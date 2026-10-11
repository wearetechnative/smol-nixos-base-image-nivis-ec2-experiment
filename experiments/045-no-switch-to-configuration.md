# 044 and 045: no-switch-to-configuration, the blocker removed

Accepted at #45. The `needs-upstream` classification from experiment 21 was
wrong, or rather it was right about nixpkgs and wrong about what this lab
could do.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noSwitchToConfiguration`, plus a patched image builder
  in `smol.leanImage`
- **Source:** siraben `s6`

## The blocker

`config.system.build.images.amazon` installs the bootloader by chrooting
into the new root and running `switch-to-configuration boot`, so an image
could only be built from a system that carried that program. Experiment 21
recorded it as `needs-upstream`.

Four experiments then ended at the same place. `e5` (the duplicate systemd),
`e11` (GRUB), `n8` (perl) and `s6` itself. 127.53 MiB, a quarter of the
closure, behind one line of someone else's build script.

## What changed

`smol.leanImage` has owned the `make-disk-image` call since experiment 25.
The fix was always ours to make.

The builder VM has the full build closure at `/nix/store`, which is a
superset of what the image contains. Bind-mounting it over the image's store
for the duration of the bootloader step makes the installer reachable inside
the chroot without copying anything into the image:

```sh
mkdir -p $mountPoint/nix/store
mount --bind /nix/store $mountPoint/nix/store
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root $mountPoint -- \
  ${config.system.build.installBootLoader} ${config.system.build.toplevel}
umount $mountPoint/nix/store
```

Applied as `substitute --replace-fail` on the nixpkgs file rather than
vendoring 800 lines. The substitution is the entire diff, and `--replace-fail`
means a nixpkgs change breaks the build loudly instead of silently reverting
to the old behaviour.

## Numbers

| measure      | before      | after       | delta         |
| ------------ | ----------- | ----------- | ------------- |
| closure, MiB | 483.26      | 428.60      | 54.65, 11.3%  |
| image, MiB   | 592.16      | 574.16      | 18.00, 3.0%   |

GRUB, `systemd-minimal`'s `switch-to-configuration` holders and
`btrfs-progs` leave together.

## What it unlocked, immediately

| # | strategy | closure saving | note |
| - | -------- | -------------- | ---- |
| 46 | `noPerl` | 58.00 MiB | the identical module saved nothing in #37 |
| 48 | `noDuplicateSystemd` | 22.11 MiB | after two more holders turned up |

**134.76 MiB across the three**, against the 127.53 MiB predicted.

## Experiment 44: rejected, and not the candidate's fault

The first run passed gate 1 with the same 54.65 MiB and failed gate 2
because the machine ran out of disk, 216 GB full with 84 MB free. 88 image
derivations from this lab were holding 33 GB of the store. The ledger
recorded a gate 2 failure whose cause was the machine.

## Gate 1, local

Pass at #44 and #45.

## Gate 2, EC2

Pass at #45. Boot time 14.043s. Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only.

## Still worth proposing upstream

Every NixOS EC2 image pays this: `make-disk-image` should install the
bootloader without requiring `config.system.switch.enable` in the runtime
closure. It is no longer a blocker here, so it belongs in `REPORT.md`'s
recommendations rather than in `BACKLOG.md`.

## Surprises

The lesson is about the classification, not the patch. `needs-upstream` was
recorded honestly and it closed the question too early: the right reading was
"nixpkgs does this, and we already control the call site". Four experiments
and two sessions passed between filing it and noticing.

What made the difference was Pim asking whether the image build could be
reverse engineered. That question had already produced 544 MiB in experiment
25, and I stopped at the two easy defaults in the same file instead of going
back for the hard one.
