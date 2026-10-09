#!/usr/bin/env bash
# Prove the lab can reach AWS. Prints pass or fail and the role ARN, nothing
# else: no credentials, no raw API output (BRIEFING §7).
#
#   just aws-check
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)

if [ ! -f "$here/config.env" ]; then
  echo "FAIL: lab/config.env is missing. See docs/SETUP-AWS.md step 1."
  exit 1
fi
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"
smol_write_profiles

fail() {
  echo "FAIL: $1"
  [ $# -gt 1 ] && echo "      $2"
  exit 1
}

command -v aws >/dev/null 2>&1 || fail "no aws CLI on PATH" "run inside 'nix develop'"

aws configure get aws_access_key_id --profile "$smol_base_profile" >/dev/null 2>&1 ||
  fail "no key stored for $smol_base_profile" \
    "run: just aws-key <admin-profile>, see docs/SETUP-AWS.md"

# --- 1. the role is assumed ------------------------------------------------
arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null) || {
  fail "could not assume the role" \
    "check ~/.aws/config and ~/.aws/credentials, see docs/SETUP-AWS.md step 4"
}

case "$arn" in
  *:assumed-role/SmolLabRole/*) ;;
  *)
    fail "wrong identity: not an assumed SmolLabRole session" \
      "got $arn; profile $AWS_PROFILE should have role_arn set"
    ;;
esac

# --- 2. a correctly tagged launch would be permitted -----------------------
#
# DryRun never creates anything. AWS signals "you would have been allowed"
# with the DryRunOperation error, so that string is the pass condition.
ami=$(aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text 2>/dev/null) || ami=""

if [ -z "$ami" ] || [ "$ami" = "None" ]; then
  # The lab role has no ssm:GetParameters, which is correct. Fall back to any
  # AMI the account can see; the dry run only has to reach the authorisation
  # check.
  ami=$(aws ec2 describe-images --owners amazon \
    --filters "Name=architecture,Values=x86_64" "Name=state,Values=available" \
    --query 'Images[0].ImageId' --output text 2>/dev/null) || ami=""
fi

[ -n "$ami" ] && [ "$ami" != "None" ] ||
  fail "could not find any AMI to dry-run against" \
    "ec2:DescribeImages may be missing from SmolLabRole"

out=$(aws ec2 run-instances --dry-run \
  --image-id "$ami" \
  --instance-type "${SMOL_INSTANCE_TYPE:-t3.micro}" \
  --tag-specifications \
  "ResourceType=instance,Tags=[{Key=Project,Value=${SMOL_PROJECT_TAG:-smol-lab}},{Key=Experiment,Value=aws-check}]" \
  2>&1) || true

case "$out" in
  *DryRunOperation*)
    echo "PASS: $arn"
    echo "      region $AWS_REGION, tagged launch of ${SMOL_INSTANCE_TYPE:-t3.micro} permitted"
    exit 0
    ;;
  *UnauthorizedOperation*)
    fail "the role may not launch a tagged instance" \
      "review infra/iam/SmolLabRole-permissions.json, then re-run bootstrap.sh"
    ;;
  *)
    fail "unexpected response to the dry run" \
      "$(printf '%s' "$out" | head -1)"
    ;;
esac
