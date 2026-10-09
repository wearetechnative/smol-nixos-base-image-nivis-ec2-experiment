#!/usr/bin/env bash
#
# Create and destroy the two cheap resources of the gate 2 plan, to find an
# IAM gap without paying for a 2.6 GB upload first.
#
#   just aws-probe
#
# The key pair and the security group have no dependencies, so --target can
# reach them on their own. Between them they exercise ImportKeyPair,
# CreateSecurityGroup (which also touches the VPC), CreateTags, the security
# group rule calls, and both delete paths.
#
# It does NOT cover ImportSnapshot, RegisterImage or RunInstances. Those need
# the image, so only a real gate 2 run finds a gap in them.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"
smol_write_profiles

EXPERIMENT="probe"
STATE="$repo/experiments/state/${EXPERIMENT}.json"
LOG="$repo/experiments/logs/${EXPERIMENT}.log"
mkdir -p "$(dirname "$STATE")" "$(dirname "$LOG")"

workdir=$(mktemp -d "${TMPDIR:-/tmp}/smol-probe.XXXXXXXX")
chmod 700 "$workdir"
ssh-keygen -q -t ed25519 -N '' -C "smol-probe" -f "$workdir/id" </dev/null

VAR_ARGS=(
  --flake "$repo"
  --state "$STATE"
  --build=false
  --var "variant=baseline"
  --var "experiment=$EXPERIMENT"
  --var "region=$AWS_REGION"
  --var "bucket=smol-lab-images-${AWS_ACCOUNT_ID}"
  --var "instanceType=${SMOL_INSTANCE_TYPE:-t3.micro}"
  --var "sshPublicKey=$(cat "$workdir/id.pub")"
)

cleanup() {
  local rc=$?
  if [ -f "$STATE" ]; then
    echo "==> destroying the probe resources"
    nivis destroy "${VAR_ARGS[@]}" >>"$LOG" 2>&1 &&
      rm -f "$STATE" ||
      echo "    DESTROY FAILED, run 'just reap'"
  fi
  rm -rf "$workdir"
  exit "$rc"
}
trap cleanup EXIT INT TERM

: >"$LOG"
for target in aws.aws_key_pair.verify aws.aws_security_group.verify; do
  echo "==> $target"
  if nivis apply --target "$target" "${VAR_ARGS[@]}" >>"$LOG" 2>&1; then
    echo "    ok"
  else
    echo "    DENIED"
    grep -o 'is not authorized to perform: [a-zA-Z0-9:]* on resource: [^ ]*' "$LOG" |
      sort -u | sed 's/^/    /'
    grep -o 'api error [A-Za-z]*' "$LOG" | sort -u | sed 's/^/    /'
    echo "    full diagnostics: ${LOG#"$repo"/}"
    exit 1
  fi
done

echo "==> PASS: key pair and security group both create and tag cleanly"
