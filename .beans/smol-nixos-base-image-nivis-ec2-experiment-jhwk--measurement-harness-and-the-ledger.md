---
# smol-nixos-base-image-nivis-ec2-experiment-jhwk
title: Measurement harness and the ledger
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-10T10:17:03Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

Done: `just measure <variant>` emits the JSON of BRIEFING section 8.2 and one append-only ledger line exists per experiment, also for failures.

- [x] `lab/measure.sh`: closure size, image size, compressed size, top 20 paths
- [x] `lab/experiment.sh`: the full pipeline of BRIEFING section 8, appending a ledger line on every path including failure
- [x] ledger line built with jq, so a malformed line cannot be appended
- [x] `experiments/NNN-<slug>.md` template, instantiated automatically on every run
- [ ] size-over-time table generated from ledger.jsonl, for REPORT.md in milestone 04

## Summary of Changes

`just experiment <slug>` runs build, measure, gate 1, gate 2, decide and log
as one command, and appends a ledger line on every exit path including a
failed build. Proven over six experiments, one of which it correctly recorded
as rejected.

The size-over-time table is deferred to milestone 04, where REPORT.md needs
it.
