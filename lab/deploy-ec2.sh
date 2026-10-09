#!/usr/bin/env bash
#
# Gate 2 (BRIEFING §8.4): deploy a variant to EC2 through nivis, run the
# verification contract over SSH, reboot, run it again, and tear everything
# down. Pass or fail, nothing is left running.
#
#   just gate2 <experiment-id> [variant]
#
# Prints a one-line JSON summary on stdout for the ledger. The narrative goes
# to experiments/logs/<id>-deploy.log; a full nivis run is never streamed into
# a conversation.
set -euo pipefail

EXPERIMENT="${1:?usage: just gate2 <experiment-id> [variant]}"
VARIANT="${2:-candidate}"

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"
smol_write_profiles

SYSTEM="${SMOL_SYSTEM:-x86_64-linux}"
SSH_TIMEOUT="${SMOL_SSH_TIMEOUT:-600}"
STATE_DIR="$repo/experiments/state"
LOG_DIR="$repo/experiments/logs"
STATE="$STATE_DIR/${EXPERIMENT}.json"
LOG="$LOG_DIR/${EXPERIMENT}-deploy.log"
mkdir -p "$STATE_DIR" "$LOG_DIR"

say() { printf '==> %s\n' "$*" >&2; }
note() { printf '    %s\n' "$*" >&2; }

# --- an ephemeral keypair, never reused, never committed -------------------
#
# The public half becomes an aws_key_pair and reaches the guest through
# instance metadata. That is the whole point of contract check 1: the key must
# not be in the image.
workdir=$(mktemp -d "${TMPDIR:-/tmp}/smol-gate2.XXXXXXXX")
chmod 700 "$workdir"
ssh-keygen -q -t ed25519 -N '' -C "smol-${EXPERIMENT}" -f "$workdir/id" </dev/null

gate=fail
instance_id=""
ami_id=""
boot_seconds=null
torn_down=no

teardown() {
  local rc=$?
  if [ "$torn_down" = no ] && [ -f "$STATE" ]; then
    torn_down=yes
    say "tearing down"
    if nivis destroy --state "$STATE" --build=false "${VAR_ARGS[@]}" \
      >>"$LOG" 2>&1; then
      note "destroyed"
      rm -f "$STATE"
    else
      note "DESTROY FAILED, see $LOG"
      note "run 'just reap' before anything else"
    fi
  fi
  rm -rf "$workdir"
  summary
  exit "$rc"
}

summary() {
  printf '{"experiment":"%s","variant":"%s","gate2":"%s","instance_id":"%s","ami_id":"%s","boot_seconds":%s,"torn_down":"%s","log":"%s"}\n' \
    "$EXPERIMENT" "$VARIANT" "$gate" "$instance_id" "$ami_id" \
    "$boot_seconds" "$torn_down" "experiments/logs/${EXPERIMENT}-deploy.log"
}

VAR_ARGS=(
  --flake "$repo"
  --var "variant=$VARIANT"
  --var "experiment=$EXPERIMENT"
  --var "region=$AWS_REGION"
  --var "bucket=smol-lab-images-${AWS_ACCOUNT_ID}"
  --var "instanceType=${SMOL_INSTANCE_TYPE:-t3.micro}"
  --var "system=$SYSTEM"
  --var "sshPublicKey=$(cat "$workdir/id.pub")"
)

trap teardown EXIT INT TERM

# --- deploy ----------------------------------------------------------------
say "deploying $VARIANT as experiment $EXPERIMENT, log: ${LOG#"$repo"/}"
: >"$LOG"
if ! nivis apply --state "$STATE" "${VAR_ARGS[@]}" >>"$LOG" 2>&1; then
  note "nivis apply failed, see ${LOG#"$repo"/}"
  tail -20 "$LOG" >&2
  exit 1
fi

outputs=$(nivis output --json --state "$STATE" "${VAR_ARGS[@]}" 2>>"$LOG")
ip=$(printf '%s' "$outputs" | jq -r '.public_ip // empty')
instance_id=$(printf '%s' "$outputs" | jq -r '.instance_id // empty')
ami_id=$(printf '%s' "$outputs" | jq -r '.ami_id // empty')

[ -n "$ip" ] || {
  note "nivis produced no public_ip"
  exit 1
}
say "instance $instance_id at $ip, ami $ami_id"

SSH=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR
  -i "$workdir/id" "root@$ip")
SCP=(scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR
  -i "$workdir/id")

wait_for_ssh() {
  local deadline=$((SECONDS + SSH_TIMEOUT)) first=1
  while [ "$SECONDS" -lt "$deadline" ]; do
    if "${SSH[@]}" true 2>/dev/null; then
      [ "$first" = 1 ] || echo >&2
      return 0
    fi
    first=0
    printf '.' >&2
    sleep 10
  done
  echo >&2
  return 1
}

if ! wait_for_ssh; then
  note "no SSH within ${SSH_TIMEOUT}s; fetching the serial console"
  "$here/console.sh" "$instance_id" "$EXPERIMENT" >&2 || true
  exit 1
fi

# --- the contract ----------------------------------------------------------
#
# The same lab/verify.sh gate 1 runs. The image ships no curl, so push a
# static one first.
curl_path=$(nix build --no-link --print-out-paths \
  "$repo#packages.${SYSTEM}.static-curl" 2>>"$LOG")

run_contract() {
  local label="$1"
  "${SCP[@]}" "$curl_path/bin/curl" "root@$ip:/tmp/smol-curl" >>"$LOG" 2>&1
  say "verification contract ($label)"
  if "${SSH[@]}" "VERIFY_ENV=ec2 VERIFY_TRACK=${SMOL_TRACK:-appliance} sh -s" \
    <"$here/verify.sh" >&2; then
    return 0
  fi
  return 1
}

run_contract "first boot" || exit 1

# --- reboot and do it again ------------------------------------------------
boot_id_before=$("${SSH[@]}" cat /proc/sys/kernel/random/boot_id)
say "rebooting"
"${SSH[@]}" "systemctl reboot" >/dev/null 2>&1 || true

# Wait for a genuinely different boot, not a surviving pre-reboot session.
deadline=$((SECONDS + SSH_TIMEOUT))
rebooted=no
while [ "$SECONDS" -lt "$deadline" ]; do
  current=$("${SSH[@]}" cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
  if [ -n "$current" ] && [ "$current" != "$boot_id_before" ]; then
    rebooted=yes
    echo >&2
    break
  fi
  printf '.' >&2
  sleep 10
done

[ "$rebooted" = yes ] || {
  note "the instance did not come back within ${SSH_TIMEOUT}s"
  "$here/console.sh" "$instance_id" "$EXPERIMENT" >&2 || true
  exit 1
}

run_contract "after reboot" || exit 1

# --- boot time, measured on the guest --------------------------------------
#
# The API only knows when the launch call returned, which is not the same
# thing as how long the machine took to come up.
boot_seconds=$("${SSH[@]}" "systemd-analyze --no-pager" 2>/dev/null |
  sed -n '1s/.*= *\([0-9.]*\)s.*/\1/p') || true
[ -n "$boot_seconds" ] || boot_seconds=null
say "boot time ${boot_seconds}s"

gate=pass
say "GATE 2 PASS"
