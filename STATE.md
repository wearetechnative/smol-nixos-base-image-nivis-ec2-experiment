# STATE

Single source of truth for where the lab is right now (BRIEFING §10). Update
it at every step change, not at the end of a session.

## Phase

Phase 0, bootstrap, essentially complete. Both gates are green on
`systems/baseline` and the ledger has its first line. What is left of phase 0
is `lab/experiment.sh`, the pipeline that ties build, measure, both gates and
the ledger together.

## Current experiment

None in flight. Experiment 001 is recorded and the account is empty.

| field         | value |
| ------------- | ----- |
| experiment id | 1, done |
| slug          | baseline |
| step          | logged |
| branch        | main |

Steps are `building | measuring | gate1 | gate2 | logging`.

## The baseline, frozen

Ledger line 1. `systems/baseline` does not change from here.

| measure           | value |
| ----------------- | ----- |
| closure           | 1516.25 MiB |
| image, raw VHD    | 2598.64 MiB |
| boot time         | 40.753s |
| gate 1            | pass, 10 of 10, twice |
| gate 2            | pass, 10 of 10, twice |

Largest paths: the nixpkgs source at 199.75 MiB, `linux-6.18.55-modules` at
145.17, `python3-3.14.7` at 136.55, `amazon-ssm-agent` at 110.09, `systemd`
at 63.02. The first four have no obvious business in an appliance image.

## Cost of one experiment

About 15 minutes of gate 2 once the image is built: 2m52s upload, 7m51s
snapshot import, 3 minutes to verify twice, under a minute to tear down. The
snapshot import dominates and is AWS's. BRIEFING §9 stops at 4 EC2 hours in a
session, which is roughly 16 runs.

## Live AWS resources

None. If this table is non-empty on resume, run `just reap` before anything
else.

| kind | id  | region | created |
| ---- | --- | ------ | ------- |
| none | n/a | n/a    | n/a     |

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

## Decided with Pim, 2026-10-09, second round

Claude runs `infra/iam/bootstrap.sh` and may call `aws` directly. Recorded as
an amendment in BRIEFING §7, because the briefing said the opposite and the
briefing wins where the repo disagrees with it.

The trade, stated plainly: Claude can now rewrite `SmolLabRole`, so the fence
around the playground account is no longer one Claude cannot move. Reading
anything from `~/.aws/` is still denied, and no secret is ever printed.

Pim applied the matching edit to `.claude/settings.json` on 2026-10-09. The
harness blocks an agent from editing its own allow list, which is the right
default and worth keeping, so that edit stays a human one.

## Still open, not blocking

- Is the mutable track wanted, or is the appliance track enough for the alpha?
  Only affects milestone `03`, and the "Mutable track" epic carries it.
- The Graviton track needs an aarch64 builder or emulation. Until then
  `nix flake check` evaluates those outputs but cannot build them.

## What already works

- `nix flake check` passes: gate 1 for both `candidate` and `accepted`, plus
  shellcheck on `lab/*.sh`. It builds x86_64-linux only; aarch64-linux
  evaluates but is omitted as incompatible, so the Graviton track needs a
  builder before it means anything.
- `just gate1 accepted` passes all ten contract checks on first boot and again
  after a reboot.
- `just measure <variant>` emits the measurement JSON, including image size
  when `SMOL_IMAGE` points at a built image.
- `just gate2 <id> <variant>` deploys through nivis, verifies twice around a
  reboot, and tears everything down.
- `just aws-check`, `just aws-probe`, `just reap`, `just reap-dry`,
  `just console <instance>`.
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

## What gate 2 established

- Check 1 passes on EC2: `/root/.ssh/authorized_keys` is a real file outside
  the nix store, so the key arrives through instance metadata. Gate 1 can
  only skip this.
- The root device is `/dev/nvme0n1p2`, so NVMe loaded and this is a genuine
  Nitro boot. This is the check a kernel or initrd trim is most likely to
  break.
- Teardown is unconditional and proven: three failed attempts each cleaned up
  after themselves without being asked, including the EBS snapshot.
- Three IAM gaps, all found by running it and all now in `GOTCHAS.md`:
  `CreateSecurityGroup` is authorised against the VPC too, `ImportSnapshot`
  needs `iam:PassRole` on `vmimport`, and `RegisterImage` tags after
  registering so there is no request tag to condition on.
- `just aws-probe` now dry-runs `RegisterImage` and `RunInstances` as well as
  really creating the cheap pair, so the next gap of that kind costs seconds.
  Only `ImportSnapshot` still needs a real upload to reach.

## What is missing before experiment 2

- `lab/experiment.sh`, the pipeline of BRIEFING §8 that ties build, measure,
  gate 1, gate 2 and the ledger line together. Right now those are run by
  hand.

## Next three planned experiments

1. `lab/experiment.sh`, so an experiment is one command rather than four.
2. Replay natkr n1: `documentation.enable = false`.
3. Replay natkr n2: `environment.defaultPackages = [ ]`.

Worth jumping the queue: the baseline's top five paths include the nixpkgs
source (199.75 MiB), `python3` (136.55) and `amazon-ssm-agent` (110.09).
Those are not on the natkr or siraben lists because an ISO never had them,
and together they are more than a quarter of the closure.

## Checkpoints

Write one every 5 experiments.

- 2026-10-09: repo scaffolded. Flake without flake-utils, `smol.*` module
  skeleton with profile and track, verification contract v1, gate 1 green with
  a gateway node that makes the DNS, HTTPS and NTP checks real, four beans
  milestones with their epics, OpenSpec initialised with the first change
  proposed.
