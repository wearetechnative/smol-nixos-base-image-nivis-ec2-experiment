---
# smol-nixos-base-image-nivis-ec2-experiment-mlca
title: AWS access, IAM and the setup Pim runs
status: in-progress
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T12:01:07Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

Claude never sees a secret and never runs the bootstrap. Done: Pim has run bootstrap.sh and `just aws-check` passes.

- [ ] derive the minimal IAM actions from what nivis actually calls
- [ ] `infra/iam/smol-lab-ci-policy.json`
- [ ] `infra/iam/SmolLabRole-trust.json`
- [ ] `infra/iam/SmolLabRole-permissions.json` with region lock, tag conditions and instance type limits
- [ ] `infra/iam/bootstrap.sh`, written by Claude and run only by Pim
- [ ] `docs/SETUP-AWS.md` walkthrough
- [ ] `lab/aws-check.sh`: get-caller-identity plus a dry run tagged launch, pass or fail only
- [ ] AWS Budget alert amount agreed with Pim
- [ ] ask Pim: region, budget amount, whether the mutable track is wanted
- [ ] stop and wait for Pim to confirm the setup is done
