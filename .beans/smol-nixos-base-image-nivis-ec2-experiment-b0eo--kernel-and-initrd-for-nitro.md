---
# smol-nixos-base-image-nivis-ec2-experiment-b0eo
title: Kernel and initrd for Nitro
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-13T07:16:57Z
parent: smol-nixos-base-image-nivis-ec2-experiment-6waj
---

Item e1 of BACKLOG.md, the one hypothesis with the largest expected saving. A kernel with ENA and NVMe built in needs no loadable modules at all.

- [ ] measure what the stock kernel and its modules cost in the accepted closure
- [ ] a Nitro kernel config with ENA, NVMe and the EC2 essentials built in
- [ ] prove it boots on a Nitro type through gate 2
- [ ] decide what happens to the Xen based types, and record it
- [x] drop the module tree, accepted #17; done without a custom kernel, since the 145 MiB was in the module tree rather than the kernel image

## Summary of Changes

Kernel and initrd. `noKernelModules` 152.93 MiB after three rejections that each named a missing module. `nitroKernel` rejected: a trimmed config derails nixpkgs' `make config`. `minimalInitrdModules` rejected: the initrd is a userland, not a module tree. `xzInitrd` accepted at 4.23 MiB and 2.5 seconds of boot.
