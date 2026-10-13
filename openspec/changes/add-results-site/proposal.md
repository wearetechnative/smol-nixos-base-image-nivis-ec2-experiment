## Why

The lab is closed and `REPORT.md` is written, but the result is only
readable by someone willing to open a repository and a JSON ledger. The
findings are worth more than that: 1516.25 MiB of closure down to 266.39,
2598.64 MiB of upload down to 380.10, and four results that belong
upstream in nixpkgs. A single shareable page is what turns a closed lab
into something a blog post and a Discourse thread can point at.

Milestone: `05 Publish the results` (beans
`smol-nixos-base-image-nivis-ec2-experiment-zct3`), epic `Results site`
(`...-f1an`). This is the first change that sits outside `BRIEFING.md`'s
phases. The briefing governs what the lab measured and still does;
`results-site-brief.md` governs this change, and where the two disagree
about what this work is, the site brief wins.

## What Changes

- A new `site/` directory holding the page source, its styles and its
  client-side behaviour. `docs/` is left alone: it already serves
  `TESTING.md`, `SETUP-AWS.md`, `options.md` and `progress.svg`, and
  publishing that directory would publish those too.
- A build script that reads `ledger.jsonl`, `REPORT.md` and the experiment
  notes and emits the site's data as JSON, so no number on the page is
  typed by hand. It reuses the data extraction in `lab/stats.py` and not
  its SVG output, which was shaped for a README on GitHub rather than for
  a page with scroll-driven motion.
- The repository's **first GitHub Actions workflow**: regenerate, verify,
  and deploy to GitHub Pages from `main`. There is no CI here today.
- A `just` recipe for the same build, so the site can be checked locally
  the way every other artefact in this repo can.
- `STATE.md` and `README.md` gain a line saying the research is closed and
  the repository is open for publishing. Neither claim changes.

Not in scope, from the brief: the TechNative blog post, the NixOS
Discourse post, any new experiment, and any change to a finding.

## Capabilities

### New Capabilities

- `publishing/results-site`: what the published site must contain, which
  source each number comes from, and what has to stay true when the data
  changes. The requirements are about provenance and legibility, not about
  layout.

### Modified Capabilities

None. `lab/aws-access` and `lab/ec2-gate` are untouched.

## Impact

**Affected systems.**

| what | change |
| ---- | ------ |
| `site/` | new. Page source, styles, client behaviour, build script, generated `data.json` |
| `.github/workflows/` | new, and the first CI this repository has ever had. Build, verify provenance, deploy to Pages |
| GitHub Pages | new. Serves the workflow artefact, not a directory in the tree |
| `justfile` | one recipe, so the site builds locally like everything else here |
| `lab/stats.py` | its ledger reading is factored out and reused. Its SVG output and the README block it writes are untouched |
| `README.md`, `STATE.md` | one line each: research closed, repository open for publishing |
| `docs/` | untouched, and deliberately not the Pages root |
| `ledger.jsonl`, `modules/`, `systems/`, `lab/verify.sh` | untouched. No finding changes |

**Dependencies.** Python 3 and the existing dev shell. No Node, no
bundler, no framework: the page is one document and the data is 75 rows.
No third-party runtime service, so the page renders with no host reachable
other than the one serving it.

**Three inputs are undecided and each blocks a different part of the
build.** They are findings from exploring the data, not open questions
about taste.

1. **Which boot number the hero states.** `REPORT.md` says 14.141s, from
   an e15 control run. `README.md` says 15.926s, from ledger #75. Both are
   real measurements and both sit inside the noise: the last ten accepted
   experiments boot in 12.8 to 15.9 seconds, mean 14.32, standard
   deviation 0.91. Stating either as the final boot time is a claim the
   lab cannot support. The proposed answer is to state the spread.

2. **The published URL.** The repository is
   `wearetechnative/smol-nixos-base-image-nivis-ec2-experiment`, so Pages
   serves
   `wearetechnative.github.io/smol-nixos-base-image-nivis-ec2-experiment/`.
   The brief asks that nivis be named exactly once; the link names it
   before the page loads. Rename, custom domain, or accept.

3. **The TechNative palette, logo and type.** `technative.nl` redirects to
   `technative.eu`, and a text-mode fetch returns the copy but not the
   stylesheet, so there are no hex values and no logo file to work from.
   The brief forbids guessing a brand colour. This needs a brand guide, an
   existing TechNative front-end repository, or the palette by hand.

**Gate evidence.** This change cannot use the lab's two gates, which boot
machines. Three checks replace them, and all three run in the workflow:

- **Provenance.** The build regenerates every published number from the
  repository and fails if any of them differs from the committed output.
  A number that is not in `ledger.jsonl`, `REPORT.md` or an experiment
  note cannot appear on the page.
- **Legibility without motion.** The page renders completely and reads top
  to bottom with `prefers-reduced-motion: reduce`, and with JavaScript
  disabled the content is still there.
- **Deploy.** The workflow publishes from `main` and the resulting URL
  returns the page.

**Risk worth naming.** The brief asks to frame the result as a generic,
reusable NixOS EC2 base image. `REPORT.md` §8 says the opposite about the
artefact: the `safe` profile holds three strategies against thirty in
`aggressive`, four options need a second look before production, and the
configurable image is the next project. The site should therefore present
the **measurements** as the reusable thing, 36 options each with its
trade-off and its ledger line, and leave the image itself to ElastiNix.
That keeps the forward line honest, which the brief also asks for.
