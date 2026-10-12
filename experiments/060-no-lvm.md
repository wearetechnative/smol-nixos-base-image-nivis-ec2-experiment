# 060: no-lvm

- **Track:** appliance
- **Contract:** 7 and 9 (`findmnt`, and `growpart` resizing the root)
- **Module:** `smol.noLvm`
- **Source:** backlog item `e24`

## Hypothesis

`services.lvm.enable` defaults to true in NixOS. It puts
`lvm2-2.03.41-bin` at 2.61 MiB in the closure through `system-units` and a
tmpfiles fragment, along with the device-mapper udev rules.

This image is a plain ext4 partition on a single EBS volume, written by
`make-disk-image` with `partitionTableType = "legacy+gpt"`. There is no
physical volume, no volume group, no logical volume, and `growpart`
resizes the partition directly.

## What changed

[`modules/smol/no-lvm.nix`](../modules/smol/no-lvm.nix): one line,
`services.lvm.enable = false`, guarded with `"-lvm2-"`.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 304.39 | 298.51 | 5.88, 1.9% |
| image, raw | 430.11 | 422.11 | 8.00, 1.9% |

More than the 2.61 MiB `FLOOR.md` predicted: `lvm2-scripts`,
`lvm2-2.03.41` itself and the udev rules went with the bin output.

`util-linux-minimal` did **not** go. `lvm2-scripts` was one of its three
referrers; `etc-systemd-system.conf` and
`systemd-generator-environment.json` are the other two and both remain.
`FLOOR.md` is corrected.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 15.10s. Check 9 is the one that mattered: the root filesystem
still grows to the volume without any device-mapper tooling present.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted.

## Surprises

None in the result. The run itself is the first since experiment 59: build,
both gates and teardown in about twenty-five minutes, where the three
before it spent an hour each rebuilding QEMU before they could measure
anything.
