# AWS setup

For Pim. Claude wrote this; Claude never runs any of it.

One-time setup, then `just aws-check` is the only AWS command anyone types by
hand. Roughly fifteen minutes.

The design is BRIEFING §7: a user that can do nothing but assume one role, a
role fenced to one region and one tag, and AWS CLI profiles so the SDK
re-assumes the role on its own and a long autonomous run never breaks on an
expired token.

## What you need first

- An admin profile on the **playground account**, say `playground-admin`.
  Everything below runs with that profile; nothing runs with your main
  account.
- The region, already recorded in `lab/config.env` as `eu-central-1`. Change
  it there first if you want a different one; the IAM policy is generated
  from that value.
- `nix develop` for the AWS CLI, or your own.

## Step 1: review what will be created

Five policy documents, all with `${ACCOUNT_ID}`, `${REGION}` and `${BUCKET}`
filled in by the script:

| file | what it grants |
| ---- | -------------- |
| `infra/iam/smol-lab-ci-policy.json` | the user may assume `SmolLabRole`, and nothing else |
| `infra/iam/SmolLabRole-trust.json` | only `smol-lab-ci` may assume the role |
| `infra/iam/SmolLabRole-permissions.json` | what the lab may do, one statement at a time, below |
| `infra/iam/vmimport-trust.json` | only AWS's VM Import service may assume `vmimport`, with external id `vmimport` |
| `infra/iam/vmimport-permissions.json` | `vmimport` may read the one lab bucket and turn an image into a snapshot |

`SmolLabRole-permissions.json`, statement by statement:

| Sid | one line |
| --- | -------- |
| `ReadOnlyDescribesInTheLabRegion` | read-only `ec2:Describe*`, only in the lab region |
| `SeeWhoWeAre` | `sts:GetCallerIdentity`, so `just aws-check` can report the role |
| `LaunchOnlyTheAgreedInstanceTypes` | launch an instance only as `t3.micro` or `t3.small`, only tagged `Project=smol-lab` |
| `LaunchNeedsTheseSupportingResources` | the AMI, subnet, security group, key pair and volume a launch touches, in the lab region |
| `CreateTheLabsOwnResourcesTaggedAsTheLabs` | create a security group, key pair, AMI or snapshot import, only tagged `Project=smol-lab` |
| `TagOnCreateOnly` | `ec2:CreateTags`, only when the tag being set is `Project=smol-lab` |
| `ManageTheSecurityGroupsOwnRules` | open and close ports, only on a security group already tagged as the lab's |
| `TearDownOnlyWhatIsTaggedAsTheLabs` | terminate, deregister and delete, only on resources already tagged `Project=smol-lab` |
| `ReadTheSerialConsoleOfOurOwnInstances` | `ec2:GetConsoleOutput` on lab instances, for diagnosing a boot that never comes up |
| `TheOneLabBucketAndNoOther` | read the lab bucket's own settings, by name, no other bucket |
| `ImagesInAndOutOfTheLabBucket` | put, get and delete objects in that one bucket |

What the role deliberately **cannot** do: create or modify any IAM role, user
or policy; create or delete an S3 bucket; touch anything in another region;
touch any resource not tagged `Project=smol-lab`; launch anything bigger than
a `t3.small`.

That IAM gap is on purpose. AWS needs a `vmimport` service role to import a
disk image, and nivis's example creates it per deployment, which would hand
the lab every IAM write permission. The script below creates `vmimport` once
instead, and the lab points at it by name. See `experiments/000-nivis.md`
gap 3.

## Step 2: run the bootstrap

```sh
export SMOL_BUDGET_EMAIL=pim@technative.eu   # optional, gets the 80% alert
./infra/iam/bootstrap.sh playground-admin
```

It is safe to re-run: every step checks before it creates. It creates the lab
bucket, the `vmimport` role, the `smol-lab-ci` user, `SmolLabRole`, and a
monthly budget.

The budget is 55 USD, standing in for the agreed 50 EUR: AWS Budgets only
accepts the account's billing currency, and the playground account bills in
USD. Change `SMOL_BUDGET_AMOUNT` and `SMOL_BUDGET_UNIT` in `lab/config.env`
if that is wrong.

It deliberately does **not** create an access key, so no key is ever printed
by a script. That is the next step, and it is yours.

## Step 3: create the access key

CLI:

```sh
aws --profile playground-admin iam create-access-key --user-name smol-lab-ci
```

Console: IAM, Users, `smol-lab-ci`, Security credentials, Create access key,
pick "Command Line Interface", no description needed.

Either way you get an access key id and a secret. The secret is shown once.

## Step 4: put the key and the profiles in place

The key goes in `~/.aws/credentials`, nowhere else. Not in the repo, not in
`lab/config.env`, not in an environment variable, not in a chat message.

```ini
# ~/.aws/credentials
[smol-lab-base]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

```sh
chmod 600 ~/.aws/credentials
```

```ini
# ~/.aws/config
[profile smol-lab-base]
region = eu-central-1

[profile smol-lab]
role_arn = arn:aws:iam::<account-id>:role/SmolLabRole
source_profile = smol-lab-base
role_session_name = smol-lab
duration_seconds = 3600
region = eu-central-1
```

`<account-id>` is printed at the end of the bootstrap run.

The two-profile split is what makes long runs work: the SDK holds the key in
`smol-lab-base` and re-assumes `SmolLabRole` whenever the hour is up, without
anyone noticing.

## Step 5: verify

```sh
AWS_PROFILE=smol-lab aws sts get-caller-identity
```

The ARN should read `arn:aws:sts::<account-id>:assumed-role/SmolLabRole/smol-lab`.
If it shows the user instead of an assumed role, `role_arn` or
`source_profile` is wrong in `~/.aws/config`.

Then:

```sh
just aws-check
```

It prints one `PASS` line with the role ARN, or one `FAIL` line naming what is
missing. It never prints credentials or raw API output. Under the hood it does
a dry-run tagged launch, which creates nothing.

Tell Claude when this passes. Gate 2 is blocked until then.

## Rotating the key

```sh
aws --profile playground-admin iam create-access-key --user-name smol-lab-ci
# update ~/.aws/credentials, then:
aws --profile playground-admin iam delete-access-key \
  --user-name smol-lab-ci --access-key-id <the old one>
```

`smol-lab-ci` may hold at most two keys, so create the new one before deleting
the old.

## Tearing it all down

After the lab is finished:

```sh
just reap                                   # anything the lab left running
aws --profile playground-admin s3 rm s3://smol-lab-images-<account-id> --recursive
aws --profile playground-admin s3api delete-bucket --bucket smol-lab-images-<account-id>
aws --profile playground-admin iam delete-access-key --user-name smol-lab-ci --access-key-id <id>
aws --profile playground-admin iam delete-user-policy --user-name smol-lab-ci --policy-name smol-lab-assume-role
aws --profile playground-admin iam delete-user --user-name smol-lab-ci
aws --profile playground-admin iam delete-role-policy --role-name SmolLabRole --policy-name smol-lab-permissions
aws --profile playground-admin iam delete-role --role-name SmolLabRole
aws --profile playground-admin iam delete-role-policy --role-name vmimport --policy-name smol-lab-vmimport
aws --profile playground-admin iam delete-role --role-name vmimport
aws --profile playground-admin budgets delete-budget --account-id <account-id> --budget-name smol-lab
```

Run `just reap` first. The other commands do not touch running instances, and
an instance with no one watching it is the only thing here that costs real
money.

## If something is wrong

- **`just aws-check` says the role may not launch a tagged instance.** The
  permissions policy drifted from what the pipeline needs. Claude updates
  `infra/iam/SmolLabRole-permissions.json`, you re-run `bootstrap.sh`.
- **A deployment fails on a permission the policy does not have.** Same loop.
  The action list in `experiments/000-nivis.md` is marked `certain` or
  `likely`; the `likely` ones are exactly the ones expected to need a round
  of correction.
- **You want a different region.** Change `AWS_REGION` in `lab/config.env`,
  re-run `bootstrap.sh`, and update both profiles in `~/.aws/config`. The old
  region's resources are not migrated; reap them first.
