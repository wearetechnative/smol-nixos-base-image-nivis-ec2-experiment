---
# smol-nixos-base-image-nivis-ec2-experiment-jd12
title: nivis deploy adapter and gate 2
status: in-progress
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T12:10:51Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
blocked_by:
    - smol-nixos-base-image-nivis-ec2-experiment-mlca
---

Deploy through nivis, never through hand written AWS calls. Done: `just gate2 <experiment>` builds an image, registers an AMI, launches, verifies, reboots, verifies, and tears everything down, pass or fail.

- [x] read how nivis builds images, registers AMIs and launches instances
- [x] `experiments/000-nivis.md`: what nivis can and cannot do for the lab
- [ ] `lab/deploy-ec2.sh` as a thin adapter, tagging Project=smol-lab and Experiment=<id>
- [ ] push the static curl to the target before verifying, as gate 1 does
- [ ] `lab/console.sh`: fetch serial console output when SSH never comes up
- [ ] `lab/reap.sh`: terminate and deregister everything tagged Project=smol-lab older than N minutes
- [ ] teardown is unconditional, proven by a deliberate failing run
- [x] three gaps written up and proposed to Pim, not worked around
- [ ] add a key pair and SSH ingress to the plan; the nivis example only opens port 80
