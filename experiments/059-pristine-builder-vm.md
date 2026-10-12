# 059: pristine-builder-vm

- **Track:** appliance
- **Contract:** the whole contract, on an image built a different way
- **Module:** `smol.leanImage.pristineBuilderVm`
- **Source:** found by lab, exp #59, after #57 could not finish

## Hypothesis

`make-disk-image` builds the image inside a QEMU VM, through
`pkgs.vmTools.runInLinuxVM`. `smol.leanImage` passes it the appliance's
`pkgs`, which carries every smol overlay, so an override of systemd,
util-linux, dbus or curl rebuilds that QEMU, and gtk4, mesa and pipewire
behind it, before the image can be measured. Experiments 48, 55 and 58 each
paid about an hour for it; 57 never finished.

The VM's only job is to hold a loop device and run `mkfs`. Nothing the
appliance overrides is needed for that.

## What changed

[`modules/smol/lean-image.nix`](../modules/smol/lean-image.nix): the
`pkgs` handed to `make-disk-image` is extended with `vmTools` from an
unoverlaid nixpkgs.

```nix
pkgs = pkgs.extend (_: _: {
  inherit (import pkgs.path { inherit (pkgs.stdenv.hostPlatform) system; }) vmTools;
});
```

Everything the image *contains* still comes from the overlaid `pkgs`. Only
the machine that assembles it changes.

`nix build --dry-run` on `image-accepted` afterwards: **two derivations**,
`vm-run` and the image itself.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 304.39 | 304.39 | 0, identical |
| image, raw | 432.11 | 430.11 | 2.00, 0.5% |

The closure cannot move: this touches nothing the image contains. The
image did move, which is why this went through the protocol as an
experiment rather than being committed as a refactor. The two images differ
in 154 million bytes, so the builder VM reaches the ext4 layout; the
smaller one is the pristine build.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.49s. This is the check that mattered: an image assembled by a
different VM still boots on Nitro and passes the whole contract.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. 2.00 MiB of image, and the build-time cost of every future
package strategy drops from an hour to minutes.

## Surprises

I expected the image to be byte-identical and said so in a comment before
measuring it. It is not. The hypothesis was wrong in a way that only
`sha256sum` would catch, and it is the reason this is ledger line 59 rather
than a quiet commit.
