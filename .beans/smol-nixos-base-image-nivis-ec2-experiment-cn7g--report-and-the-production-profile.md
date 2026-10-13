---
# smol-nixos-base-image-nivis-ec2-experiment-cn7g
title: Report and the production profile
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-13T07:16:57Z
parent: smol-nixos-base-image-nivis-ec2-experiment-ppfg
---

What anyone reading the repo afterwards actually uses. Done: REPORT.md states the floor per track with evidence, and smol.profile safe is a defensible recommendation.

- [ ] `just docs` output committed as docs/options.md
- [ ] size over time table generated from ledger.jsonl
- [ ] REPORT.md: final sizes per track against the frozen baseline
- [ ] the needs-upstream list, with the nixpkgs change each one waits for
- [ ] curate smol.profile safe and aggressive in modules/smol/profiles.nix
- [ ] a short recommendation for our production base image

## Summary of Changes

`REPORT.md` is written: the result, how to read the numbers, where the size went, the floor, what did not work, the four findings that belong upstream, what the method cost, boot time, and what a configurable production image should take from this one. The production profile is left as a recommendation rather than a `smol.profile` value, because the dividing question is who logs into the machine, and that is the next project's to answer.
