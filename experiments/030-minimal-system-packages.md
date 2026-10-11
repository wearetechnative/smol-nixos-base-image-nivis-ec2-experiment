# 030: minimal-system-packages

Rejected. Full account in
`experiments/031-minimal-system-packages.md`; this file exists because the
ledger points at it.

Gate 2 failed with `no curl at $VERIFY_CURL (/tmp/smol-curl) and none on
PATH`, which blamed the candidate for something it had not done.

`static-curl` is multi-output, so `nix build --print-out-paths` printed two
store paths and `lab/deploy-ec2.sh` concatenated them into an argument that
did not exist. Latent since gate 2 was written; it surfaced when the `man`
output happened to get built.

`deploy-ec2.sh` now selects the output that holds the binary and fails loudly
if the push fails, rather than letting the contract report a missing HTTPS
client.
