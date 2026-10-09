## Why

Gate 2 deploys to real EC2 through nivis, so the lab needs AWS credentials
that survive long autonomous sessions. BRIEFING §7 fixes the design: a
playground account, an IAM user whose only permission is to assume one role,
and AWS CLI profiles so the SDK re-assumes that role automatically and a long
run never breaks on an expired token.

The hard constraint is that Claude never sees a secret. Claude writes the
policies and the bootstrap script; Pim runs them. This change produces exactly
those artifacts, and it blocks the nivis adapter epic and therefore every
gate 2 result in milestone `01 Bootstrap the lab`.

## What Changes

- Three IAM policy documents under `infra/iam/`: the user policy, the role
  trust policy and the role permissions policy. The permissions are derived
  from the AWS API actions nivis actually calls, read out of its source, not
  guessed from a wildcard.
- The role is fenced in: region locked with `aws:RequestedRegion`, create
  actions require `aws:RequestTag/Project=smol-lab`, destructive actions only
  on resources already tagged `Project=smol-lab`, and `ec2:InstanceType`
  limited to the agreed small types.
- `infra/iam/bootstrap.sh`, which creates the user, the role, the policies,
  the lab bucket if nivis needs one, and the budget alert. It takes Pim's own
  admin profile as an argument. Claude writes it and never runs it.
- `docs/SETUP-AWS.md`: a walkthrough for Pim from prerequisites to teardown,
  explaining each permission in one line.
- `lab/aws-check.sh` behind `just aws-check`: proves the assumed role works
  and that a correctly tagged launch would be permitted, printing only
  pass/fail and the role ARN.

## Capabilities

### New Capabilities

- `lab/aws-access`: how the lab reaches AWS, what it is permitted to do, and
  the boundary between what Claude writes and what Pim runs.

## Impact

- New: `infra/iam/*.json`, `infra/iam/bootstrap.sh`, `docs/SETUP-AWS.md`,
  `lab/aws-check.sh`.
- `justfile`: the `aws-check` recipe starts working.
- `lab/config.env`: Pim fills in the region after this change lands.
- Blocks: the nivis deploy adapter epic, and with it every gate 2 run.
- Needs from Pim before it can be applied: the region, the budget amount, and
  whether the mutable track is wanted.
