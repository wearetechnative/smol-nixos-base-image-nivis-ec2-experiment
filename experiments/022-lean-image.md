# 022: lean-image

Rejected. See `experiments/025-lean-image.md` for the full account; this
line exists because the ledger points at it.

Rejected by the protocol, not by a gate: `lab/experiment.sh` compared only
closures, and this strategy changes the image. The closure delta was exactly
zero while the image fell by 544 MiB.

`lab/experiment.sh` now measures the accepted image too and accepts a
candidate if either measure went down.
