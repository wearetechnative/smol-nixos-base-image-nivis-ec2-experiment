---
# smol-nixos-base-image-nivis-ec2-experiment-dodr
title: Store, image and filesystem
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-13T07:16:57Z
parent: smol-nixos-base-image-nivis-ec2-experiment-6waj
---

Items e3, e6 and e7 of BACKLOG.md. How the bits are packed, rather than which bits are there.

- [ ] e3 erofs or squashfs compressed store
- [ ] e6 image compression at AMI registration time
- [ ] e7 root filesystem choice
- [ ] record raw and compressed image sizes separately in every ledger line

Experiment 25: the image carried a full nixpkgs source tree as a nix channel, invisible to every closure measurement. copyChannel = false plus diskSize = auto took 544.14 MiB off the raw VHD, 38.9%, with no closure change. Found by reading nixos/lib/make-disk-image.nix.

- [ ] e16 read the rest of make-disk-image.nix for other unoverridden defaults
- [ ] e15 explain the 36.4s to 14.3s boot time drop

## Summary of Changes

Store and image. `leanImage` 544.14 MiB of image at #25, the single largest result in the lab, from one default in `make-disk-image`. Experiments 68 to 71 then established that the image is its contents: the VHD is sparse and CHS-rounded, and the sizing knobs cannot move it. `e3` and `e7`, a compressed store and a non-ext4 root, are blocked by that builder's own assertion.
