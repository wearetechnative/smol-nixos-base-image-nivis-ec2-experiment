---
# smol-nixos-base-image-nivis-ec2-experiment-b0eo
title: Kernel and initrd for Nitro
status: todo
type: epic
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-09T11:51:38Z
parent: smol-nixos-base-image-nivis-ec2-experiment-6waj
---

Item e1 of BACKLOG.md, the one hypothesis with the largest expected saving. A kernel with ENA and NVMe built in needs no loadable modules at all.

- [ ] measure what the stock kernel and its modules cost in the accepted closure
- [ ] a Nitro kernel config with ENA, NVMe and the EC2 essentials built in
- [ ] prove it boots on a Nitro type through gate 2
- [ ] decide what happens to the Xen based types, and record it
- [ ] drop the module tree once the kernel carries everything
