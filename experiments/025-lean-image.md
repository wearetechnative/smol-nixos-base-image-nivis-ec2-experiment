# 022 to 025: lean-image

Four ledger lines, one result. Accepted at #25.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.leanImage`
- **Source:** found by lab, by reading `nixos/lib/make-disk-image.nix`
  instead of the closure

## Hypothesis

Every experiment in this lab had measured `system.build.toplevel`. The raw
VHD stayed about 900 MiB larger than that number could explain, and nobody
had asked why.

Reading the builder answers it. `maintainers/scripts/ec2/amazon-image.nix`
calls `nixos/lib/make-disk-image.nix`, which has two defaults nothing in the
EC2 path overrides:

```nix
diskSize ? "auto",          # amazon-image.nix forces this to 4096 MiB
copyChannel ? true,         # nothing overrides this
```

`copyChannel` is the big one. It puts a complete copy of the nixpkgs source
tree into the image as a nix channel, through `basePaths`:

```nix
basePaths = [ config.system.build.toplevel ] ++ lib.optional copyChannel channelSources;
```

It is added to the **image's own store**, not to the system closure, which is
why no measurement in this lab could see it. An appliance with no Nix has no
use for a channel.

## What changed

`image.modules.amazon` is an `attrsOf deferredModule`, so a definition there
merges with nixpkgs' own and applies only inside the image evaluation. The
system configuration is untouched:

```nix
image.modules.amazon = { config, lib, pkgs, ... }: {
  system.build.amazonImage = lib.mkForce (
    import (pkgs.path + "/nixos/lib/make-disk-image.nix") {
      inherit lib config pkgs;
      copyChannel = false;
      diskSize = "auto";
      additionalSpace = "128M";
      configFile = null;
      ...
    });
};
```

And in `lab/nivis-plan.nix`, a `root_block_device` sizing the volume at
launch:

```nix
root_block_device = [{ volume_size = vars.rootVolumeGb; volume_type = "gp3"; }];
```

## Numbers

| measure           | before        | after       | delta          |
| ----------------- | ------------- | ----------- | -------------- |
| closure           | 732 039 064   | 732 039 064 | **0**          |
| image, raw VHD    | 1 468 375 552 | 897 804 800 | 570 570 752    |
| image, MiB        | 1400.35       | 856.21      | 544.14, 38.9%  |
| boot time         | 36.4s         | **14.3s**   | 22.1s, 61%     |

**544 MiB off the artefact that is uploaded, imported as a snapshot and
stored as an AMI, with the closure unchanged by a single byte.**

The boot time was not predicted and is not yet explained. 36.4s to 14.3s is
far outside the 34 to 42s band every previous experiment sat in. The
plausible cause is that the old image's root filesystem was 4 GiB containing
a nixpkgs channel of many small files, and something in early boot walks it.
That is a guess; it deserves its own measurement rather than a claim.

## Gate 1, local

Pass throughout. Gate 1 does not build a disk image, so it has nothing to say
about this strategy either way.

## Gate 2, EC2

Pass at #25. Boot time **14.338s**, root filesystem 7 GiB on an 8 GiB
volume, ten checks on first boot and ten after reboot.

## The three rejections before it

| # | reason | what it taught |
| - | ------ | -------------- |
| 22 | "not smaller than accepted" | the protocol only compared closures, so an image-only strategy could not be accepted at all |
| 23 | gate 2, check 9 | with `diskSize = "auto"` the EBS volume inherits the snapshot's size, so `growpart` has nothing to grow into |
| 24 | nix eval, `attribute 'rootVolumeGb' missing` | my own error: an unasserted search-and-replace matched nothing after the file had been reformatted, so the variable's use landed and its declaration did not |

## Changes to the harness

`lab/experiment.sh` now measures the accepted **image** as well as the
accepted closure, and accepts a candidate if either went down. The old rule
would have rejected this strategy forever.

That is worth stating plainly: **the protocol had a blind spot that matched
the lab's blind spot.** Both measured the closure, so for twenty-one
experiments neither could see 900 MiB sitting in the artefact.

## Decision

**Accepted.** Profile: `safe` and `aggressive`. A nix channel in the image is
of no use to any machine that is not rebuilt in place, and sizing the
filesystem to its contents is strictly better once the volume is sized at
launch, which is how a production AMI is built anyway.

## Surprises

The question that started this was "can the image build process be reverse
engineered to fix its own blockers". It did not fix the blocker it was aimed
at, `switch-to-configuration`, which is still `needs-upstream`. It found
something larger that nobody was looking for.

Worth generalising: **this lab had been measuring the thing it could measure
rather than the thing that costs money.** The closure is what `nix path-info`
reports; the image is what gets uploaded, snapshotted, stored and booted. For
twenty-one experiments they were assumed to track each other, and the single
largest saving in the lab came from the gap between them.
