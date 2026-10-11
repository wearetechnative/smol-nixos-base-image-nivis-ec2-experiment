# 023: lean-image

Rejected. See `experiments/025-lean-image.md` for the full account; this
line exists because the ledger points at it.

Rejected, gate 2 failed on contract check 9:

```
not ok 9 - root filesystem is at least 2 GiB
```

With `diskSize = "auto"` the image is only as large as its contents, the EBS
volume created from its snapshot inherits that size, and `growpart` has
nothing to grow into. Fixed by sizing the root volume at launch in
`lab/nivis-plan.nix` rather than by padding the image.
