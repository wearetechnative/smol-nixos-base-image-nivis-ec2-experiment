# 007: no-ebsnvme-id

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noEbsNvmeId`, later folded into `smol.noPython`
- **Source:** found by lab, experiment 005

## Hypothesis

Experiment 005 found CPython held by `ebsnvme-id`, a Python script in
`amazon-ec2-utils`, through `70-ec2-nvme-devices.rules`. Strip the script and
the two rules that call it, and the 136.55 MiB interpreter should go with
them.

## What changed

An overlay removing `bin/ebsnvme-id` in `postFixup`.

## Numbers

None. The build failed.

## Gate 1, local

Not reached.

## Gate 2, EC2

Not reached. No AWS resources created.

## Decision

**Rejected: build failed.** An implementation error on my part, not a finding
about the system.

```
patching script interpreter paths in /nix/store/...-amazon-ec2-utils-2.2.0
setup: line 1772: .../bin/ebsnvme-id: No such file or directory
```

`postFixup` was the wrong hook: `patchShebangs` still wanted the file. The
retry moved the removal to `postInstall`, which was also wrong, for a
different and more interesting reason, and then to `preFixup`, which works.
See experiment 008 and `GOTCHAS.md`.

## Surprises

Recorded here because the ledger keeps a line for it either way, and because
the sequence of three wrong hooks is worth knowing before anyone overrides
another package in this repo:

1. `postFixup` fails, because `patchShebangs` has not finished with the file.
2. `postInstall` does nothing at all, because this package has a custom
   `installPhase` that never calls `runHook postInstall`. Silent, which is
   worse than failing.
3. `preFixup` works, and is also the right phase on the merits: it removes
   the file before `patchShebangs` creates the CPython reference, rather than
   deleting the reference afterwards.

`doInstallCheck = false` is needed as well, because `installCheckPhase` runs
`$out/bin/ebsnvme-id --help`.
