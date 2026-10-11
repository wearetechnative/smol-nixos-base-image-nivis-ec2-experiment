# 027: minimal-system-packages

Rejected. Full account in
`experiments/031-minimal-system-packages.md`; this file exists because the
ledger points at it.

Gate 1 failed with `nc: command not found`, repeating until the driver timed
out after 900 seconds. The NixOS test driver's `wait_for_open_port` runs `nc`
on the target, and the trimmed package list removed it.

A gate 1 environment problem rather than a property of the candidate, like
experiment 8 before it. `smol.minimalSystemPackages.extra` now exists for
exactly this, and `lab/test-support/qemu.nix` uses it to put netcat back.
