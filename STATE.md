# STATE

Single source of truth for where the lab is right now (BRIEFING §10). Update
it at every step change, not at the end of a session.

## Phase

Phase 0, bootstrap. The scaffolding is in place and gate 1 is green on
`systems/accepted`. No experiment has run yet, and the ledger is empty.

## Current experiment

None. The OpenSpec change `add-aws-lab-access` is written out: the five policy
documents, `infra/iam/bootstrap.sh`, `docs/SETUP-AWS.md` and
`lab/aws-check.sh`. Task 6.2 is the only thing left in it, and it is Pim's.

| field          | value |
| -------------- | ----- |
| experiment id  | -     |
| slug           | -     |
| step           | -     |
| branch         | -     |

Steps are `building | measuring | gate1 | gate2 | logging`.

## Live AWS resources

None. If this table is non-empty on resume, run `just reap` before anything
else.

| kind | id | region | created |
| ---- | -- | ------ | ------- |
| -    | -  | -      | -       |

## Decided with Pim, 2026-10-09

- Region: `eu-central-1`, in `lab/config.env`.
- The `vmimport` role and the lab bucket are created once by
  `infra/iam/bootstrap.sh`, not per deployment. `SmolLabRole` therefore has no
  IAM write permission and no `s3:CreateBucket`.
- `lab/console.sh` and the `lab/reap.sh` fallback may call `aws ec2` directly.
  Both are read-only diagnostics or tag-filtered cleanup on resources the lab
  created, not a deployment path. Deployment still goes through nivis only.
- Budget: 50 EUR per month, alert at 80 percent.
- Instance types: `t3.micro` and `t3.small`, enforced by the IAM policy.

## Waiting on Pim

**The lab is blocked here.** `docs/SETUP-AWS.md` is the walkthrough:

1. `./infra/iam/bootstrap.sh <admin-profile>` on the playground account.
2. Create one access key for `smol-lab-ci`, put it in `~/.aws/credentials`,
   put the two profiles in `~/.aws/config`.
3. `just aws-check` should print one `PASS` line.

Say when it passes. Nothing on EC2 can run before that.

## Still open, not blocking

- Is the mutable track wanted, or is the appliance track enough for the alpha?
  Only affects milestone `03`.

## What already works

- `nix flake check` passes: gate 1 for both `candidate` and `accepted`, plus
  shellcheck on `lab/*.sh`. It builds x86_64-linux only; aarch64-linux
  evaluates but is omitted as incompatible, so the Graviton track needs a
  builder before it means anything.
- `just gate1 accepted` passes all ten contract checks on first boot and again
  after a reboot.
- `just measure <variant>` emits the measurement JSON. First reading on
  `systems/accepted`, which is still identical to the baseline: **1516 MiB
  closure**, largest paths `linux-6.18.55-modules` at 145 MiB and
  `python3-3.14.7` at 137 MiB. Not a ledger entry; the ledger starts once
  gate 2 exists.
- `just docs` regenerates `docs/options.md`.

## What nivis covers, and what it does not

`experiments/000-nivis.md` has the detail. nivis drives the whole pipeline:
build, upload, snapshot import, AMI registration, launch, reading the public
IP back out of state, and teardown in reverse order. Region and instance type
go in through `mkVars`; tagging through `default_tags` on the provider.

Three things it does not cover: serial console output, orphans from a run that
died before writing state, and SSH itself. The example pipeline opens port 80
and has no key pair, so `lab/deploy-ec2.sh` adds an `aws_key_pair` and ingress
on 22. That key pair is what makes contract check 1 real.

## What is missing before the first experiment

- `lab/deploy-ec2.sh`, `lab/console.sh`, `lab/reap.sh`
- `lab/experiment.sh`, the pipeline that appends a ledger line
- the AWS setup Pim runs, from `docs/SETUP-AWS.md`

`lab/aws-check.sh` and the IAM artifacts are written and waiting to be run.

## Next three planned experiments

1. Establish baseline numbers for `systems/baseline` through both gates.
2. Replay natkr n1: `documentation.enable = false`.
3. Replay natkr n2: `environment.defaultPackages = [ ]`.

## Checkpoints

Write one every 5 experiments.

- 2026-10-09: repo scaffolded. Flake without flake-utils, `smol.*` module
  skeleton with profile and track, verification contract v1, gate 1 green with
  a gateway node that makes the DNS, HTTPS and NTP checks real, four beans
  milestones with their epics, OpenSpec initialised with the first change
  proposed.
