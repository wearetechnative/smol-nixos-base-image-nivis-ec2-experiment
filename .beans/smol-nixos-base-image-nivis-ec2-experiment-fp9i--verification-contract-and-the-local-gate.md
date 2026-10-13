---
# smol-nixos-base-image-nivis-ec2-experiment-fp9i
title: Verification contract and the local gate
status: completed
type: epic
priority: high
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-13T07:16:56Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

The contract of BRIEFING section 3, as one script both gates run. Done: `just gate1 accepted` is green and every check that gate 1 cannot cover is listed with a reason.

- [x] `lab/verify.sh`, contract version 1, POSIX sh, TAP output
- [x] `lab/test-local.nix`: target, client and gateway nodes under the NixOS test driver
- [x] gateway node proving DNS, HTTPS against a test CA, and NTP
- [x] reboot and re-verify inside the same test
- [x] `lab/test-support/qemu.nix` listing every forced override as a known hole
- [x] `just gate1 accepted` and `just gate1 candidate` both green
- [x] contract version 1 recorded in docs/TESTING.md and frozen

Gate 1 needed node.pkgsReadOnly = false before any overlay-based strategy could pass it. Found by experiment 008; would have blocked every siraben item.

## Summary of Changes

The contract is `lab/verify.sh`, ten checks, run identically by gate 1 and gate 2 so the two cannot drift. It never changed after phase 0, which is what makes every ledger line comparable.
