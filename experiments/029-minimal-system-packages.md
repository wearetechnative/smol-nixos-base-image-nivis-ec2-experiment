# 029: minimal-system-packages

Rejected. Full account in
`experiments/031-minimal-system-packages.md`; this file exists because the
ledger points at it.

Same failure as 28 after adding `openresolv`, which was a wrong diagnosis on
my part. `/etc/resolv.conf` was never the problem.

The actual cause was found by comparing `config.system.path` between the
accepted and the candidate system: `bin/getent` was missing. `getent` is a
separate wrapper derivation in nixpkgs rather than an output of glibc, so
`pkgs.glibc` does not provide it.
