# 032 to 036: slim-systemd

Five ledger lines, one result. Accepted at #36.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.slimSystemd`
- **Source:** siraben, backlog item `s1`

## Hypothesis

`systemd` at 63.02 MiB was the largest path left. A stock build carries
homed, portabled, importd, repart, sysupdate, vmspawn, oomd, coredump,
cryptsetup, TPM2, FIDO2 and the remote journal tooling. None has a caller on
this image.

## What changed

A `nixpkgs.overlays` entry, not an override on `systemd.package`. That is
siraben's whole point: an override leaves every consumer linking the stock
build and the image carries two systemds instead of one. It is also why the
flake never hands a prebuilt `pkgs` to `nixosSystem`, and why gate 1 needed
`node.pkgsReadOnly = false` back in experiment 8.

Twenty features off. What stays, and why:

| kept | because |
| ---- | ------- |
| `withAnalyze` | `lab/deploy-ec2.sh` measures boot time with `systemd-analyze` |
| `withTimedated` | contract check 6 calls `timedatectl` |
| `withTimesyncd` | check 6 is about the clock being synchronised |
| `withLogind` | SSH sessions are logind sessions |
| `withMachined` | `/etc/nsswitch.conf` lists `mymachines`; losing it breaks `getent`, which is check 4 |
| `withQrencode` | see below |

## Numbers

| measure           | before      | after       | delta         |
| ----------------- | ----------- | ----------- | ------------- |
| closure           | 579 854 408 | 540 043 920 | 39 810 488    |
| closure, MiB      | 553.27      | 515.03      | 38.24, 6.9%   |
| image, raw VHD    | 709 014 528 | 660 768 256 | 48 246 272    |
| image, MiB        | 676.16      | 630.16      | 46.00, 6.8%   |

`systemd` itself went from 63.02 to 52.04 MiB. The rest of the saving is what
the disabled features dragged behind them.

## The four rejections before it

All four were the same failure in different clothes: **turning a feature off
in the package is only half the job, because NixOS still references what the
feature would have installed.** Each build error named a missing file under
`${systemd}` and nothing else.

| # | missing | fix |
| - | ------- | --- |
| 32 | `example/systemd/system/systemd-bsod.service` | keep `withQrencode` |
| 33 | `lib/sysctl.d/50-coredump.conf` | `systemd.coredump.enable = false` |
| 34 | `example/systemd/system/systemd-oomd.service` | `systemd.oomd.enable = false` |
| 35 | gate 2 not yet run | built and passed gate 1 |

`systemd-bsod.service` is the one worth remembering. Disabling `withQrencode`
on a headless server looks like the most obviously correct removal in the
whole list, and it is not optional: the feature gates that unit, and NixOS
puts it in the initrd's unit list unconditionally. libqrencode is small;
fighting the unit list is not.

The other two have NixOS options. `systemd-importd` and `systemd-portabled`
do not, and are in `upstreamSystemUnits`, which NixOS copies without
checking. `systemd.suppressedSystemUnits` is filtered out of that list before
the copy, so it is the right lever rather than keeping a feature to satisfy
a unit nothing will ever start.

Experiment 35 ran gate 1 only, deliberately. Four failed builds in a row is
the point at which to stop paying 11 minutes per EC2 round trip to learn
something a local build already knows.

## Gate 1, local

Pass at #35 and #36.

## Gate 2, EC2

Pass at #36. Boot time **13.506s**. Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only.

## What it did not do

`systemd-minimal` is still 22.26 MiB. The overlay replaces `systemd`;
`systemdMinimal` is a separate nixpkgs attribute and is untouched, so the
duplicate survives. Backlog `e5` is still open and still blocked behind
`s6`, for the reasons in `experiments/018-no-duplicate-systemd.md`.

Listing the closure afterwards also showed `grub-2.14` still present at 36.30
MiB, which contradicted what experiment 31's note claimed. That note now
carries a correction: GRUB had two holders, experiment 31 removed one, and
the other is `switch-to-configuration`.
