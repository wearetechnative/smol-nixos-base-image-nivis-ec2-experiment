---
# smol-nixos-base-image-nivis-ec2-experiment-jd12
title: nivis deploy adapter and gate 2
status: completed
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T14:42:54Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
blocked_by:
    - smol-nixos-base-image-nivis-ec2-experiment-mlca
---

Deploy through nivis, never through hand written AWS calls. Done: `just gate2 <experiment>` builds an image, registers an AMI, launches, verifies, reboots, verifies, and tears everything down, pass or fail.

- [x] read how nivis builds images, registers AMIs and launches instances
- [x] `experiments/000-nivis.md`: what nivis can and cannot do for the lab
- [x] `lab/deploy-ec2.sh` as a thin adapter, tagging Project=smol-lab and Experiment=<id>
- [x] push the static curl to the target before verifying, as gate 1 does
- [x] `lab/console.sh`: fetch serial console output when SSH never comes up
- [x] `lab/reap.sh`: terminate and deregister everything tagged Project=smol-lab older than N minutes
- [x] teardown is unconditional, proven by three real failing runs
- [x] three gaps written up and proposed to Pim, not worked around
- [x] add a key pair and SSH ingress to the plan; the nivis example only opens port 80

- [x] confirm the `likely` IAM actions against a real deployment: three were wrong, all fixed and recorded

## Summary of Changes

Gate 2 is real. `just gate2 000-baseline baseline` deploys through nivis,
verifies twice around a reboot and tears everything down.

Baseline: 1516.25 MiB closure, 2598.64 MiB raw VHD, 40.753s boot, 10 of 10
contract checks on both boots. Ledger line 1.

Two things only gate 2 can show, both confirmed: contract check 1 passes, so
the SSH key really arrives through instance metadata; and the root device is
/dev/nvme0n1p2, so this is a genuine Nitro boot.

Three IAM gaps found by running it, all in GOTCHAS.md. `just aws-probe` now
dry-runs RegisterImage and RunInstances so the next one costs seconds.
