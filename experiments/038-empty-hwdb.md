# 038: empty-hwdb

Rejected, build failed. Full account in
`experiments/039-empty-hwdb.md`; this file exists because the ledger points
at it.

`systemd-hwdb update` with no input files prints `No hwdb files found,
skipping`, exits successfully and writes nothing, so `mv etc/udev/hwdb.bin`
fails. A single placeholder entry that matches nothing produces a valid
database.
