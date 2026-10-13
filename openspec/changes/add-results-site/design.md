## Context

See `proposal.md` for motivation. What shapes the approach is the data,
which was explored before this was written.

- `ledger.jsonl` has 75 rows. All 40 baseline-or-accepted rows carry
  closure, image and boot. The other 35 carry no size of their own, and 13
  of them have `closure_after: 0` because the build never produced a
  system.
- `REPORT.md` and `experiments/e15-boot-time.md` contain measurements that
  were deliberately never ledger lines, because nothing was accepted or
  rejected on them.
- `lab/stats.py` already turns the ledger into a two-panel SVG for the
  README. Its palette was chosen to read on GitHub's light and dark
  backgrounds, and its output is a static image.
- The repository has no CI. This change adds the first workflow.

## Goals / Non-Goals

**Goals:**

- One page, built from the repository, where no number is typed by hand.
- The rejections visible in the result rather than filtered out of it.
- A boot section that says what the lab actually established, which is a
  negative result.
- Motion as decoration over a page that is complete without it.

**Non-Goals:**

- A framework, a bundler, or a Node toolchain in a Nix flake that has
  none. The page is small and the data is 75 rows.
- Reuse of `lab/stats.py`'s SVG output. Its data extraction is reused; its
  rendering is not.
- Interactive exploration of the ledger. This is a result, not a tool.
- Changing `docs/`, which holds lab documentation and would be published
  wholesale if Pages served that directory.

## Decisions

### The build has two inputs, and they are not interchangeable

```
ledger.jsonl ──────▶ the series: 75 rows, closure, image, boot
                     everything that was an experiment

REPORT.md     ──┐
experiments/  ──┴──▶ the stated facts and the controls
                     measured, in the repository, never ledger lines
```

The series drives every chart. The controls are quoted with the file they
came from and labelled as controls. Without that rule a later editor
"reconciles" the page to the ledger and silently deletes the e15 result,
which is the most interesting measurement the lab made.

### The descent is a step function over all 75 experiments

Carry the last accepted closure forward through rejections. The flat
stretches are then the rejections, and they have names:

```
 MiB
1516 ┐■
     │ ■■
     │   ■■■■■■
1000 ┤        ■■■▁▁▁▁▁   20-24  systemd-minimal, s6 filed needs-upstream,
     │                          lean-image three times
     │               ■■▁▁▁▁     27-30  minimalSystemPackages, four tries
 500 ┤                    ■■■▁  32-35  slimSystemd, four builds
     │                        ■■▁▁▁ ■■ 69-71  image sizing, three ways
 266 ┤                              ▔▔▔■
     └┬────┬────┬────┬────┬────┬────┬────┬
      1   10   20   30   40   50   60   75
```

The alternative, plotting the 40 accepted rows as a smooth curve, is what
`lab/stats.py` does and it hides the lab. The plateau at 20-24 is where
`switch-to-configuration` was given up on; experiment 45 came back to it
and took 134 MiB. A curve without plateaus cannot tell that.

Rejections also get a rail beneath the line, one tick each, so a flat
stretch has a visible cause rather than looking like an absence of work.

### The pinned counter follows the same step function

Scroll position maps to experiment id, and the counter shows the carried
closure at that id. It therefore stands still during the plateaus, which
is the point: the reader feels the stall as well as the fall.

### Boot time gets a negative result, not a trend line

The last ten accepted experiments boot in 12.8 to 15.9 seconds, mean
14.32, standard deviation 0.91. `REPORT.md` quotes 14.141 and `README.md`
quotes 15.926, and both are inside that spread. The page states the
spread.

The panel's content is the e15 control, which is the clean result:

```
boot
 15s ┤        ●              ●              ●
     │     13.30           13.44          14.17
 10s ┤
     └──────┬───────────────┬──────────────┬────
          398 MB          438 MB        1002 MB
                    image size

     604 MB and some 40000 extra files cost 0.03s
```

Boot time does not track size. The only boot effect the lab isolated is
`smol.xzInitrd`, which costs 2.5 seconds for 4.23 MiB.

### Generated data, static page

```
ledger.jsonl ─┐
REPORT.md ────┼─▶ site/build.py ─▶ site/data.json ─▶ index.html + css + js
experiments/ ─┘        │                                     │
                       │                              inline SVG, drawn
                  reuses the ledger                    from data.json
                  reading in lab/stats.py
```

Charts are inline SVG whose geometry comes from the data, with motion
applied by CSS and a small amount of JavaScript. With scripting off the
SVG is already complete; with `prefers-reduced-motion` the transitions do
not run. That is what makes the legibility requirement cheap to satisfy
rather than a second implementation.

### Published from `site/`, deployed by Actions

Pages serves the workflow's artefact, not a directory in the tree, so
`docs/` keeps holding lab documentation and nothing in it becomes public
by accident. A `just` recipe runs the same build locally, as every other
artefact in this repository can be.

### Provenance is a check, not a convention

The workflow rebuilds and fails if the committed output differs from what
the data produces. That is the closest thing this change has to the lab's
gates, and it is the reason the site can be trusted a year from now when
nobody remembers which numbers were hand-placed.

## Risks / Trade-offs

**The brand is unsourced and the brief forbids guessing.** A text-mode
fetch of technative.eu returns the copy and not the stylesheet, so there
is no palette, no logo file and no type stack. Until one arrives the page
has to be built on a neutral dark palette with the accent as a single
token, so that applying the real one later is one change rather than a
redesign.

**The URL names nivis before the page loads.** Pages would serve
`wearetechnative.github.io/smol-nixos-base-image-nivis-ec2-experiment/`.
The brief asks for nivis once and for a link worth sharing, and the
repository name gives neither. Renaming the repository breaks every
existing link to it, including the ones in the ledger notes; a custom
domain costs DNS; accepting it costs the brief's framing.

**"Bold first" against a page whose subject is restraint.** The lab's own
prose is short and refuses to overstate. A maximal visual treatment can
carry that, but the copy has to stay terse or the page argues with itself.
The resolution is loud geometry and quiet sentences.

**A page that outlives its data.** The research is finished, so the
ledger will not change again. The provenance check therefore protects
against editing rather than against drift, which is a weaker guarantee
than the lab's gates and should not be described as equivalent.
