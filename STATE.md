# STATE

Single source of truth for where the lab is right now (BRIEFING §10). Update
it at every step change, not at the end of a session.

## Phase

Phase 0, bootstrap. The scaffolding is in place and gate 1 is green on
`systems/accepted`. No experiment has run yet, and the ledger is empty.

## Current experiment

None. Next action is the OpenSpec change `add-aws-lab-access`, under the epic
"AWS access, IAM and the setup Pim runs". It is blocked on three answers from
Pim, listed below.

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

## Open questions for Pim

Blocking, in the order they are needed:

1. Which AWS region does the lab run in? Goes into `lab/config.env`.
2. What amount for the AWS Budget alert on the playground account?
3. Is the mutable track wanted, or is the appliance track enough for the
   alpha?

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

## What is missing before the first experiment

- `lab/deploy-ec2.sh`, `lab/console.sh`, `lab/reap.sh`, `lab/aws-check.sh`
- `lab/experiment.sh`, the pipeline that appends a ledger line
- the AWS setup Pim runs, from `docs/SETUP-AWS.md`

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
