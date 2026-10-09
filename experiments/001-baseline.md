# 001: baseline

- **Track:** appliance
- **Contract:** 1
- **Module:** none, this is the reference
- **Branch:** `main`
- **Commit:** `cb99f41c`
- **Source:** `systems/baseline`, stock EC2 NixOS as nivis would deploy it

## Hypothesis

Not a hypothesis. This is the frozen reference every later measurement is
relative to (BRIEFING §4). It establishes what a stock NixOS EC2 image costs
before any `smol.*` option exists, and it proves the two gates agree.

## What changed

Nothing. `systems/baseline` imports `virtualisation/amazon-image.nix` with
`services.openssh.enable = true` and `stateVersion = "25.05"`. It is frozen
from here on; changing it invalidates the ledger and needs a new contract
epoch.

## Numbers

| measure            | bytes         | MiB     |
| ------------------ | ------------- | ------- |
| closure            | 1 589 904 712 | 1516.25 |
| image, raw VHD     | 2 724 876 288 | 2598.64 |
| image, compressed  | not produced  | n/a     |

Largest store paths:

| MiB    | path |
| ------ | ---- |
| 199.75 | the nixpkgs source checkout |
| 145.17 | `linux-6.18.55-modules` |
| 136.55 | `python3-3.14.7` |
| 110.09 | `amazon-ssm-agent-3.3.5226.0` |
| 63.02  | `systemd-261.3` |

The top five are already a backlog in themselves. The nixpkgs source and
`python3` have no business in an appliance image; `amazon-ssm-agent` is a
nivis or amazon-image default worth questioning; the module tree is the
single biggest removable thing and is already backlog item `e1`.

## Gate 1, local

Pass. Ten checks on first boot, ten again after reboot, under the NixOS test
driver with the gateway node supplying DNS, HTTPS and NTP.

Check 1 is skipped locally: there is no instance metadata service in QEMU.

## Gate 2, EC2

Pass. `t3.micro` in `eu-central-1`, instance `i-091e9071401aee589`, AMI
`ami-0279dce033c1eb082`.

Ten checks on first boot, ten after reboot. Boot time **40.753s**, measured
on the guest with `systemd-analyze`.

Two things gate 1 cannot show, both confirmed here:

- Check 1 passes: `/root/.ssh/authorized_keys` is a real file outside the nix
  store, so the key arrived through instance metadata rather than being baked
  into the image.
- The root device is `/dev/nvme0n1p2`, so the NVMe driver loaded and this is a
  genuine Nitro boot rather than a Xen fallback.

Teardown: all six resources destroyed. `just reap` afterwards reports nothing
to reap.

## Timing and cost

One gate 2 run, end to end:

| step | duration |
| ---- | -------- |
| image build, cold | roughly 20 min |
| upload 2.6 GiB to S3 | 2m52s |
| EBS snapshot import | 7m51s |
| launch to first SSH | under 1 min |
| contract, reboot, contract | about 2 min |
| teardown | under 1 min |

So about **15 minutes per experiment** once the image is built, dominated by
the snapshot import, which is AWS and not something the lab can speed up. The
upload shrinks as the image does, which is the point.

## Decision

Baseline recorded. Ledger line 1.

## Surprises

Three IAM gaps, all now in `GOTCHAS.md`:

1. `ec2:CreateSecurityGroup` is authorised against the VPC as well as the new
   group, and the VPC carries no request tag.
2. `ec2:ImportSnapshot` needs `iam:PassRole` on the `vmimport` role.
3. `ec2:RegisterImage` registers first and tags afterwards, so there is no
   request tag to condition on either.

Each cost a round trip, and the second and third cost eleven minutes of
upload and import to discover. `just aws-probe` now does dry-run
authorisation checks for `RegisterImage` and `RunInstances` alongside the two
real cheap creates, so the next gap of this kind is found in seconds.
