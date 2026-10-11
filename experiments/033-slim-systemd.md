# 033: slim-systemd

Full account in `experiments/036-slim-systemd.md`; this file exists because
the ledger points at it.

Rejected, build failed: `missing .../lib/sysctl.d/50-coredump.conf`.

Fixed with `systemd.coredump.enable = false`. Turning a feature off in the
package needs the matching NixOS module turned off too.
