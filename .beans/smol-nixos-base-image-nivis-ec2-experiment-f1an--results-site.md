---
# smol-nixos-base-image-nivis-ec2-experiment-f1an
title: Results site
status: in-progress
type: epic
priority: normal
created_at: 2026-10-13T22:37:58Z
updated_at: 2026-10-13T22:38:01Z
parent: smol-nixos-base-image-nivis-ec2-experiment-zct3
---

One deliverable: `site/`, built by a script in this repo, deployed to GitHub
Pages by an Action, from `ledger.jsonl` and `REPORT.md`.

Scope boundaries, from `results-site-brief.md`:

- The TechNative blog post and the NixOS Discourse post are out of scope.
- No new experiments, and no changes to the findings.
- nivis is named once, as the mechanism the lab used, and is not the point.
- The forward line is ElastiNix as direction, not as a finished claim.

Three inputs are not decided yet and each blocks a different part of the
build. They are written up in the OpenSpec change:

[ ] which boot number the hero states, given that the ledger and `REPORT.md`
    disagree and both sit inside the noise
[ ] the published URL, which today contains `nivis` twice through the repo
    name
[ ] the TechNative palette, logo and type, which a text-mode fetch of
    technative.eu cannot recover
