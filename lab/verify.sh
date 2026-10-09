#!/usr/bin/env sh
# The verification contract (BRIEFING §3). Runs ON the target.
#
# Contract version: 1
#
# Invoke over SSH:   ssh <host> 'sh -s' < lab/verify.sh
# Or inside a test:  machine.succeed("sh ${./verify.sh}")
#
# Environment:
#   VERIFY_ENV        qemu | ec2            (default: ec2)
#   VERIFY_TRACK      appliance | mutable   (default: appliance)
#   VERIFY_ROOT_MIN_GB  minimum usable root size in GiB (default: 2)
#   VERIFY_HTTPS_URL  URL used for the outbound HTTPS check
#   VERIFY_CURL       path to a curl binary; the harness pushes a static one to
#                     the target so the image itself never has to ship curl
#   VERIFY_CA_BUNDLE  CA bundle curl validates against (default: the image's)
#   VERIFY_NTP_TIMEOUT  seconds to wait for the clock to synchronise
#
# Exit code 0 means the candidate passes. Any other code means it fails.
set -u

VERIFY_ENV="${VERIFY_ENV:-ec2}"
VERIFY_TRACK="${VERIFY_TRACK:-appliance}"
VERIFY_ROOT_MIN_GB="${VERIFY_ROOT_MIN_GB:-2}"
VERIFY_HTTPS_URL="${VERIFY_HTTPS_URL:-https://cache.nixos.org/nix-cache-info}"
VERIFY_CURL="${VERIFY_CURL:-/tmp/smol-curl}"
VERIFY_CA_BUNDLE="${VERIFY_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
VERIFY_NTP_TIMEOUT="${VERIFY_NTP_TIMEOUT:-90}"
CONTRACT_VERSION=1

failures=0
checks=0

pass() {
  checks=$((checks + 1))
  echo "ok $checks - $1"
}

fail() {
  checks=$((checks + 1))
  failures=$((failures + 1))
  echo "not ok $checks - $1"
  shift
  for line in "$@"; do echo "  # $line"; done
}

skip() {
  checks=$((checks + 1))
  echo "ok $checks - $1 # SKIP $2"
}

have() { command -v "$1" >/dev/null 2>&1; }

echo "# smol verify contract v$CONTRACT_VERSION env=$VERIFY_ENV track=$VERIFY_TRACK"

# --- 1. SSH login works with a key injected from EC2 metadata --------------
#
# Reaching this script already proves key-based login worked. What is left to
# prove is that the key was injected at boot rather than baked into the image.
check_metadata_key() {
  keyfile=""
  for candidate in /root/.ssh/authorized_keys /etc/ssh/authorized_keys.d/root; do
    [ -e "$candidate" ] && keyfile="$candidate" && break
  done

  if [ -z "$keyfile" ]; then
    fail "authorized_keys present" "no authorized_keys file found for root"
    return
  fi

  resolved=$(readlink -f "$keyfile")
  case "$resolved" in
    /nix/store/*)
      fail "ssh key comes from metadata, not the image" \
        "$keyfile resolves into the nix store: $resolved"
      return
      ;;
  esac

  if [ ! -s "$keyfile" ]; then
    fail "ssh key comes from metadata, not the image" "$keyfile is empty"
    return
  fi

  pass "ssh key comes from metadata, not the image ($keyfile)"
}

if [ "$VERIFY_ENV" = "ec2" ]; then
  check_metadata_key
else
  skip "ssh key comes from metadata, not the image" "no IMDS under $VERIFY_ENV"
fi

# --- 2. systemd is fully up, no failed units -------------------------------
state=$(systemctl is-system-running 2>/dev/null || true)
if [ "$state" = "running" ]; then
  pass "systemctl is-system-running = running"
else
  fail "systemctl is-system-running = running" "got: ${state:-<empty>}"
fi

failed=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}')
if [ -z "$failed" ]; then
  pass "no failed units"
else
  # shellcheck disable=SC2086  # deliberate split: one message line per unit
  fail "no failed units" $failed
fi

# --- 3. DNS, outbound HTTPS, clock -----------------------------------------
dns_host=$(echo "$VERIFY_HTTPS_URL" | sed -e 's|^[a-z]*://||' -e 's|/.*$||')
if getent hosts "$dns_host" >/dev/null 2>&1; then
  pass "DNS resolves $dns_host"
else
  fail "DNS resolves $dns_host" "getent hosts returned nothing"
fi

curlbin=""
if [ -x "$VERIFY_CURL" ]; then
  curlbin="$VERIFY_CURL"
elif have curl; then
  curlbin=$(command -v curl)
fi

if [ -n "$curlbin" ]; then
  # A pushed static curl has its own compiled-in CA path, so point it at the
  # image's bundle: whether the image still has one is part of the contract.
  if [ -r "$VERIFY_CA_BUNDLE" ]; then
    CURL_CA_BUNDLE="$VERIFY_CA_BUNDLE"
    export CURL_CA_BUNDLE
  fi
  if "$curlbin" -fsS --max-time 30 -o /dev/null "$VERIFY_HTTPS_URL"; then
    pass "outbound HTTPS to $VERIFY_HTTPS_URL"
  else
    fail "outbound HTTPS to $VERIFY_HTTPS_URL" "$curlbin failed"
  fi
else
  fail "outbound HTTPS to $VERIFY_HTTPS_URL" \
    "no curl at \$VERIFY_CURL ($VERIFY_CURL) and none on PATH;" \
    "the harness must push a static curl to the target before verifying"
fi

synced=""
waited=0
while [ "$waited" -lt "$VERIFY_NTP_TIMEOUT" ]; do
  synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || true)
  [ "$synced" = "yes" ] && break
  sleep 3
  waited=$((waited + 3))
done

if [ "$synced" = "yes" ]; then
  pass "clock is NTP synchronised (after ${waited}s)"
elif [ -z "$synced" ]; then
  fail "clock is NTP synchronised" "timedatectl gave no NTPSynchronized property"
else
  fail "clock is NTP synchronised" \
    "NTPSynchronized=$synced after ${VERIFY_NTP_TIMEOUT}s"
fi

# --- 4. Root filesystem is read-write and large enough ---------------------
rootsrc=$(findmnt -no SOURCE / 2>/dev/null || echo "?")
rootopts=$(findmnt -no OPTIONS / 2>/dev/null || echo "")
case ",$rootopts," in
  *,rw,*) pass "root filesystem $rootsrc is mounted read-write" ;;
  *) fail "root filesystem is mounted read-write" "source=$rootsrc options=$rootopts" ;;
esac

probe=/.smol-verify-write-probe
if (echo smol >"$probe" && rm -f "$probe") 2>/dev/null; then
  pass "root filesystem accepts writes"
else
  fail "root filesystem accepts writes" "could not create $probe"
fi

root_kb=$(df -Pk / | awk 'NR==2 {print $2}')
root_gb=$((root_kb / 1024 / 1024))
if [ "$root_gb" -ge "$VERIFY_ROOT_MIN_GB" ]; then
  pass "root filesystem is ${root_gb} GiB (>= ${VERIFY_ROOT_MIN_GB} GiB)"
else
  fail "root filesystem is at least ${VERIFY_ROOT_MIN_GB} GiB" "got ${root_gb} GiB"
fi

# --- 6. Mutable track only: in-place update path works ---------------------
if [ "$VERIFY_TRACK" = "mutable" ]; then
  if have nixos-rebuild; then
    if nixos-rebuild --help >/dev/null 2>&1 && have nix; then
      pass "nixos-rebuild and nix are available for in-place updates"
    else
      fail "nixos-rebuild and nix are available for in-place updates" \
        "nixos-rebuild present but nix is not usable"
    fi
  else
    fail "nixos-rebuild and nix are available for in-place updates" \
      "no nixos-rebuild on the target"
  fi
else
  skip "in-place update path" "appliance track"
fi

echo "1..$checks"
if [ "$failures" -eq 0 ]; then
  echo "# VERIFY PASS ($checks checks)"
  exit 0
fi
echo "# VERIFY FAIL ($failures of $checks checks failed)"
exit 1
