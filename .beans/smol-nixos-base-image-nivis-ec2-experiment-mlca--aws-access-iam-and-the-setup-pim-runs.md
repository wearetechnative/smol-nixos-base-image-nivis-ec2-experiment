---
# smol-nixos-base-image-nivis-ec2-experiment-mlca
title: AWS access, IAM and the setup Pim runs
status: completed
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T12:44:19Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

Claude never sees a secret and never runs the bootstrap. Done: Pim has run bootstrap.sh and `just aws-check` passes.

- [x] derive the minimal IAM actions from what nivis actually calls
- [x] `infra/iam/smol-lab-ci-policy.json`
- [x] `infra/iam/SmolLabRole-trust.json`
- [x] `infra/iam/SmolLabRole-permissions.json` with region lock, tag conditions and instance type limits
- [x] `infra/iam/bootstrap.sh`, written by Claude and run only by Pim
- [x] `docs/SETUP-AWS.md` walkthrough
- [x] `lab/aws-check.sh`: get-caller-identity plus a dry run tagged launch, pass or fail only
- [x] AWS Budget alert amount agreed with Pim: 50 EUR, created as 55 USD because the account bills in USD
- [x] ask Pim: region eu-central-1, budget 50 EUR, mutable track still open
- [x] stop and wait for Pim to confirm the setup is done

## Summary of Changes

AWS access works. `just aws-check` returns PASS on
`arn:aws:sts::076504012268:assumed-role/SmolLabRole/smol-lab`, region
eu-central-1, with a tagged t3.micro launch permitted.

Delivered: five policy documents under `infra/iam/`, `bootstrap.sh` for Pim
to run, `docs/SETUP-AWS.md`, `lab/aws-key.sh` and `lab/aws-check.sh`.

Two deviations from BRIEFING section 7, both recorded in GOTCHAS.md:

1. The vmimport role and the lab bucket are created once by the bootstrap
   rather than per deployment, so SmolLabRole needs no IAM write permission
   and no s3:CreateBucket.
2. The lab keeps its AWS profiles in `lab/aws-config` rather than
   `~/.aws/config`, which is managed by home-manager and read-only. The key
   still lives in `~/.aws/credentials`.

Carried forward: confirming the eleven `likely` IAM actions is a task on the
nivis deploy adapter epic, since only a real deployment can do it.
