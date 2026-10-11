# 044: no-switch-to-configuration, second attempt

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noSwitchToConfiguration`, with a patched image builder
- **Source:** siraben `s6`, previously `needs-upstream` after experiment 21

## What changed

Experiment 21 classified `s6` as `needs-upstream`: nixpkgs'
`make-disk-image` installs the bootloader by chrooting into the new root and
running `/nix/var/nix/profiles/system/bin/switch-to-configuration`, so an
image can only be built from a system that carries that program.

`smol.leanImage` already owns the `make-disk-image` call, so the fix is
ours to make. The builder VM has the full build closure at `/nix/store`,
which is a superset of what the image contains. Bind-mounting it over the
image's store for the duration of the bootloader step makes the installer
reachable inside the chroot without copying anything into the image:

```sh
mkdir -p $mountPoint/nix/store
mount --bind /nix/store $mountPoint/nix/store
NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root $mountPoint -- \
  ${config.system.build.installBootLoader} ${config.system.build.toplevel}
umount $mountPoint/nix/store
```

Applied as a `substitute --replace-fail` on the nixpkgs file rather than
vendoring 800 lines. The substitution is the whole diff, and `--replace-fail`
means a nixpkgs change breaks the build loudly instead of silently reverting
to the old behaviour.

## Numbers

| measure      | before      | after       | delta         |
| ------------ | ----------- | ----------- | ------------- |
| closure      | 506 731 704 | 449 421 776 | 57 309 928    |
| closure, MiB | 483.26      | 428.60      | 54.65, 11.3%  |

**The approach works.** 54.65 MiB on the first swing, which is GRUB,
`systemd-minimal` and `btrfs-progs` leaving together. Perl stays until
`smol.noPerl` is enabled alongside, which is experiment 45 and should take
most of the remaining 70 MiB.

## Gate 1, local

**Pass.**

## Gate 2, EC2

**Fail, and not for a reason about the candidate.** The machine ran out of
disk during the image build: 216 GB full, 84 MB free. 88 image derivations
from this lab were occupying 33 GB of the store.

The image build therefore produced nothing, both image measurements read 0,
and `lab/experiment.sh` recorded a gate 2 failure. The ledger line is
honest about the outcome and misleading about the cause, which is the
limitation of recording a verdict rather than a diagnosis.

No AWS resources were created or left behind: verified directly with
`describe-instances`, `describe-images`, `describe-snapshots` and a bucket
listing, all empty.

## Decision

**Rejected on the ledger, unresolved in fact.** The closure result is real
and gate 1 passed; gate 2 has not had a chance to judge it. It needs a rerun
once there is disk, and nothing about the candidate has to change for that.

## What this means for the blocker

`s6` should no longer be read as `needs-upstream`. It is an upstream
*improvement* worth proposing, because every NixOS EC2 image carries this
cost, but it is not a blocker for this lab any more. `BACKLOG.md` and
`FLOOR.md` both need rewriting once experiment 45 confirms the full figure.
