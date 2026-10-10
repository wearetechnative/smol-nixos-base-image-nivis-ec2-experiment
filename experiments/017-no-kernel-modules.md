# 017: no-kernel-modules

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noKernelModules`
- **Source:** natkr, backlog item `n7`

## Hypothesis

Third attempt at the same idea. Experiments 013, 015 and 016 established the
shape: the 145 MiB module tree hangs off one symlink in the system builder,
and removing it means everything the running system needs must already be
loaded. The question each attempt answered was *what exactly that list is*.

## What changed

```nix
boot.initrd.kernelModules = [ "ena" "af_packet" "fuse" "configfs" ];

system.systemBuilderCommands = lib.mkAfter ''
  rm -f $out/kernel-modules
'';
```

Four modules, each one bought with a failed deployment or a config read:

| module | why | found by |
| ------ | --- | -------- |
| `ena` | the network adapter; udev only loads root-device modules in the initrd | exp 015 |
| `af_packet` | `CONFIG_PACKET=m`, and dhcpcd needs an `AF_PACKET` socket to send a DHCP request at all | exp 016 |
| `fuse` | `CONFIG_FUSE_FS=m` | kernel config |
| `configfs` | `CONFIG_CONFIGFS_FS=m`, mounted by systemd during early boot | kernel config |

`nvme` needs no entry: it is already in
`boot.initrd.availableKernelModules`, so udev loads it in the initrd to find
the root device.

## Numbers

| measure      | before      | after       | delta          |
| ------------ | ----------- | ----------- | -------------- |
| closure      | 892 396 888 | 732 042 408 | 160 354 480    |
| closure, MiB | 851.07      | 698.13      | 152.93, 18.0%  |

**The largest single saving in this lab**, and larger than the 145.17 MiB
module tree itself: the dependency metadata and firmware leave with it.

**698.13 MiB, 54.0% off the 1516.25 MiB baseline.**

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot. Gate 1 passed on 015 and
016 too, which is the point below.

## Gate 2, EC2

Pass. Instance `i-03892b661e9235062`, AMI `ami-0220ca2a8fd16e797`.

Ten checks on first boot, ten after reboot. Boot time **36.391s**.

## Decision

**Accepted.** Profile: `aggressive` only, and of everything in it this is the
one that most deserves a warning. The image can load no module it was not
built with. A different instance type with a different network or storage
adapter will not boot, and the symptom is a device that silently does not
appear.

## Surprises

**Gate 1 passed all three times.** 013 was caught by gate 1 only because of
the firewall; 015 and 016 passed it and failed on EC2. That is not a defect
in gate 1, it is its boundary: under QEMU the devices are virtio, built into
the kernel, so nothing about a missing ENA driver or an unloadable
`af_packet` is observable. Two of the four modules in that list exist
*because* gate 2 exists.

The `af_packet` failure is the one worth remembering. The symptom was
`A start job is running for DHCP Client (12s / 1min 33s)` repeating until the
timeout, with the link up and no error anywhere. Nothing in that points at a
kernel module. It came from reading `CONFIG_PACKET=m` in the kernel config
and knowing dhcpcd opens a raw socket, not from the logs.

The general lesson, now the third time this lab has hit it: **when removing a
mechanism rather than a package, enumerate what depended on the mechanism
before deploying, not after.** `grep '=m' configfile` against the list of
services that start after switch-root would have produced all four modules in
one pass and saved two EC2 round trips.
