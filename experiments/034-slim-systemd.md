# 034: slim-systemd

Full account in `experiments/036-slim-systemd.md`; this file exists because
the ledger points at it.

Rejected, build failed: `missing .../example/systemd/system/systemd-oomd.service`.

Fixed with `systemd.oomd.enable = false`, and `systemd-importd` and
`systemd-portabled` pre-emptively added to `systemd.suppressedSystemUnits`,
since those are in `upstreamSystemUnits` and have no NixOS option.
