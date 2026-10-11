# 028: minimal-system-packages

Rejected. Full account in
`experiments/031-minimal-system-packages.md`; this file exists because the
ledger points at it.

Gate 1 failed on contract check 4, `getent hosts returned nothing`, while
check 5 fetched a URL from the same host successfully.

The explanation is that the harness pushes a statically linked musl curl,
which resolves names itself and never consults NSS. Check 5 therefore says
nothing about whether the machine can resolve a name; only check 4 does.
