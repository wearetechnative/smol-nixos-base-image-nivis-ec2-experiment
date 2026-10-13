---
# smol-nixos-base-image-nivis-ec2-experiment-x5uw
title: Service stack slimming
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-13T07:16:57Z
parent: smol-nixos-base-image-nivis-ec2-experiment-6waj
---

Items e2, e4 and e5 of BACKLOG.md. Replacing or deduplicating what runs on the image.

- [ ] e2 networkd instead of dhcpcd
- [ ] e4 dropbear instead of openssh, if the contract still passes
- [ ] e5 blocked behind s6, which is needs-upstream; a different route is in experiments/018
- [ ] new hypotheses from nix why-depends on whatever is left, written to BACKLOG.md first

## Summary of Changes

Service stack. `noAmazonInit`, `noSsmAgent`, `noSwitchToConfiguration`, `noPerl`, `noSudo`, `noFirewall`, `noLvm`, `noNscd`, `noX11`, `slimOpenssh`, `slimCurl`, `slimIproute2`, `noUserDataDecompression`, `noEditor`, `noBashCompletion`. The two largest came last and came from strings in `/etc`, not from code.
