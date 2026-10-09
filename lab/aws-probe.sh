#!/usr/bin/env bash
#
# Create and destroy the two cheap resources of the gate 2 plan, to find an
# IAM gap without paying for a 2.6 GB upload first.
#
#   just aws-probe
#
# It applies the plan with scope=cheap, which drops every resource that needs
# the image. Between the key pair and the security group it exercises
# ImportKeyPair, CreateSecurityGroup (which also touches the VPC), CreateTags,
# the security group rule calls, and both delete paths.
#
# It does NOT cover ImportSnapshot, RegisterImage or RunInstances. Those need
# the image, so only a real gate 2 run finds a gap in them.
#
# Do not reach for `nivis --target` here: it does not restrict the graph the
# way the name suggests, and an earlier version of this script paid for the
# full upload because of it.
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
  --var "scope=cheap"
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

# --- dry-run authorisation checks ------------------------------------------
#
# RegisterImage and RunInstances cannot be reached without a real snapshot and
# a real AMI, which cost eleven minutes to produce. Both support DryRun, which
# runs the authorisation check and creates nothing, so a gap in either is
# found here instead of after the upload and the import.
dryrun() {
  local label="$1"
  shift
  local out
  out=$(aws "$@" --dry-run 2>&1) || true
  case "$out" in
    *DryRunOperation*)
      echo "    ok       $label"
      ;;
    *UnauthorizedOperation* | *AccessDenied* | *not\ authorized*)
      echo "    DENIED   $label"
      printf '%s' "$out" | grep -oE 'not authorized to perform:? ?[a-zA-Z0-9:]+( on resource: [^ ]*)?' |
        sort -u | sed 's/^/             /'
      return 1
      ;;
    *)
      echo "    unclear  $label: $(printf '%s' "$out" | head -1 | cut -c1-120)"
      ;;
  esac
}

echo "==> dry-run authorisation checks"
tagspec_image="ResourceType=image,Tags=[{Key=Project,Value=smol-lab},{Key=Experiment,Value=probe}]"
tagspec_instance="ResourceType=instance,Tags=[{Key=Project,Value=smol-lab},{Key=Experiment,Value=probe}]"
denied=0

dryrun "ec2:RegisterImage" ec2 register-image \
  --name smol-probe-dryrun \
  --architecture x86_64 \
  --root-device-name /dev/xvda \
  --virtualization-type hvm \
  --ena-support \
  --block-device-mappings 'DeviceName=/dev/xvda,Ebs={SnapshotId=snap-00000000000000000}' \
  --tag-specifications "$tagspec_image" || denied=1

ami=$(aws ec2 describe-images --owners amazon \
  --filters "Name=architecture,Values=x86_64" "Name=state,Values=available" \
  --query 'Images[0].ImageId' --output text 2>/dev/null || echo "")
if [ -n "$ami" ] && [ "$ami" != "None" ]; then
  dryrun "ec2:RunInstances" ec2 run-instances \
    --image-id "$ami" \
    --instance-type "${SMOL_INSTANCE_TYPE:-t3.micro}" \
    --tag-specifications "$tagspec_instance" || denied=1
fi

[ "$denied" -eq 0 ] || {
  echo "    fix infra/iam/SmolLabRole-permissions.json, then re-run bootstrap.sh"
  exit 1
}

: >"$LOG"
echo "==> applying the key pair and the security group"
if nivis apply "${VAR_ARGS[@]}" >>"$LOG" 2>&1; then
  echo "==> PASS: both create and tag cleanly"
else
  echo "==> DENIED"
  grep -oE 'not authorized to perform:? ?[a-zA-Z0-9:]+( on resource: [^ ]*)?' "$LOG" |
    sort -u | sed 's/^/    /'
  grep -oE 'api error [A-Za-z]+' "$LOG" | sort -u | sed 's/^/    /'
  echo "    full diagnostics: ${LOG#"$repo"/}"
  exit 1
fi
