---
# smol-nixos-base-image-nivis-ec2-experiment-onxl
title: Baseline numbers through both gates
status: completed
type: epic
priority: normal
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-09T14:42:54Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
blocked_by:
    - smol-nixos-base-image-nivis-ec2-experiment-jd12
    - smol-nixos-base-image-nivis-ec2-experiment-fp9i
    - smol-nixos-base-image-nivis-ec2-experiment-jhwk
---

The frozen reference every later measurement is relative to. Done: systems/baseline has closure, image and compressed image numbers from both gates, and ledger.jsonl has its first line.

- [x] gate 1 green on systems/baseline
- [x] gate 2 green on systems/baseline
- [x] `just measure baseline` numbers recorded
- [x] ledger line id 1 appended
- [x] boot time recorded: 40.753s
- [x] systems/baseline declared frozen in STATE.md

## Summary of Changes

1516.25 MiB closure, 2598.64 MiB raw VHD, 40.753s boot. Both gates pass 10
of 10 twice. Ledger line 1, note in experiments/001-baseline.md.
