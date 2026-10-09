---
# smol-nixos-base-image-nivis-ec2-experiment-x5uw
title: Service stack slimming
status: todo
type: epic
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-09T11:51:38Z
parent: smol-nixos-base-image-nivis-ec2-experiment-6waj
---

Items e2, e4 and e5 of BACKLOG.md. Replacing or deduplicating what runs on the image.

- [ ] e2 networkd instead of dhcpcd
- [ ] e4 dropbear instead of openssh, if the contract still passes
- [ ] e5 remove the remaining duplicate util-linux and systemd builds
- [ ] new hypotheses from nix why-depends on whatever is left, written to BACKLOG.md first
