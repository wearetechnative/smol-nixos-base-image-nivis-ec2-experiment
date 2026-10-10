# 012: nitro-kernel

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.nitroKernel`
- **Source:** backlog item `e1`

## Hypothesis

The kernel module tree is 145.17 MiB and the largest path left by a wide
margin. 115 MiB of it is `drivers`, broken down as:

| MiB | directory |
| --- | --------- |
| 29  | net |
| 15  | media |
| 13  | gpu |
| 5.8 | scsi |
| 5.8 | iio |
| 4.1 | usb |
| 3.1 | infiniband |

Plus 15 MiB of `sound` outside `drivers`. A Nitro instance has none of that
hardware and never will. Build ENA, NVMe and ext4 in, turn the unused
subsystems off, and most of the tree should stop existing.

## What changed

`boot.kernelPatches` with a `structuredExtraConfig` turning off sound, DRM,
media, IIO, infiniband, wireless, staging, hwmon, watchdog, bluetooth, MMC,
PCMCIA and the input device classes, while forcing ENA, NVMe, ext4, virtio
and the 8250 serial console on.

virtio and 9p are kept deliberately: gate 1 boots this same kernel under
QEMU, so a kernel that only works on Nitro could not be tested locally at
all.

## Numbers

None. The kernel configuration step failed before any compilation.

## Gate 1, local

Not reached.

## Gate 2, EC2

Not reached. No AWS resources created.

## Decision

**Rejected: build failed**, in the kernel configuration rather than the
compile.

```
Error in reading or end of file.     [387 times]
```

nixpkgs builds the kernel config by driving `make config` with a script that
answers prompts from the structured configuration. Turning off a subsystem
changes which symbols are reachable, and therefore which prompts appear and
in what order, so the script runs off the end of its answers and every
remaining prompt reports EOF. The error names no symbol, which makes it
expensive to bisect: each attempt is a full config run.

Two implementation errors were fixed before reaching this point, and are
worth recording separately because they are cheap to hit:

- `boot.kernelPatches` takes `structuredExtraConfig`, not
  `extraStructuredConfig`. The latter is rejected with a clear message.
- Every entry needs `lib.mkForce`. nixpkgs' `common-config.nix` already has
  an opinion about nearly all of these symbols, and a structured kernel
  config conflicts rather than merges.

## Decision about what to do instead

The 145.17 MiB lives in the **module tree**, not in the kernel image. Dropping
`$out/kernel-modules` from the system closure removes all of it without
recompiling anything, which is natkr's `n7`, and it does not need the kernel
config touched at all. That became experiment 013.

A trimmed kernel is still worth having afterwards, for the `bzImage` and the
initrd rather than the module tree, and for the honest reason that a kernel
carrying drivers it can never use is untidy. But it is a much smaller prize
than it looked, and the right order was the other way round.

## Surprises

The framing was wrong rather than the implementation. "Shrink the kernel" and
"stop shipping 145 MiB of modules" look like the same task and are not: one
is a day of fighting kconfig, the other is one line in the system builder.
Checking **where** a large path is referenced from, before deciding how to
remove it, would have caught that before the compile was ever started.
