## Why

Gate 1 proves a candidate boots in QEMU. It cannot prove the thing the lab is
actually about: that a trimmed image still boots on Nitro, finds its ENA and
NVMe devices, and picks up an SSH key from instance metadata. Every one of
those is exactly what a size reduction is most likely to break, and all three
are invisible locally.

This change makes gate 2 real. It belongs to phase 0 (BRIEFING §6, §8.4) and
to milestone `01 Bootstrap the lab`. Nothing in `ledger.jsonl` can be written
until it lands, because a ledger line records both gates.

The groundwork is done: `experiments/000-nivis.md` maps the pipeline and the
AWS actions, and `just aws-check` passes against `SmolLabRole`.

## What Changes

- A nivis plan exposed as the flake's `nivis.plan` output, parameterised with
  `mkVars` over variant, experiment id, region, instance type and SSH public
  key. It reuses the shape of nivis's own `nix/example/ec2.nix` with three
  deliberate differences:
  - an `aws_key_pair`, and `key_name` on the instance, so the key reaches the
    guest through IMDS rather than being baked into the image. Contract check
    1 depends on this.
  - security group ingress on 22 instead of 80.
  - no `aws_s3_bucket` and no `aws_iam_role`: the lab bucket and the
    `vmimport` role already exist, created once by `infra/iam/bootstrap.sh`,
    so `SmolLabRole` needs no IAM or bucket write permission.
- `default_tags` on the provider carrying `Project=smol-lab` and
  `Experiment=<id>`, which is what the IAM conditions key on.
- `lab/deploy-ec2.sh`: apply, wait for SSH, push the static curl, run
  `lab/verify.sh`, reboot, run it again, record boot time, tear down. The
  teardown is in a trap so it runs on every exit path, including a failure
  and a Ctrl-C.
- `lab/console.sh`: `ec2:GetConsoleOutput` for an instance that never answers
  SSH, saved into the experiment note.
- `lab/reap.sh`: `nivis destroy` for every state file the lab left behind,
  then a tag-and-age sweep for orphans nivis has no state for.
- An ephemeral SSH keypair per run, generated into a temp dir and deleted on
  exit. Nothing is committed and no key is reused between experiments.

## Capabilities

### New Capabilities

- `lab/ec2-gate`: deploying a candidate to EC2 through nivis, verifying it
  there against the same contract gate 1 runs, and guaranteeing teardown.

## Impact

- New: `lab/nivis-plan.nix`, `lab/deploy-ec2.sh`, `lab/console.sh`,
  `lab/reap.sh`.
- `flake.nix` gains a `nivis.plan` output and the image build targets.
- `justfile`: `gate2`, `reap` and `console` start working.
- `experiments/000-nivis.md`: the eleven `likely` IAM actions get confirmed or
  corrected against a real run, which may mean one round of editing
  `infra/iam/SmolLabRole-permissions.json` and re-running `bootstrap.sh`.
- First real spend. A `t3.micro`, an EBS snapshot and roughly 2 GB in S3 per
  run, all removed at the end. Minutes, not hours.
- Unblocks: the baseline numbers epic, and with it every experiment.
