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
| 1 | key-based SSH login with a key injected from instance metadata | skipped, no IMDS | yes, confirmed in experiment 001 |
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
just gate2 <experiment-id> [variant]
```

Deploys through nivis: `lab/nivis-plan.nix` builds the image as a `drv` leaf,
uploads it to the lab bucket, imports it as an EBS snapshot, registers an AMI
and launches an instance. It waits for SSH with a ten minute timeout, pushes
the same static curl gate 1 uses, runs `lab/verify.sh` with `VERIFY_ENV=ec2`,
reboots, and runs it again. If SSH never comes up it fetches the serial
console with `lab/console.sh` and saves the output in the experiment note.

The reboot wait keys on `/proc/sys/kernel/random/boot_id` changing, not on
SSH answering, so a session that survives the reboot command cannot be
mistaken for a machine that came back.

Boot time is read off the guest with `systemd-analyze`. The API only knows
when the launch call returned, which is a different thing.

### What only gate 2 can prove

- **Check 1, the metadata key.** The verification keypair is generated per
  run, registered as an `aws_key_pair`, and never touches the image. Passing
  check 1 on EC2 means the key genuinely arrived through IMDS.
- **The Nitro drivers.** A baseline run shows the root device as
  `/dev/nvme0n1p2`, which is only true if the NVMe driver loaded. This is the
  check that a kernel or initrd trim is most likely to break.

### Teardown

Unconditional, in a trap on `EXIT`, `INT` and `TERM`. Pass, fail or
interrupt, the instance, AMI, snapshot, key pair, security group and uploaded
image all go. This was proven the hard way: the first three attempts failed
mid-apply on IAM gaps and each one cleaned up after itself without being
asked.

`just reap` is the backstop. It runs `nivis destroy` for every state file
under `experiments/state/`, then sweeps for resources tagged
`Project=smol-lab` older than `SMOL_REAP_AFTER_MINUTES` that no state file
accounts for. `just reap-dry` shows what it would remove.

### Finding an IAM gap without paying for it

```sh
just aws-probe
```

Seconds, no upload. It dry-runs `ec2:RegisterImage` and `ec2:RunInstances`,
which create nothing, and really creates and destroys the key pair and the
security group. Between them that is most of the authorisation surface.

What it cannot reach is `ec2:ImportSnapshot`, which needs a real uploaded
image. A gap there still costs one 11 minute round trip.

### Cost of one run

About 15 minutes once the image is built: 2m52s to upload 2.6 GiB, 7m51s for
the snapshot import, about 3 minutes to launch and verify twice, under a
minute to tear down. The snapshot import dominates and is AWS's.

## Running everything

```sh
just check     # nix flake check: both gates' eval, shellcheck, formatting
just gate1 accepted
```

`nix flake check` builds the gate 1 tests, so a broken harness fails before an
experiment ever starts. It builds x86_64-linux only; the aarch64-linux outputs
evaluate but are omitted as incompatible. The Graviton track needs an
aarch64 builder or emulation before gate 1 means anything there.
