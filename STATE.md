# STATE

Single source of truth for where the lab is right now (BRIEFING §10). Update
it at every step change, not at the end of a session.

## Phase

Phase 0 complete. Phase 2 in progress, ahead of phase 1: auditing the
platform's own defaults turned out to pay better than replaying the ISO work,
so that came first.

## Where the appliance track stands

Two numbers now, because they are not the same thing and this lab spent
twenty-one experiments assuming they tracked each other.

| measure | baseline | now | off |
| ------- | -------- | --- | --- |
| closure | 1516.25 MiB | 364.27 MiB | 76.0% |
| raw VHD | 2598.64 MiB | 482.13 MiB | 81.4% |
| boot time | 40.8s | 14.1s | 65.4% |

Twenty-one accepted strategies. The image is what gets uploaded, imported as a
snapshot and stored as an AMI, so it is the number that costs money.

| id  | strategy | closure after | delta |
| --- | -------- | ------------- | ----- |
| 1   | baseline | 1516.25 MiB | frozen reference |
| 2   | `noFlakeRegistry` | 1316.50 MiB | 199.75, 13.2% |
| 3   | `noInstallerTools` | rejected, build failed | guard caught an incomplete removal |
| 4   | `noAmazonInit` | 1215.40 MiB | 101.10, 7.7% |
| 5   | `noInstallerTools` | 1203.06 MiB | 12.34, 1.0% |
| 6   | `noSsmAgent` | 1092.73 MiB | 110.33, 9.2% |
| 7   | `noEbsNvmeId` | rejected, build failed | wrong build phase, my error |
| 8   | `noPython` | rejected, gate 1 failed | harness could not handle an overlay |
| 9   | `noPython` | 955.86 MiB | 136.87, 12.5% |
| 10  | `noDocumentation` | 861.99 MiB | 93.87, 9.8% |
| 11  | `noDefaultPackages` | 858.60 MiB | 3.39, 0.4% |
| 12  | `nitroKernel` | rejected, build failed | kconfig dialogue derails |
| 13  | `noKernelModules` | rejected, gate 1 failed | firewall needs netfilter modules |
| 14  | `noFirewall` | 851.07 MiB | 7.53, 0.9% |
| 15  | `noKernelModules` | rejected, gate 2 failed | no `ena`, no network |
| 16  | `noKernelModules` | rejected, gate 2 failed | no `af_packet`, dhcpcd hangs |
| 17  | `noKernelModules` | 698.13 MiB | 152.93, 18.0% |
| 18  | `noDuplicateSystemd` | rejected, build failed | util-linux lastlog ships the tmpfiles fragment |
| 19  | `noLastlog` | 698.13 MiB | 3344 bytes; sqlite stays |
| 20  | `noDuplicateSystemd` | rejected, guard failed | two more holders of systemd-minimal |
| 21  | `noSwitchToConfiguration` | rejected, gate 2 failed | **needs-upstream**: the amazon image builder calls it |
| 22  | `leanImage` | rejected by the protocol | it only compared closures; fixed |
| 23  | `leanImage` | rejected, gate 2 failed | auto-sized image left growpart nothing to grow into |
| 24  | `leanImage` | rejected, nix eval | my error: declaration missing, use present |
| 25  | `leanImage` | **image 1400.35 to 856.21 MiB** | 544.14, 38.9%, closure unchanged |
| 26  | `noNix` | 610.59 MiB | 87.54, 12.5%; the appliance track still had Nix |
| 27 to 30 | `minimalSystemPackages` | rejected | three lab defects, one real |
| 31  | `minimalSystemPackages` | 553.27 MiB | 57.32, 9.4%; 57 packages down to 16 |
| 32 to 35 | `slimSystemd` | rejected | four builds, each naming one missing systemd file |
| 36  | `slimSystemd` | 515.03 MiB | 38.24, 6.9%; systemd 63.02 to 52.04 MiB |
| 37  | `noPerl` | rejected | **needs-upstream**: perl is held by `install-grub.pl` |
| 38  | `emptyHwdb` | rejected, build failed | `systemd-hwdb` writes nothing from no input |
| 39  | `emptyHwdb` | 501.82 MiB | 13.21, 2.6% |
| 40  | `minimalCoreutils` | rejected | protocol trap: both sides of the comparison moved |
| 41  | `minimalCoreutils` | 489.07 MiB | 12.75, 2.5% |
| 42  | `minimalInitrdModules` | rejected, gate 1 panicked | 1.41 MiB; the initrd is userland, not modules |
| 43  | `noSudo` | 483.26 MiB | 5.81, 1.2%; found by writing `FLOOR.md` |
| 44  | `noSwitchToConfiguration` | rejected, disk full | gate 1 passed; the machine, not the candidate |
| 45  | `noSwitchToConfiguration` | 428.60 MiB | 54.65, 11.3%; the blocker removed |
| 46  | `noPerl` | 386.38 MiB | 58.00, 13.7%; the same module that saved nothing in #37 |
| 47  | `noDuplicateSystemd` | rejected, guard | two more holders: dbus and pam |
| 48  | `noDuplicateSystemd` | 364.27 MiB | 22.11, 6.1% |

Boot time has moved between 12.3s and 41.9s with no clear relationship to
closure size.

## The blocker is gone

`s6` was `needs-upstream` from experiment 21 and held 127.53 MiB, a quarter
of the closure, behind one line of nixpkgs' image builder.
`smol.leanImage` has owned the `make-disk-image` call since experiment 25,
so the fix was always ours: the bootloader step now bind-mounts the builder's
store over the image's store, which makes the installer reachable inside the
chroot without anything entering the runtime closure.

| # | strategy | closure saving |
| - | -------- | -------------- |
| 45 | `noSwitchToConfiguration` | 54.65 MiB |
| 46 | `noPerl`, unchanged since it measured zero in #37 | 58.00 MiB |
| 48 | `noDuplicateSystemd`, after two more holders turned up | 22.11 MiB |

134.76 MiB against the 127.53 MiB predicted.

Still worth proposing upstream, because every NixOS EC2 image pays it, but
it belongs in `REPORT.md`'s recommendations rather than on the backlog.

Switching to systemd-boot to escape `install-grub.pl` was checked and
rejected without running it: NixOS installs systemd-boot with
`systemd-boot-builder.py`, so it would have traded 91 MiB of perl and GRUB
for a 136 MiB CPython.

## What is left

| MiB   | path | status |
| ----- | ---- | ------ |
| 52.04 | `systemd-261.3` | slimmed in #36; further cuts hit NixOS's unit list |
| 33.93 | `glibc-2.44-25` | the C library |
| 24.77 | `initrd-linux-6.18.55` | mostly a systemd userland this lab put there in #17 |
| 21.97 | `linux-6.18.55` | the bzImage |
| 13.98 | `util-linux-2.42.3-lib` | libmount, libblkid, libuuid |
| 10.54 | `file-5.48` | on `fetch-ec2-metadata.service`'s PATH |
| 10.31 | `gcc-16.2.0-lib` | held perl before; the holder has changed and needs retracing |
| 9.60  | `util-linux-2.42.3-bin` | `findmnt` is contract check 7 |
| 9.00  | `openssl-3.5.8` | sshd and TLS trust |
| 8.78  | `openssh-10.5p1` | the only way in |
| 8.72  | `util-linux-minimal-2.42.3-bin` | a second util-linux, the same shape as the systemd duplicate just removed |
| 7.20  | `linux-headers-static-7.2` | the wrapper builder |

The top four are 132.71 MiB and are the system itself.

## Disk

The machine filled up during experiment 44: 216 GB, 84 MB free. 88 image
derivations from this lab were holding 33 GB, all of them dead, and
deleting just those freed 32.8 GiB. **Each gate 2 run leaves a 500 MiB image
behind**, so this needs doing periodically.

A general `nix-collect-garbage` would free far more, 17877 paths, and is
Pim's call, since it also drops his other projects' build products.

## Current experiment

None in flight. Forty-eight ledger entries, the account is empty,
`systems/candidate` is reset to `systems/accepted`.

| field         | value |
| ------------- | ----- |
| experiment id | 48, done |
| slug          | no-duplicate-systemd |
| step          | logged |
| branch        | main |

Steps are `building | measuring | gate1 | gate2 | logging`.

## The baseline, frozen

Ledger line 1. `systems/baseline` does not change from here. Verified
byte-identical after the `mkDefault` change in experiment 002.

| measure           | value |
| ----------------- | ----- |
| closure           | 1516.25 MiB |
| image, raw VHD    | 2598.64 MiB |
| boot time         | 40.753s |
| gate 1            | pass, 10 of 10, twice |
| gate 2            | pass, 10 of 10, twice |

Largest paths: the nixpkgs source at 199.75 MiB, `linux-6.18.55-modules` at
145.17, `python3-3.14.7` at 136.55, `amazon-ssm-agent` at 110.09, `systemd`
at 63.02. The first four have no obvious business in an appliance image.

## Cost of one experiment

About 15 minutes of gate 2 once the image is built: 2m52s upload, 7m51s
snapshot import, 3 minutes to verify twice, under a minute to tear down. The
snapshot import dominates and is AWS's. BRIEFING §9 stops at 4 EC2 hours in a
session, which is roughly 16 runs.

## Live AWS resources

None. If this table is non-empty on resume, run `just reap` before anything
else.

| kind | id  | region | created |
| ---- | --- | ------ | ------- |
| none | n/a | n/a    | n/a     |

`just reap` reports nothing to reap. Nine deployments so far, six of them
successful and three failed mid-apply, and every one tore itself down.

## Decided with Pim, 2026-10-09

- Region: `eu-central-1`, in `lab/config.env`.
- The `vmimport` role and the lab bucket are created once by
  `infra/iam/bootstrap.sh`, not per deployment. `SmolLabRole` therefore has no
  IAM write permission and no `s3:CreateBucket`.
- `lab/console.sh` and the `lab/reap.sh` fallback may call `aws ec2` directly.
  Both are read-only diagnostics or tag-filtered cleanup on resources the lab
  created, not a deployment path. Deployment still goes through nivis only.
- Budget: 50 EUR per month, alert at 80 percent.
- Instance types: `t3.micro` and `t3.small`, enforced by the IAM policy.

## AWS access

Working since 2026-10-09. `just aws-check`:

```
PASS: arn:aws:sts::076504012268:assumed-role/SmolLabRole/smol-lab
      region eu-central-1, tagged launch of t3.micro permitted
```

The lab's AWS profiles live in `lab/aws-config`, generated from
`lab/config.env` and selected with `AWS_CONFIG_FILE`, because `~/.aws/config`
is managed by home-manager here. The access key is in `~/.aws/credentials`
under `[smol-lab-base]`.

Nothing is blocked any more.

## Decided with Pim, 2026-10-09, second round

Claude runs `infra/iam/bootstrap.sh` and may call `aws` directly. Recorded as
an amendment in BRIEFING §7, because the briefing said the opposite and the
briefing wins where the repo disagrees with it.

The trade, stated plainly: Claude can now rewrite `SmolLabRole`, so the fence
around the playground account is no longer one Claude cannot move. Reading
anything from `~/.aws/` is still denied, and no secret is ever printed.

Pim applied the matching edit to `.claude/settings.json` on 2026-10-09. The
harness blocks an agent from editing its own allow list, which is the right
default and worth keeping, so that edit stays a human one.

## Still open, not blocking

- Is the mutable track wanted, or is the appliance track enough for the alpha?
  Only affects milestone `03`, and the "Mutable track" epic carries it.
- The Graviton track needs an aarch64 builder or emulation. Until then
  `nix flake check` evaluates those outputs but cannot build them.

## What already works

- `nix flake check` passes: gate 1 for both `candidate` and `accepted`, plus
  shellcheck on `lab/*.sh`. It builds x86_64-linux only; aarch64-linux
  evaluates but is omitted as incompatible, so the Graviton track needs a
  builder before it means anything.
- `just gate1 accepted` passes all ten contract checks on first boot and again
  after a reboot.
- `just measure <variant>` emits the measurement JSON, including image size
  when `SMOL_IMAGE` points at a built image.
- `just gate2 <id> <variant>` deploys through nivis, verifies twice around a
  reboot, and tears everything down.
- `just aws-check`, `just aws-probe`, `just reap`, `just reap-dry`,
  `just console <instance>`.
- `just docs` regenerates `docs/options.md`.

## What nivis covers, and what it does not

`experiments/000-nivis.md` has the detail. nivis drives the whole pipeline:
build, upload, snapshot import, AMI registration, launch, reading the public
IP back out of state, and teardown in reverse order. Region and instance type
go in through `mkVars`; tagging through `default_tags` on the provider.

Three things it does not cover: serial console output, orphans from a run that
died before writing state, and SSH itself. The example pipeline opens port 80
and has no key pair, so `lab/deploy-ec2.sh` adds an `aws_key_pair` and ingress
on 22. That key pair is what makes contract check 1 real.

## What gate 2 established

- Check 1 passes on EC2: `/root/.ssh/authorized_keys` is a real file outside
  the nix store, so the key arrives through instance metadata. Gate 1 can
  only skip this.
- The root device is `/dev/nvme0n1p2`, so NVMe loaded and this is a genuine
  Nitro boot. This is the check a kernel or initrd trim is most likely to
  break.
- Teardown is unconditional and proven: three failed attempts each cleaned up
  after themselves without being asked, including the EBS snapshot.
- Three IAM gaps, all found by running it and all now in `GOTCHAS.md`:
  `CreateSecurityGroup` is authorised against the VPC too, `ImportSnapshot`
  needs `iam:PassRole` on `vmimport`, and `RegisterImage` tags after
  registering so there is no request tag to condition on.
- `just aws-probe` now dry-runs `RegisterImage` and `RunInstances` alongside
  creating the cheap pair for real, so the next gap of that kind costs
  seconds. Only `ImportSnapshot` still needs a real upload to reach.

## Next three planned experiments

1. `util-linux-minimal` at 8.72 MiB, a second util-linux build reached
   through `systemd-generator-environment.json`. The same shape as the
   systemd duplicate that experiment 48 removed.
2. Retrace `gcc-16.2.0-lib` and `file` in `FLOOR.md`, and settle `elfutils`
   and the second Berkeley DB, which are still untraced.
3. `s4`: xz the initrd, the only lever left on it, with the briefing's
   single-threaded crc32 gotcha.

## Stop criteria, where they stand

Criterion 1, "the last 8 accepted experiments each saved < 1% or < 2 MiB":
not met, and experiment 25 moved it further away.

Criterion 2: one item is `needs-upstream` with a concrete nixpkgs change
named. Fifteen backlog items are still `todo`, three of them new this
session.

Criterion 3: `FLOOR.md` is written and needs a pass after experiments 45 to
48, which removed five of the paths it listed. Several entries still have no
justification, so the criterion is not met.

## Checkpoints

Write one every 5 experiments.

- 2026-10-11, after experiment 48: **1516.25 to 364.27 MiB, 76.0% off, and
  the raw VHD 2598.64 to 482.13 MiB, 81.4%.** The `needs-upstream` blocker
  turned out to be removable here, because `smol.leanImage` already owned
  the `make-disk-image` call. That unlocked 134.76 MiB across three
  experiments, one of which was a module written in #37, measured zero, and
  kept unchanged for exactly this moment. The lesson is about
  classification: `needs-upstream` was recorded honestly and closed the
  question too early.
- 2026-10-11, after experiment 43: **1516.25 to 483.26 MiB, 68.1% off, and
  the raw VHD 2598.64 to 592.16 MiB, 77.2%.** Eighteen accepted. This block
  added noNix (the appliance track had carried Nix for 25 experiments),
  minimalSystemPackages (57 packages to 16), slimSystemd, emptyHwdb,
  coreutils and noSudo. `FLOOR.md` is written and is now what drives the
  queue. Two findings matter more than the numbers: one nixpkgs change is
  worth 127.53 MiB, and `lab/experiment.sh` had a silent hole where
  refining an already-accepted module put an ungated change into the tree
  with a measured delta of zero.
- 2026-10-11, after experiment 25: **the raw VHD went from 1400.35 to
  856.21 MiB, 544.14 MiB off, with the closure unchanged by a single byte**,
  and boot time fell from 36.4s to 14.3s. It came from reading
  `nixos/lib/make-disk-image.nix` rather than the closure: `copyChannel`
  defaults to true and puts a full nixpkgs source tree in the image, where no
  closure measurement can see it. The protocol had the same blind spot and
  rejected the strategy outright until `lab/experiment.sh` was taught to
  measure the image too. Twenty-one experiments had assumed the closure and
  the image tracked each other.
- 2026-10-10, after experiment 21: eleven accepted, still 698.13 MiB. Four
  experiments spent on the systemd duplicate and `switch-to-configuration`
  with nothing to show in the closure, but the ground is mapped:
  `systemd-minimal` has three holders, two of which sit behind
  `switch-to-configuration`, which in turn cannot be removed because the
  amazon image builder calls it. That last one is the lab's first
  `needs-upstream` item and the first failure neither gate was designed to
  catch, since gate 1 never builds an image and gate 2 only builds one on the
  way to an instance. The dependency guard earned its place twice more.
- 2026-10-10, after experiment 17: **1516.25 to 698.13 MiB, 54.0% off the
  baseline**, ten accepted. The module tree took three attempts and two
  failed EC2 deployments: `ena`, `af_packet`, `fuse` and `configfs` all have
  to be force-loaded in the initrd once nothing can be loaded at runtime.
  Gate 1 passed all three attempts, which is its boundary rather than a
  defect: under QEMU every device is virtio and built in, so a missing ENA
  driver is invisible. Removing the module tree also turned out to require
  giving up the in-guest firewall, which is the first strategy in this lab
  whose trade-off is security rather than convenience.
- 2026-10-10, after experiment 11: **1516.25 to 858.60 MiB, 43.4% off the
  baseline**, eight accepted strategies, three rejected. Two of the three
  rejections were my own implementation errors; the third, experiment 008,
  found that gate 1 could not handle a strategy installing an overlay, which
  would have blocked every siraben item. Boot time does not track closure
  size. The two natkr replays run so far both under-delivered against their
  ISO figures, because the savings they describe are partly already gone and
  partly held by things an ISO never carried.
- 2026-10-10, after experiment 6: **1516.25 to 1092.73 MiB, 27.9% off the
  baseline**, five accepted strategies, every one through both gates, boot
  time flat at about 40s. All of it came from auditing what
  `virtualisation/amazon-image.nix` and the flake wrapper turn on by default,
  none of it from the prior-art lists, which have not been started.
  `lab/experiment.sh` now runs build, measure, gate 1, gate 2, decide and log
  as one command. Three IAM gaps and four GOTCHAS found along the way. One
  rejected experiment, 003, where the dependency guard caught an incomplete
  removal and turned a null result into a diagnosis.

- 2026-10-09: repo scaffolded. Flake without flake-utils, `smol.*` module
  skeleton with profile and track, verification contract v1, gate 1 green with
  a gateway node that makes the DNS, HTTPS and NTP checks real, four beans
  milestones with their epics, OpenSpec initialised with the first change
  proposed.
