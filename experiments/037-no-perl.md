# 037: no-perl

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noPerl`
- **Source:** natkr, backlog item `n8`

## Hypothesis

`perl-5.42.3` at 55.18 MiB was the largest path left. Two activation scripts
are the reason a stock NixOS carries it: `setup-etc.pl` builds `/etc` on
every boot and `update-users-groups.pl` reconciles users and groups.
natkr's `n8` replaces both: `system.etc.overlay` mounts `/etc` as an overlay,
and `services.userborn` does users and groups in a small C program.

## What changed

```nix
system.etc.overlay.enable = true;
services.userborn.enable = true;
```

Plus an assertion on `boot.initrd.systemd.enable`, which
`system.etc.overlay` requires and which this image already has. That is the
briefing's GOTCHAS seed and it held.

## Numbers

| measure      | before      | after       | delta        |
| ------------ | ----------- | ----------- | ------------ |
| closure      | 540 043 920 | 540 300 000 | **-0.05%**   |
| image, MiB   | 630.16      | 628.16      | 2.00, 0.3%   |

**The closure went up.** Perl did not leave.

## Gate 1, local

Pass. The change works; it just does not do what it was for.

## Gate 2, EC2

Not run, deliberately. The measurement already answered the question, and
there is no reason to spend eleven minutes of EC2 to confirm that a
strategy which saves nothing also boots.

## Decision

**Rejected, and reclassified as `needs-upstream`.**

`nix why-depends` on the result:

```
nixos-system
└── bin/switch-to-configuration: INSTALL_BOOTLOADER='.../install-grub.sh'
    └── .../perl-5.42.3-env/bin/perl .../install-grub.pl
        └── perl-5.42.3
```

Perl had two holders and they are different store paths of the same package.
The activation scripts used one `perl-5.42.3-env`; `install-grub.pl` uses
another. `n8` removes the first. The second belongs to
`switch-to-configuration`, which experiment 21 established cannot be removed
because the amazon image builder calls it.

The module is kept and not enabled in any profile, so that the day `s6` is
unblocked this is one toggle rather than a rediscovery.

## What this makes clear

Four separate lines of attack have now ended at the same place. One nixpkgs
change is worth **127.53 MiB**, 24.8% of the current 515.03 MiB closure:

| MiB   | path | item | held through |
| ----- | ---- | ---- | ------------ |
| 55.18 | `perl-5.42.3` | `n8` | `install-grub.pl` |
| 36.30 | `grub-2.14` | `e11` | `grub-config.xml` |
| 22.26 | `systemd-minimal-261.3` | `e5` | `dbus-lib` and `libfido2` |
| 13.79 | `switch-to-configuration` | `s6` | itself |

`btrfs-progs` at 6.62 MiB hangs off `install-grub.pl` too, so the real figure
is higher.

## A route that was checked and rejected without running it

If `install-grub.pl` is the problem, the obvious move is to stop using GRUB:
`ec2.efi = true` with `boot.loader.systemd-boot`, which AWS supports through
the AMI's `boot_mode`.

It would be worse. NixOS installs systemd-boot with
`systemd-boot-builder.py`, so the trade is 55.18 MiB of perl and 36.30 MiB of
GRUB for a 136 MiB CPython that experiments 5 to 9 spent four attempts
removing. One `grep` for `python` in `systemd-boot.nix` settled it, and no
experiment was spent.
