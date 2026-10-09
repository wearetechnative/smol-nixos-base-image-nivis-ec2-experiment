#!/usr/bin/env bash
#
# Create an access key for smol-lab-ci and wire up the two AWS CLI profiles.
# PIM RUNS THIS. The secret never reaches a terminal, a log or a chat: it goes
# from the API response straight into ~/.aws/credentials through
# `aws configure set`.
#
#   just aws-key <admin-profile>
#
# If storing the key fails for any reason, the key it just created is deleted
# again, so a failed run never leaves an unusable key behind eating one of the
# two slots IAM allows.
set -euo pipefail

PROFILE="${1:?usage: just aws-key <admin-profile>}"

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"

USER=smol-lab-ci

say() { printf '==> %s\n' "$*"; }

account=$(smol_aws_admin --profile "$PROFILE" sts get-caller-identity \
  --query Account --output text)

if [ "$account" != "$AWS_ACCOUNT_ID" ]; then
  echo "FAIL: profile $PROFILE is on account $account," >&2
  echo "      but lab/config.env says AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID" >&2
  exit 1
fi
say "account $account, region $AWS_REGION"

smol_write_profiles
say "wrote $AWS_CONFIG_FILE"

# --- what is already there -------------------------------------------------
existing=$(smol_aws_admin --profile "$PROFILE" iam list-access-keys \
  --user-name "$USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text)

stored=$(aws configure get aws_access_key_id --profile "$smol_base_profile" 2>/dev/null || true)

if [ -n "$existing" ]; then
  count=$(printf '%s\n' "$existing" | wc -w)
  say "$USER already has $count key(s): $existing"

  orphans=""
  for k in $existing; do
    [ "$k" = "$stored" ] || orphans="$orphans $k"
  done

  if [ -n "$orphans" ]; then
    echo
    echo "These keys are not the one stored in ~/.aws/credentials, so their"
    echo "secret is lost and they can never be used. Delete them:"
    for k in $orphans; do
      echo "  aws --profile $PROFILE iam delete-access-key --user-name $USER --access-key-id $k"
    done
    echo
  fi

  if [ "$count" -ge 2 ]; then
    echo "IAM allows at most two keys per user. Delete one, then re-run."
    exit 1
  fi

  printf 'Create another key anyway? [y/N] '
  read -r answer
  case "$answer" in
    [yY]*) ;;
    *)
      echo "nothing created"
      exit 0
      ;;
  esac
fi

# --- the only moment the secret exists ------------------------------------
#
# It lives in a shell variable for a handful of lines and is never printed.
# Keep it that way: do not add an echo here, and do not run this through a
# tool that captures output.
say "creating an access key for $USER"
creds=$(smol_aws_admin --profile "$PROFILE" iam create-access-key \
  --user-name "$USER" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' \
  --output text)

key_id=$(printf '%s' "$creds" | cut -f1)
secret=$(printf '%s' "$creds" | cut -f2)
unset creds

if [ -z "$key_id" ] || [ -z "$secret" ]; then
  echo "could not parse the create-access-key response" >&2
  exit 1
fi

# From here on, any failure must take the new key with it.
cleanup_key() {
  echo >&2
  echo "Storing the key failed. Deleting $key_id again so it does not sit" >&2
  echo "unusable in the account." >&2
  smol_aws_admin --profile "$PROFILE" iam delete-access-key \
    --user-name "$USER" --access-key-id "$key_id" >/dev/null 2>&1 ||
    echo "Could not delete it; do it by hand: aws --profile $PROFILE iam delete-access-key --user-name $USER --access-key-id $key_id" >&2
}
trap cleanup_key ERR

aws configure set aws_access_key_id "$key_id" --profile "$smol_base_profile"
aws configure set aws_secret_access_key "$secret" --profile "$smol_base_profile"
unset secret

trap - ERR

chmod 600 "${HOME}/.aws/credentials"

cat <<EOF

==> done.

Key id:  $key_id            (public, the secret was never printed)
Stored:  ~/.aws/credentials [$smol_base_profile], mode 600
Profile: $AWS_CONFIG_FILE   [profile $AWS_PROFILE] assumes SmolLabRole

Next:

  just aws-check

EOF
