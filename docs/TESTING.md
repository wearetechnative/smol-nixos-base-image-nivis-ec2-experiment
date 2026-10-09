# Testing

Two gates, one contract. Both gates run the exact same script,
`lab/verify.sh`, so they cannot drift apart. A candidate is accepted only when
both gates pass and the closure shrank (BRIEFING §8.5).

## The contract

`lab/verify.sh` is contract version 1. It runs on the target, prints TAP, and
exits non-zero on any failure. Changing it needs Pim's approval and starts a
new ledger epoch: results from the old contract stay valid only for the old
contract (BRIEFING §3).

| # | check | gate 1 | gate 2 |
| - | ----- | ------ | ------ |
| 1 | key-based SSH login with a key injected from instance metadata | skipped, no IMDS | yes |
| 2 | `systemctl is-system-running` is `running` | yes | yes |
| 3 | no failed units | yes | yes |
| 4 | DNS resolves | yes, against the gateway node | yes |
| 5 | outbound HTTPS succeeds | yes, against the gateway node | yes |
| 6 | clock is NTP synchronised | yes, against the gateway node | yes |
| 7 | root filesystem mounted read-write | yes | yes |
| 8 | root filesystem accepts writes | yes | yes |
| 9 | root filesystem is at least the expected size | yes | yes |
| 10 | mutable track: in-place update path works | skipped on the appliance track | yes |

Check 5 of BRIEFING §3, "survives a reboot and passes 1 to 4 again", is
orchestrated around the script: both gates run the contract, reboot, and run
it again.

### The target never ships curl

The HTTPS check needs an HTTPS client, and baking one into the image would
inflate every measurement. Both gates push a statically linked curl to
`/tmp/smol-curl` before verifying, and `verify.sh` points it at the image's
own CA bundle through `CURL_CA_BUNDLE`. So the check still proves the image
has working TLS trust, without the image carrying the client.

## Gate 1, local

```sh
just gate1 candidate      # or: accepted, baseline
just gate1-debug candidate  # interactive driver, for a boot that will not come up
```

Three nodes under the NixOS test driver:

- **target**: the system variant under test.
- **client**: connects over SSH with a snakeoil key and runs the contract.
  Nothing is executed from the host, so SSH itself is part of what is tested.
- **gateway**: dnsmasq authoritative for `smol-gate.test`, nginx serving
  HTTPS with a test CA, and chrony as an NTP server.

The gateway exists so checks 4, 5 and 6 are real locally. A bare NixOS test
network has no resolver, no reachable TLS endpoint and no time source, so
those three checks could otherwise only be skipped, and a strategy that broke
the resolver, the CA bundle or the time client would survive all the way to
gate 2.

### Known holes in gate 1

Every override in `lab/test-support/qemu.nix` is a thing gate 1 cannot prove.
Keep that file short, and justify every line in it:

| forced off | why | covered by |
| ---------- | --- | ---------- |
| `fileSystems`, grub | the test driver supplies its own root device and bootloader | gate 2 |
| `amazon-init`, `fetch-ec2-metadata`, `apply-ec2-data` | no instance metadata service | gate 2, check 1 |
| `growpart` | the test disk has no partition table to grow | gate 2 |
| `serial-getty@ttyS0` | `test-instrumentation.nix` owns the serial console | gate 2 |

## Gate 2, EC2

```sh
just gate2 <experiment-id>
```

Deploys through nivis, never through hand-written AWS calls. It waits for SSH
with a 10 minute timeout, runs the contract, reboots, runs it again, and
records the boot time. If SSH never comes up it fetches the serial console
with `lab/console.sh` and saves the output in the experiment note.

Teardown of the instance, the AMI and the snapshot is unconditional: pass or
fail, nothing is left running. `just reap` is the backstop for anything tagged
`Project=smol-lab` that outlived its experiment.

## Running everything

```sh
just check     # nix flake check: both gates' eval, shellcheck, formatting
just gate1 accepted
```

`nix flake check` builds the gate 1 tests, so a broken harness fails before an
experiment ever starts. It builds x86_64-linux only; the aarch64-linux outputs
evaluate but are omitted as incompatible. The Graviton track needs an
aarch64 builder or emulation before gate 1 means anything there.
