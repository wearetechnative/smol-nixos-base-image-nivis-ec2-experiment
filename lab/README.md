# lab/

The harness. Everything here runs the same contract, so the local gate and the
EC2 gate cannot drift apart.

| file | what it does | status |
| --------------------- | ------------------------------------------------- | ------ |
| `verify.sh`           | the verification contract, version 1, runs on the target | done |
| `test-local.nix`      | gate 1: target, client and gateway under the NixOS test driver | done |
| `test-support/qemu.nix` | every override gate 1 needs, each one a known hole | done |
| `test-support/net.nix`  | the gateway node: DNS, HTTPS with a test CA, NTP | done |
| `measure.sh`          | closure, image and compressed sizes, top 20 paths, as JSON | done |
| `config.env.example`  | the non-secret lab settings; copy to `config.env` | done |
| `experiment.sh`       | the pipeline of BRIEFING §8, appends a ledger line on every path | to write |
| `deploy-ec2.sh`       | gate 2: a thin adapter around nivis | to write |
| `console.sh`          | EC2 serial console output when SSH never comes up | to write |
| `reap.sh`             | terminate and deregister everything tagged `Project=smol-lab` | to write |
| `aws-check.sh`        | prove the assumed role works, pass or fail only | to write |

`config.env` is gitignored and holds no secrets. The access key lives only in
`~/.aws/credentials`, which nothing here reads.

See `docs/TESTING.md` for what the contract checks and which checks each gate
can actually prove.
