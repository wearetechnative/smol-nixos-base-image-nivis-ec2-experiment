# 024: lean-image

Rejected. See `experiments/025-lean-image.md` for the full account; this
line exists because the ledger points at it.

Rejected before any AWS resource was created, on a Nix evaluation error:

```
error: attribute 'rootVolumeGb' missing
```

My own mistake. The search-and-replace that added the variable's declaration
had no assertion and matched nothing, because the file had been reformatted
since; the replace that added its *use* did match. Declaration missing, use
present.

Every edit to a Nix file in this repo since asserts that its pattern matched.
