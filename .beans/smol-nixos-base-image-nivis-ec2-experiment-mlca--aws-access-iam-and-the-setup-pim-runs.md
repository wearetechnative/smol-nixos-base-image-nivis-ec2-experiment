---
# smol-nixos-base-image-nivis-ec2-experiment-mlca
title: AWS access, IAM and the setup Pim runs
status: in-progress
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T12:23:32Z
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
- [ ] stop and wait for Pim to confirm the setup is done
