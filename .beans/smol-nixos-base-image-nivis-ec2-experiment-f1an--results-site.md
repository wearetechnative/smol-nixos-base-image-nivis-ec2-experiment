---
# smol-nixos-base-image-nivis-ec2-experiment-f1an
title: Results site
status: completed
type: epic
priority: normal
created_at: 2026-10-13T22:37:58Z
updated_at: 2026-10-13T23:08:21Z
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

[x] which boot number the hero states, given that the ledger and `REPORT.md`
    disagree and both sit inside the noise
[x] the published URL, which today contains `nivis` twice through the repo
    name
[x] the TechNative palette, logo and type, which a text-mode fetch of
    technative.eu cannot recover
## Summary of Changes

`site/` is built from `ledger.jsonl`, `REPORT.md` and the experiment notes
by `just site`, verified by `just site-check` and `site/verify.py`, and
published to GitHub Pages by `.github/workflows/site.yml`, the first CI
this repository has had.

What the page does that a hand-written one would not: the descent is drawn
across all 75 experiments with the size carried forward, so the flat
stretches are the 33 rejections and the plateau at 20 to 24 is visible as
the place the lab was stuck. The boot section is the e15 control, three
images from 398 to 1002 MB against a flat line, because boot time does not
track size. Every quantity is a slot filled from the data, and the build
refuses to publish a literal it cannot derive.

Three decisions were taken on their defaults, as the OpenSpec change
allowed:

- Boot is stated as a spread, 14.3s with a deviation of 0.9. `README.md`,
  `REPORT.md` and the site previously disagreed; they now derive one
  figure and `site/verify.py` fails if they drift apart.
- The Pages URL is accepted as it stands, and nivis is named once in the
  body.
- The TechNative palette was not available, so the page uses one
  `--accent` token and nothing else carries identity. Applying the real
  brand is one edit.

Running `nix flake check` for the first time since ledger #51 found that
`smol.noUserDataDecompression` could not evaluate on aarch64: it patched
a shell script with `pkgs.runCommand`, and a derivation has a system. It
is pure string work now, with an assertion replacing what
`--replace-fail` used to guarantee, and the built system is byte-identical.
