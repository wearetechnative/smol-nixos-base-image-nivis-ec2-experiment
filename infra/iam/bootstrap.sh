#!/usr/bin/env bash
#
# Creates the AWS side of the smol lab. PIM RUNS THIS, CLAUDE NEVER DOES.
# `.claude/settings.json` denies the agent from invoking it.
#
#   ./infra/iam/bootstrap.sh <admin-profile> [region]
#
# It creates, and is safe to re-run:
#
#   - the lab S3 bucket the image is uploaded to
#   - the `vmimport` service role AWS requires for disk-image import, scoped
#     to that one bucket
#   - `SmolLabRole`, the role the lab works through
#   - `smol-lab-ci`, a user whose only permission is to assume that role
#   - a budget alert on the account
#
# It deliberately does NOT create an access key. You do that yourself,
# afterwards, following docs/SETUP-AWS.md, so the key never passes through a
# script's output.
set -euo pipefail

PROFILE="${1:?usage: bootstrap.sh <admin-profile> [region]}"
REGION="${2:-}"

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)

if [ -z "$REGION" ]; then
  # shellcheck source=/dev/null
  [ -f "$repo/lab/config.env" ] && . "$repo/lab/config.env"
  REGION="${AWS_REGION:?no region given and AWS_REGION is not set in lab/config.env}"
fi

BUDGET_AMOUNT="${SMOL_BUDGET_AMOUNT:-55}"
BUDGET_UNIT="${SMOL_BUDGET_UNIT:-USD}"
BUDGET_EMAIL="${SMOL_BUDGET_EMAIL:-}"

aws_() { aws --profile "$PROFILE" --region "$REGION" "$@"; }
say() { printf '==> %s\n' "$*"; }

ACCOUNT_ID=$(aws_ sts get-caller-identity --query Account --output text)
BUCKET="smol-lab-images-${ACCOUNT_ID}"

say "account $ACCOUNT_ID, region $REGION, bucket $BUCKET"

render() {
  sed -e "s|\${ACCOUNT_ID}|$ACCOUNT_ID|g" \
    -e "s|\${REGION}|$REGION|g" \
    -e "s|\${BUCKET}|$BUCKET|g" \
    "$here/$1"
}

exists() { "$@" >/dev/null 2>&1; }

# --- the lab bucket --------------------------------------------------------
#
# Created once here rather than per deployment, so SmolLabRole never needs
# s3:CreateBucket and the vmimport policy can name a single bucket.
if exists aws_ s3api head-bucket --bucket "$BUCKET"; then
  say "bucket $BUCKET already exists"
else
  say "creating bucket $BUCKET"
  if [ "$REGION" = "us-east-1" ]; then
    aws_ s3api create-bucket --bucket "$BUCKET"
  else
    aws_ s3api create-bucket --bucket "$BUCKET" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
  aws_ s3api put-public-access-block --bucket "$BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

aws_ s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging 'TagSet=[{Key=Project,Value=smol-lab}]'

# Images are rebuilt every experiment; nothing in here is worth keeping.
aws_ s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-lab-images",
      "Status": "Enabled",
      "Filter": {"Prefix": ""},
      "Expiration": {"Days": 7},
      "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 1}
    }]
  }'

# --- roles and policies ----------------------------------------------------

# IAM resolves a principal ARN at write time, and a freshly created user takes
# a moment to become resolvable. Retry rather than fail the whole run.
upsert_role() {
  local name="$1" trust="$2" desc="$3" attempt=1 out=""
  if exists aws_ iam get-role --role-name "$name"; then
    say "role $name exists, updating its trust policy"
    while :; do
      if out=$(aws_ iam update-assume-role-policy --role-name "$name" \
        --policy-document "$(render "$trust")" 2>&1); then
        return 0
      fi
      case "$out,$attempt" in
        *MalformedPolicyDocument*,[1-5]) ;;
        *) echo "$out" >&2; return 1 ;;
      esac
      say "principal not resolvable yet, retry $attempt"
      attempt=$((attempt + 1))
      sleep 5
    done
  fi

  say "creating role $name"
  while :; do
    if out=$(aws_ iam create-role --role-name "$name" \
      --description "$desc" \
      --assume-role-policy-document "$(render "$trust")" \
      --tags Key=Project,Value=smol-lab 2>&1); then
      return 0
    fi
    case "$out,$attempt" in
      *MalformedPolicyDocument*,[1-5]) ;;
      *) echo "$out" >&2; return 1 ;;
    esac
    say "principal not resolvable yet, retry $attempt"
    attempt=$((attempt + 1))
    sleep 5
  done
}

put_inline_policy() {
  local kind="$1" principal="$2" policy_name="$3" doc="$4"
  say "writing inline policy $policy_name on $kind $principal"
  case "$kind" in
    role)
      aws_ iam put-role-policy --role-name "$principal" \
        --policy-name "$policy_name" --policy-document "$(render "$doc")"
      ;;
    user)
      aws_ iam put-user-policy --user-name "$principal" \
        --policy-name "$policy_name" --policy-document "$(render "$doc")"
      ;;
  esac
}

upsert_role vmimport vmimport-trust.json \
  "VM Import/Export service role for the smol lab"
put_inline_policy role vmimport smol-lab-vmimport vmimport-permissions.json

# --- the user, before the role that trusts it ------------------------------
#
# SmolLabRole's trust policy names this user as its principal, and IAM rejects
# a principal that does not exist yet. The user's own policy only names the
# role as a Resource, and resource ARNs are not resolved, so this order works
# and the other does not.
if exists aws_ iam get-user --user-name smol-lab-ci; then
  say "user smol-lab-ci exists"
else
  say "creating user smol-lab-ci"
  aws_ iam create-user --user-name smol-lab-ci \
    --tags Key=Project,Value=smol-lab >/dev/null
fi
put_inline_policy user smol-lab-ci smol-lab-assume-role smol-lab-ci-policy.json

upsert_role SmolLabRole SmolLabRole-trust.json \
  "The role the smol lab works through"
put_inline_policy role SmolLabRole smol-lab-permissions SmolLabRole-permissions.json

# --- the budget ------------------------------------------------------------
if exists aws_ budgets describe-budget --account-id "$ACCOUNT_ID" \
  --budget-name smol-lab; then
  say "budget smol-lab exists"
else
  say "creating budget smol-lab at $BUDGET_AMOUNT $BUDGET_UNIT per month"
  budget_json=$(printf '{"BudgetName":"smol-lab","BudgetLimit":{"Amount":"%s","Unit":"%s"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
    "$BUDGET_AMOUNT" "$BUDGET_UNIT")
  if [ -n "$BUDGET_EMAIL" ]; then
    notifications=$(printf '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"%s"}]}]' \
      "$BUDGET_EMAIL")
    budget_out=$(aws_ budgets create-budget --account-id "$ACCOUNT_ID" \
      --budget "$budget_json" --notifications-with-subscribers "$notifications" 2>&1) || budget_failed=1
  else
    say "no SMOL_BUDGET_EMAIL set, creating the budget without an alert subscriber"
    budget_out=$(aws_ budgets create-budget --account-id "$ACCOUNT_ID" \
      --budget "$budget_json" 2>&1) || budget_failed=1
  fi

  if [ "${budget_failed:-0}" = 1 ]; then
    case "$budget_out" in
      *"not in the supported unit set"*)
        echo
        echo "The budget was NOT created: AWS Budgets only accepts the"
        echo "account's billing currency. $budget_out" | tail -1
        echo "Set SMOL_BUDGET_UNIT in lab/config.env to that currency and"
        echo "re-run. Everything else above succeeded."
        echo
        ;;
      *)
        echo "$budget_out" >&2
        exit 1
        ;;
    esac
  fi
fi

cat <<EOF

==> done.

Account: $ACCOUNT_ID
Region:  $REGION
Bucket:  $BUCKET

Next, from docs/SETUP-AWS.md:

  1. Create one access key for smol-lab-ci.
  2. Put it in ~/.aws/credentials under [smol-lab-base], chmod 600.
  3. Put the two profiles in ~/.aws/config.
  4. Run: just aws-check

EOF
