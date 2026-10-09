---
# smol-nixos-base-image-nivis-ec2-experiment-jhwk
title: Measurement harness and the ledger
status: in-progress
type: epic
priority: normal
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T12:01:07Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

Done: `just measure <variant>` emits the JSON of BRIEFING section 8.2 and one append-only ledger line exists per experiment, also for failures.

- [x] `lab/measure.sh`: closure size, image size, compressed size, top 20 paths
- [ ] `lab/experiment.sh`: the full pipeline of BRIEFING section 8, appending a ledger line on every path including failure
- [ ] ledger line schema validated before append
- [ ] `experiments/NNN-<slug>.md` template
- [ ] size-over-time table generated from ledger.jsonl
