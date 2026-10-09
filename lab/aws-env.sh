# shellcheck shell=bash
# Sourced by the lab's AWS scripts. Not executable on its own.
#
# Pim's ~/.aws/config is managed by home-manager and read-only, so the lab
# cannot write its profiles there. It keeps its own config file instead and
# points the SDK at it with AWS_CONFIG_FILE.
#
# The key is NOT moved: it stays in ~/.aws/credentials, which is writable and
# is the one place the briefing allows. Nothing in the repo ever holds it.

smol_repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$smol_repo/lab/config.env"

: "${AWS_REGION:?AWS_REGION is not set in lab/config.env}"
: "${AWS_PROFILE:?AWS_PROFILE is not set in lab/config.env}"
: "${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is not set in lab/config.env}"

smol_base_profile="${AWS_PROFILE}-base"
AWS_CONFIG_FILE="$smol_repo/lab/aws-config"
export AWS_CONFIG_FILE AWS_REGION AWS_PROFILE

# Regenerate the profiles from config.env. Pure text, no AWS call, no secret,
# so it is safe to do on every run and the file can never go stale.
smol_write_profiles() {
  cat >"$AWS_CONFIG_FILE" <<EOF
# Generated from lab/config.env. Do not edit; edit config.env and re-run any
# lab AWS recipe. Gitignored, and it holds no secret: the access key lives in
# ~/.aws/credentials under [$smol_base_profile].

[profile $smol_base_profile]
region = $AWS_REGION

[profile $AWS_PROFILE]
region = $AWS_REGION
role_arn = arn:aws:iam::${AWS_ACCOUNT_ID}:role/SmolLabRole
source_profile = $smol_base_profile
role_session_name = $AWS_PROFILE
duration_seconds = 3600
EOF
}

# Run an aws command against Pim's own config rather than the lab's, for the
# admin profile that only exists there.
smol_aws_admin() {
  env -u AWS_CONFIG_FILE -u AWS_PROFILE -u AWS_REGION aws "$@"
}
