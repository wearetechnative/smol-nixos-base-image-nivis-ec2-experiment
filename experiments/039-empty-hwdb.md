# 038 and 039: empty-hwdb

Two ledger lines, one result. Accepted at #39.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.emptyHwdb`
- **Source:** siraben, backlog item `s9`

## Hypothesis

`/etc/udev/hwdb.bin` is 13.21 MiB of vendor and model properties for USB
devices, PCI cards, keyboards, pointing devices and accelerometers. A Nitro
instance has an ENA adapter and an NVMe disk.

## What changed

There is no NixOS option. `services/hardware/udev.nix` builds `hwdb.bin`
from the `hwdb.d` files of udev and every package in
`services.udev.packages`, and wires it into `environment.etc` with no
switch, so the override replaces the file.

## Numbers

| measure      | before      | after       | delta         |
| ------------ | ----------- | ----------- | ------------- |
| closure      | 540 043 920 | 526 195 992 | 13 847 928    |
| closure, MiB | 515.03      | 501.82      | 13.21, 2.6%   |
| image, MiB   | 630.16      | 614.16      | 16.00, 2.5%   |

The delta matches the file exactly, which is what a clean single-consumer
removal looks like.

## Experiment 38: rejected, build failed

```
No hwdb files found, skipping.
mv: cannot stat 'etc/udev/hwdb.bin': No such file or directory
```

`systemd-hwdb update` finds no input, says so, **exits successfully** and
writes nothing. The obvious implementation of "an empty database" therefore
produces no database at all. One placeholder entry that matches nothing is
enough to get a valid file out of it.

## Gate 1, local

Pass at #39.

## Gate 2, EC2

Pass at #39. Boot time **12.436s**, the fastest recorded. Ten checks on both
boots. Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only. A machine with real peripherals
would get wrong keyboard mappings and missing device metadata; a machine
with two virtual devices notices nothing.

## Surprises

Only that a tool can report "skipping" on empty input, exit zero, and leave
the caller to discover the missing file. Worth remembering for the other
generated databases in this image.
