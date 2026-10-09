# STATE

Single source of truth for where the lab is right now (BRIEFING §10). Update
it at every step change, not at the end of a session.

## Phase

Phase 0, bootstrap. The scaffolding is in place and gate 1 is green on
`systems/accepted`. No experiment has run yet, and the ledger is empty.

## Current experiment

`000-baseline`, step `gate2`, change `add-nivis-ec2-gate`, 33 of 42 tasks.

The harness is built and the first real run got as far as
`ec2:CreateSecurityGroup`. **Blocked on Pim re-running
`./infra/iam/bootstrap.sh <admin-profile>`** to apply the corrected policy.

After that: `just aws-probe`, then `just gate2 000-baseline baseline`.

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

`just reap-dry` reports nothing to reap. The failed run of 2026-10-09 tore
down its own key pair and uploaded image through the trap.

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

## AWS access

Working since 2026-10-09. `just aws-check`:

```
PASS: arn:aws:sts::076504012268:assumed-role/SmolLabRole/smol-lab
      region eu-central-1, tagged launch of t3.micro permitted
```

The lab's AWS profiles live in `lab/aws-config`, generated from
`lab/config.env` and selected with `AWS_CONFIG_FILE`, because `~/.aws/config`
is managed by home-manager here. The access key is in `~/.aws/credentials`
under `[smol-lab-base]`.

Nothing is blocked any more.

## Still open, not blocking

- Is the mutable track wanted, or is the appliance track enough for the alpha?
  Only affects milestone `03`, and the "Mutable track" epic carries it.
- Eleven actions in `experiments/000-nivis.md` are marked `likely` rather than
  `certain`. The first real deployment confirms or corrects them; expect one
  round of "add this action, re-run bootstrap.sh".

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

## What the first gate 2 attempt established

- The image is 2.6 GiB as a VHD, and uploads to S3 in 2m49s.
- Teardown on failure works unprompted: the run died mid-apply and the trap
  destroyed the key pair and the uploaded image.
- One IAM gap, now fixed in `infra/iam/SmolLabRole-permissions.json`:
  `ec2:CreateSecurityGroup` is authorised against the new group *and* the VPC
  it goes in, and the VPC carries no request tag. The statement is split so
  created resources keep the tag condition and referenced ones get region
  only.
- `ec2:ImportSnapshot`, `ec2:RegisterImage` and `ec2:RunInstances` are still
  unproven: nothing has reached them yet.

## What is missing before the first experiment

- `lab/experiment.sh`, the pipeline that appends a ledger line

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
