## 1. Decisions that block work

Each of these is written up in `proposal.md` under Impact. Every one has a
proposed answer, so the build can proceed on the proposal's default if it
is not overruled, but none of them should be settled silently.

- [x] 1.1 Settle the boot number. Default, if not overruled: the hero
      states 41s to 14.3s with the spread, and the page never presents a
      single run as the result. Verified by the figure on the page
      matching `mean` and `pstdev` over the last ten accepted ledger rows.
- [x] 1.2 Settle the published URL: rename the repository, point a custom
      domain at Pages, or accept
      `wearetechnative.github.io/smol-nixos-base-image-nivis-ec2-experiment/`.
      Default, if not overruled: accept, and name nivis once in the body.
      Verified by the decision being written into `proposal.md` and the
      workflow deploying to that URL.
- [x] 1.3 Obtain the TechNative palette, logo and type from a brand guide
      or an existing front-end repository. Default, if not supplied: a
      neutral dark palette with the accent as a single CSS custom
      property. Verified by `grep` finding exactly one accent token in the
      stylesheet, so that applying the real brand is one edit.

## 2. Data extraction

- [x] 2.1 Factor the ledger reading out of `lab/stats.py` into a module
      both it and the site build import. Verified by `just stats`
      producing a byte-identical `docs/progress.svg` and README block
      before and after.
- [x] 2.2 Build the experiment series: 75 rows carrying id, slug,
      decision, closure, image and boot, with the last accepted closure
      and image carried forward through rejections. Verified by a unit
      check asserting 75 rows out, no null carried value after row 1, and
      the plateaus landing on ids 7-8, 12-13, 15-16, 20-24, 27-30, 32-35,
      37-38 and 69-71.
- [x] 2.3 Derive the stated facts: baseline and final closure, image and
      boot; the tally of 1 baseline, 39 accepted, 33 rejected and 2
      undecided; the top six strategies and their 794 MiB share of 1250.
      Verified by each figure matching a recomputation straight from
      `ledger.jsonl` in the same check.
- [x] 2.4 Read the controls that were never experiments, starting with the
      three e15 boot measurements in `experiments/e15-boot-time.md`, and
      tag them as controls with the file they came from. Verified by
      `data.json` carrying `source: "experiments/e15-boot-time.md"` and no
      ledger id on those points.
- [x] 2.5 Emit `site/data.json` and fail the build on any derived value
      that is null, zero where a size is expected, or absent. Verified by
      running the build against a ledger row with a blanked field and
      seeing it fail with the field named.

## 3. The page

- [x] 3.1 Write the document structure: hero, the question, how we ran it,
      the descent, the one insight, boot, the floor, the tally, what is
      next. Verified by the section order matching
      `results-site-brief.md` section 3.
- [x] 3.2 Write the copy, in the register `REPORT.md` uses: conclusion
      first, short sentences, no em dashes, no curly quotes. Verified by
      the repository's prose gate passing on the page source.
- [x] 3.3 Place every number through a template substitution from
      `data.json`, with no literal quantity in the page source. Verified
      by a check that greps the source for digit-plus-unit patterns and
      fails on any that the data does not produce.
- [x] 3.4 Name nivis exactly once in the body, and ElastiNix as direction.
      Verified by a case-insensitive count of one in the rendered page.
- [x] 3.5 Frame the strategies as the reusable result rather than the
      image, per `proposal.md`'s Risk. Verified by review against
      `REPORT.md` section 8.

## 4. Charts

- [x] 4.1 Draw the descent as a step function over all 75 experiments,
      with a rejection rail beneath it. Verified by the flat stretches
      aligning with the plateau ids from 2.2.
- [x] 4.2 Annotate the eight named wins: no-flake-registry 200,
      no-kernel-modules 153, no-python 137, no-ssm-agent 110,
      no-amazon-init 101, no-documentation 94, no-nix 88, no-perl 59.
      Verified by each label's value coming from `data.json` and matching
      the ledger delta for that id.
- [x] 4.3 Draw "where it went" as bars, longest first. Verified by the bar
      order matching the sorted closure deltas and the total matching the
      1250 MiB sum.
- [x] 4.4 Draw the boot panel as the e15 control scatter, three points at
      398, 438 and 1002 MB against 13.30, 13.44 and 14.17 seconds, with
      the 22 second drop at experiment 25 flagged as unexplained and not
      reproducible. Verified against `experiments/e15-boot-time.md`.
- [x] 4.5 Draw the floor from `REPORT.md` section 3. Verified by every row
      and figure matching that table.
- [x] 4.6 Render all charts as inline SVG whose geometry comes from
      `data.json`. Verified by the charts being complete and readable with
      scripting disabled.

## 5. Motion

- [x] 5.1 Animate the hero number shrinking as it lands. Verified by the
      final value being correct when the animation is skipped.
- [x] 5.2 Draw the descent curve on scroll, with annotations appearing at
      their milestones. Verified by the full curve and all annotations
      being present at any scroll position when motion is off.
- [x] 5.3 Animate the bars out from zero, longest first. Verified as 5.1.
- [x] 5.4 Pin the running closure counter and tick it down against scroll
      position, standing still through the plateaus. Verified by the
      counter reading 1516 at the top, 266 at the bottom, and holding
      across ids 20 to 24.
- [x] 5.5 Honour `prefers-reduced-motion: reduce` throughout. Verified by
      loading the page with the preference set and reading it end to end
      with nothing animating and nothing missing.

## 6. Build, publish, verify

- [x] 6.1 Add a `just site` recipe that regenerates `data.json` and the
      page. Verified by a clean checkout producing the same output twice.
- [x] 6.2 Add the GitHub Actions workflow: build, verify, deploy to Pages
      from `main`. Verified by a run on `main` publishing the page and the
      URL returning it.
- [x] 6.3 Add the provenance check to the workflow: rebuild and fail if
      the committed output differs from what the data produces. Verified
      by a deliberately edited figure failing the job, and by that commit
      being reverted afterwards.
- [x] 6.4 Check the page with scripting disabled and with reduced motion,
      and at a narrow viewport. Verified by the content being complete in
      all three.
- [x] 6.5 Reconcile the boot figure in `README.md` with whatever 1.1
      settled, so the repository does not state two different numbers.
      Verified by `grep` finding one boot figure across `README.md`,
      `REPORT.md` and the site.

## 7. Close out

- [x] 7.1 Update `STATE.md` and `README.md`: research closed, repository
      open for publishing, with the site's URL. Verified by both files
      naming the URL.
- [x] 7.2 Check the epic's items off in beans and close it with a
      `## Summary of Changes`. Verified by `beans list` showing milestone
      05 complete.
- [x] 7.3 Archive this change with `openspec archive` and commit. Verified
      by `openspec list` showing no active changes.
