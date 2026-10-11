# 042: minimal-initrd-modules

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.minimalInitrdModules`
- **Source:** siraben, backlog item `s5`

## Hypothesis

`boot.initrd.availableKernelModules` is 35 modules: IDE and SATA
controllers, USB host controllers of three generations, MMC, PS/2 keyboards
and eight separate USB HID drivers. A Nitro instance has an NVMe disk and an
ENA adapter, and `smol.noKernelModules` already pins `ena` separately.

## Numbers

| measure      | before      | after       | delta       |
| ------------ | ----------- | ----------- | ----------- |
| closure, MiB | 489.07      | 487.66      | 1.41, 0.3%  |
| image, MiB   | 600.16      | 596.16      | 4.00, 0.7%  |

**The premise was wrong.** The initrd is 24.77 MiB and its module tree is
2.7 MiB of that; the rest is the systemd userland it has to carry because
`smol.noKernelModules` force-loads `ena`, `af_packet`, `fuse` and `configfs`
there. Trimming 33 of 35 modules was never going to be worth much, and
checking the size of `modules-shrunk` first would have said so.

## Gate 1, local

**Fail**, kernel panic at 302 seconds.

The test VM mounts its nix store over virtio and 9p, and this list removes
the modules for both. It is the same constraint the kernel config hit in
experiment 12: **one list has to satisfy both gates**, because gate 1 boots
the identical configuration under QEMU where every device is virtio.

## Gate 2, EC2

Not reached. No AWS resources created.

## Decision

**Rejected**, and not retried.

It could be made to pass with an escape hatch, the way
`smol.minimalSystemPackages.extra` lets `lab/test-support/qemu.nix` put
netcat back. That is a lot of machinery for 1.41 MiB of closure, which is
inside BRIEFING §9's stop-criterion band of "less than 1% or less than 2
MiB".

The module is kept and not enabled in any profile, with the finding in its
description.

## Surprises

The useful part is the size breakdown rather than the result. The initrd
looked like a 24.77 MiB target full of unnecessary drivers; it is a 24.77
MiB target that is mostly a systemd userland this lab put there itself, in
experiment 17, by requiring four modules to be force-loaded before
switch-root.

That is worth saying plainly: **`smol.noKernelModules` saved 152.93 MiB and
made the initrd harder to shrink.** The two interact, and the second number
is not visible from either experiment on its own.
