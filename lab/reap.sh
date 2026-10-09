#!/usr/bin/env bash
#
# Terminate and deregister everything the lab left behind.
#
#   just reap
#
# Two passes, because they catch different things:
#
#   1. `nivis destroy` for every state file under experiments/state/. This is
#      the clean path and the only one that knows the dependency order.
#   2. A tag-and-age sweep for resources nivis holds no state for, which is
#      what a run that died before writing state leaves behind. Direct AWS
#      calls, filtered on Project=smol-lab, approved by Pim on 2026-10-09
#      (experiments/000-nivis.md gap 2).
#
# Safe to run when there is nothing to do.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"
smol_write_profiles

TAG="${SMOL_PROJECT_TAG:-smol-lab}"
AGE_MINUTES="${SMOL_REAP_AFTER_MINUTES:-60}"
STATE_DIR="$repo/experiments/state"
DRY="${SMOL_REAP_DRY_RUN:-0}"

say() { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
act() {
  if [ "$DRY" = 1 ]; then
    note "would run: $*"
  else
    "$@" >/dev/null
  fi
}

cutoff=$(date -u -d "-${AGE_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)
reaped=0

# --- pass 1: let nivis do it properly --------------------------------------
if [ -d "$STATE_DIR" ] && [ -n "$(find "$STATE_DIR" -name '*.json' -print -quit)" ]; then
  for state in "$STATE_DIR"/*.json; do
    experiment=$(basename "$state" .json)
    say "nivis destroy for $experiment"
    if [ "$DRY" = 1 ]; then
      note "would run: nivis destroy --state $state"
      continue
    fi
    if nivis destroy --state "$state" --build=false --flake "$repo" \
      --var "experiment=$experiment" \
      --var "region=$AWS_REGION" \
      --var "bucket=smol-lab-images-${AWS_ACCOUNT_ID}" \
      --var "sshPublicKey=unused-at-destroy" \
      >>"$repo/experiments/logs/reap.log" 2>&1; then
      note "destroyed"
      rm -f "$state"
      reaped=$((reaped + 1))
    else
      note "FAILED, see experiments/logs/reap.log; the sweep below may catch it"
    fi
  done
else
  say "no nivis state files"
fi

# --- pass 2: sweep whatever nivis never knew about -------------------------
say "sweeping resources tagged Project=$TAG older than ${AGE_MINUTES}m"

filters=("Name=tag:Project,Values=$TAG")

instances=$(aws ec2 describe-instances \
  --filters "${filters[@]}" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[?LaunchTime<='${cutoff}'].InstanceId" \
  --output text)
for i in $instances; do
  note "terminating instance $i"
  act aws ec2 terminate-instances --instance-ids "$i"
  reaped=$((reaped + 1))
done

images=$(aws ec2 describe-images --owners self --filters "${filters[@]}" \
  --query "Images[?CreationDate<='${cutoff}'].ImageId" --output text)
for a in $images; do
  note "deregistering ami $a"
  act aws ec2 deregister-image --image-id "$a"
  reaped=$((reaped + 1))
done

snapshots=$(aws ec2 describe-snapshots --owner-ids self --filters "${filters[@]}" \
  --query "Snapshots[?StartTime<='${cutoff}'].SnapshotId" --output text)
for s in $snapshots; do
  note "deleting snapshot $s"
  act aws ec2 delete-snapshot --snapshot-id "$s"
  reaped=$((reaped + 1))
done

# Key pairs and security groups carry no timestamp in their describe output,
# so age cannot gate them. An instance referencing one blocks its deletion,
# which is the safety net: terminate first, sweep again.
keys=$(aws ec2 describe-key-pairs --filters "${filters[@]}" \
  --query 'KeyPairs[].KeyName' --output text)
for k in $keys; do
  note "deleting key pair $k"
  act aws ec2 delete-key-pair --key-name "$k"
  reaped=$((reaped + 1))
done

groups=$(aws ec2 describe-security-groups --filters "${filters[@]}" \
  --query 'SecurityGroups[].GroupId' --output text)
for g in $groups; do
  note "deleting security group $g"
  if [ "$DRY" = 1 ]; then
    note "would run: aws ec2 delete-security-group --group-id $g"
  elif aws ec2 delete-security-group --group-id "$g" >/dev/null 2>&1; then
    reaped=$((reaped + 1))
  else
    note "still in use by a terminating instance; run reap again in a minute"
  fi
done

objects=$(aws s3api list-objects-v2 --bucket "smol-lab-images-${AWS_ACCOUNT_ID}" \
  --query "Contents[?LastModified<='${cutoff}'].Key" --output text 2>/dev/null || true)
for o in $objects; do
  [ "$o" = "None" ] && continue
  note "deleting s3://smol-lab-images-${AWS_ACCOUNT_ID}/$o"
  act aws s3api delete-object --bucket "smol-lab-images-${AWS_ACCOUNT_ID}" --key "$o"
  reaped=$((reaped + 1))
done

if [ "$reaped" -eq 0 ]; then
  say "nothing to reap"
else
  say "reaped $reaped resource(s)"
fi
