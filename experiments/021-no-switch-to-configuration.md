# 021: no-switch-to-configuration

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noSwitchToConfiguration`
- **Source:** siraben, backlog item `s6`

## Hypothesis

`switch-to-configuration` activates a new system generation in place, which
is exactly what the appliance track does not do. Experiments 18 and 20 also
showed it is expensive to keep: it links dbus, and through the systemd it is
built against it reaches `libfido2`, and both of those pull a second systemd
build back into the closure.

## What changed

```nix
system.switch.enable = false;
```

## Numbers

| measure      | before      | after       | delta         |
| ------------ | ----------- | ----------- | ------------- |
| closure      | 732 039 064 | 717 576 320 | 14 462 744    |
| closure, MiB | 698.13      | 684.33      | 13.79, 2.0%   |

Measured, and then not accepted. The number is real but the system cannot be
turned into an image, so it is not a result anyone can use.

## Gate 1, local

**Pass.** Ten checks on first boot, ten after reboot.

## Gate 2, EC2

**Fail**, and not on the instance. The image never got built:

```
chroot: failed to run command
  '/nix/var/nix/profiles/system/bin/switch-to-configuration': No such file or directory
[    1.242519] Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
```

`config.system.build.images.amazon` builds its disk image by booting a
builder VM, chrooting into the new root and running
`switch-to-configuration boot` to install the bootloader and seed
`/nix/var/nix/profiles/system`. Removing the program removes the thing the
image builder calls.

No AWS resources survived: the key pair and security group had been created
before the image build was reached, and both were destroyed.

## Decision

**Rejected, and reclassified as `needs-upstream`.**

This is not a trade-off the lab can make differently. The program is needed
at image-build time and not at run time, and nixpkgs offers no way to say
that. What would unlock it:

> `pkgs/build-support/.../make-disk-image` and the `system.build.images.*`
> builders should install the bootloader without requiring
> `config.system.switch.enable`, or should use a build-time-only
> `switch-to-configuration` that does not enter the runtime closure.

Recorded in `BACKLOG.md` as `needs-upstream` with that text, which satisfies
BRIEFING §9's stop criterion 2 for this item.

## Consequences for other items

`e5`, removing the duplicate systemd, was waiting on this. Experiments 18 and
20 established that `agetty` is only one of three holders of
`systemd-minimal`; the other two are `libfido2` and `dbus-lib`, both reached
through `switch-to-configuration`. With `s6` blocked, `e5` needs a different
route: build systemd itself with `withFido2 = false`, and find out what makes
`dbus` link against `systemd-minimal` rather than the systemd already in the
closure.

## Surprises

**Gate 1 passed and the image build failed.** Every previous gate 2 failure
was on the instance; this one was in the pipeline that produces the AMI, and
it is a failure mode neither gate was designed to catch. Gate 1 boots a
configuration under the test driver, which never makes a disk image. Gate 2
makes one, but only as a step on the way to a running instance.

Nothing needs changing: gate 2 did catch it, before any instance was
launched, and the cost was one image build. But it is worth knowing that
"gate 1 passed" says nothing about whether the thing can be turned into an
AMI at all.
