#!/usr/bin/env bash
#
# Create an access key for smol-lab-ci and wire up the two AWS CLI profiles.
# PIM RUNS THIS. The secret never reaches a terminal, a log or a chat: it goes
# from the API response straight into ~/.aws/credentials through
# `aws configure set`.
#
#   just aws-key <admin-profile>
#
# Safe to re-run only if you first delete the old key: IAM allows at most two
# keys per user, and this script refuses to create a third.
set -euo pipefail

PROFILE="${1:?usage: just aws-key <admin-profile>}"

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
# shellcheck source=/dev/null
. "$repo/lab/config.env"
: "${AWS_REGION:?AWS_REGION is not set in lab/config.env}"
: "${AWS_PROFILE:?AWS_PROFILE is not set in lab/config.env}"

BASE_PROFILE="${AWS_PROFILE}-base"
USER=smol-lab-ci
ROLE=SmolLabRole

say() { printf '==> %s\n' "$*"; }

account=$(aws --profile "$PROFILE" sts get-caller-identity --query Account --output text)
say "account $account, region $AWS_REGION"

existing=$(aws --profile "$PROFILE" iam list-access-keys --user-name "$USER" \
  --query 'AccessKeyMetadata[].AccessKeyId' --output text)

if [ -n "$existing" ]; then
  say "$USER already has: $existing"
  count=$(printf '%s\n' "$existing" | wc -w)
  if [ "$count" -ge 2 ]; then
    echo
    echo "IAM allows at most two keys per user and $USER has $count."
    echo "Delete one first:"
    for k in $existing; do
      echo "  aws --profile $PROFILE iam delete-access-key --user-name $USER --access-key-id $k"
    done
    exit 1
  fi
  printf 'Create another key anyway? [y/N] '
  read -r answer
  case "$answer" in
    [yY]*) ;;
    *) echo "nothing created"; exit 0 ;;
  esac
fi

# --- the only moment the secret exists ------------------------------------
#
# It lives in a shell variable for three lines and is never printed. Keep it
# that way: do not add an echo here, and do not run this through a tool that
# captures output.
say "creating an access key for $USER"
creds=$(aws --profile "$PROFILE" iam create-access-key --user-name "$USER" \
  --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)

key_id=$(printf '%s' "$creds" | cut -f1)
secret=$(printf '%s' "$creds" | cut -f2)
unset creds

if [ -z "$key_id" ] || [ -z "$secret" ]; then
  echo "could not parse the create-access-key response" >&2
  exit 1
fi

aws configure set aws_access_key_id "$key_id" --profile "$BASE_PROFILE"
aws configure set aws_secret_access_key "$secret" --profile "$BASE_PROFILE"
unset secret

# --- the profiles ----------------------------------------------------------
aws configure set region "$AWS_REGION" --profile "$BASE_PROFILE"

aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
aws configure set role_arn "arn:aws:iam::${account}:role/${ROLE}" --profile "$AWS_PROFILE"
aws configure set source_profile "$BASE_PROFILE" --profile "$AWS_PROFILE"
aws configure set role_session_name "$AWS_PROFILE" --profile "$AWS_PROFILE"
aws configure set duration_seconds 3600 --profile "$AWS_PROFILE"

chmod 600 "${HOME}/.aws/credentials"

cat <<EOF

==> done.

Key id:  $key_id            (public, the secret was never printed)
Stored:  ~/.aws/credentials [$BASE_PROFILE], mode 600
Profile: ~/.aws/config      [profile $AWS_PROFILE] assumes $ROLE

Next:

  just aws-check

EOF
