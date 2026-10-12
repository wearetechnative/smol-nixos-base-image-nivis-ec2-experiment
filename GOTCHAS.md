# GOTCHAS

Every non-obvious failure and its cause. Append on every surprise, including
surprises that did not cost an experiment. The `smol-experimenter` subagent
reads this file before it writes a module.

## Seeded from prior art (BRIEFING §11)

- The kernel's built-in xz initramfs decoder cannot read multi-threaded
  (`-T0`) xz streams: the initrd is silently truncated and the kernel panics
  at root mount. Use `-9 -e --check=crc32`. (siraben)
- `security.wrappers` must stay: pam_unix needs `unix_chkpwd`, otherwise login
  fails and getty loops. (siraben)
- `system.etc.overlay` requires systemd in the initrd. (siraben)
- Slim systemd and minimal util-linux must be `nixpkgs.overlays`, otherwise
  consumers pull in a second full build and the closure grows. (siraben)
- Removing `programs/ssh.nix` via `disabledModules` breaks other modules
  unless an `options.programs.ssh = lib.mkOption { }` stub is added. (natkr)
- Removing `$out/kernel-modules` disables runtime module loading. On EC2, ENA
  and NVMe (and `xen-blkfront` for Xen instance types) must then be in the
  initrd or built into the kernel.
- `nix.enable = false` still leaves `register-nix-paths` pulling Nix into the
  closure; override it. (natkr)
- `nixpkgs.overlays` is ignored when a prebuilt `pkgs` is passed to
  `nixosSystem`. The flake therefore passes `nixpkgs.hostPlatform` as a module
  and never a `pkgs` argument.

## Found by this lab

- **jj does not export to git until it snapshots.** Nix reads the git index to
  decide which files are part of the flake, so a freshly written file is
  invisible to `nix build` and fails with "not tracked by Git". Run `jj st`
  (which snapshots the working copy into the git index) before any `nix`
  command. Every `justfile` recipe that calls nix does this already.
- **`virtualisation/amazon-image.nix` conflicts with the NixOS test driver**
  on `networking.hostName` (it pins the empty string),
  `systemd.services."serial-getty@ttyS0"` and the bootloader/filesystem
  options. `lab/test-support/qemu.nix` forces those back. Every entry in that
  file is a hole in gate 1 that only gate 2 can cover, so keep the list short
  and justified.
- **`beans roadmap` produces an empty document** in beans 0.4.2, even with
  milestones and epics present and `--status` passed explicitly. Use
  `just status`, which prints `beans list` and `openspec list`, until the
  roadmap command works.
- **The vmimport service role is the expensive part of the EC2 pipeline.** AWS
  requires it for disk-image import, and nivis's example creates it per
  deployment, which drags `iam:CreateRole`, `iam:CreatePolicy` and
  `iam:AttachRolePolicy` into whatever role runs the lab. Create it once in
  the bootstrap instead and point `aws_ebs_snapshot_import.role_name` at it.
  See `experiments/000-nivis.md` gap 3.
- **`default_tags` in the AWS provider is a list-nested block**, so nivis takes
  `default_tags = [ { tags = { ... }; } ];`. A bare attrset is rejected at
  apply. The same applies to `disk_container` and `user_bucket`.
- **`aws_s3_object` and `aws_iam_role_policy_attachment` are not taggable.** An
  IAM condition that requires `aws:RequestTag/Project` on every create will
  block those two and break the pipeline.
- **IAM resolves a trust policy's principal at write time.** Creating a role
  whose trust policy names a user that does not exist yet fails with
  `MalformedPolicyDocument: Invalid principal in policy`. Create the user
  first. A policy that only names the role as a `Resource` has no such
  problem, because resource ARNs are not resolved. `bootstrap.sh` therefore
  creates `smol-lab-ci` before `SmolLabRole`, and retries the role creation a
  few times to ride out IAM's propagation delay.
- **AWS Budgets only accepts the account's billing currency.** Asking for a
  budget in EUR on a USD-billed account fails with `InvalidParameterException:
  EUR is not in the supported unit set: [USD]`. There is no conversion; pick
  the account's currency and adjust the amount.
- **`aws configure set` opens `~/.aws/config` even when writing a credential
  key.** On a machine where that file is managed by home-manager it is
  read-only, and the call fails with `Permission denied` after the access key
  has already been created, leaving an unusable key in the account. The lab
  keeps its own config at `lab/aws-config` and points `AWS_CONFIG_FILE` at it;
  `lab/aws-key.sh` deletes the key again if storing fails.
- **A shell with an AWS profile already active leaks credentials through the
  environment**, and `AWS_ACCESS_KEY_ID` or `AWS_SESSION_TOKEN` win over
  anything a profile says. `lab/aws-env.sh` unsets them so the lab's profile
  is authoritative. A diagnostic that swallows the AWS error message makes
  this almost impossible to find, so `lab/aws-check.sh` prints it.
- **An IAM condition on `aws:RequestTag` denies a create that also touches an
  untaggable resource.** `ec2:CreateSecurityGroup` is authorised against both
  the new security group and the VPC it goes in. The VPC is not being
  created, so it carries no request tag, and a single tag-conditioned
  statement covering `Resource: "*"` denies the whole call. Split the
  statement: the created resource keeps the tag condition, the referenced one
  gets region-only. The same shape applies to `ec2:RegisterImage` and the
  snapshot it points at, and to `ec2:RunInstances` and everything it attaches.
- **Finding an IAM gap through a full deploy costs a 2.6 GB upload each
  time.** `just aws-probe` creates and destroys only the key pair and the
  security group, which covers most of the authorisation surface in seconds.
- **`ec2:ImportSnapshot` needs `iam:PassRole` on the `vmimport` role.** The
  caller hands the role to the VM Import service, and AWS checks that it may.
  Grant it narrowly: `iam:PassRole` on that one role ARN, conditioned on
  `iam:PassedToService: vmie.amazonaws.com`. It does not let the role create
  or modify IAM.
- **`ec2:RegisterImage` registers the AMI first and tags it afterwards**, so
  there is no `aws:RequestTag` at register time and a tag-conditioned
  statement denies it. Allow it with the region condition only; the AMI is
  tagged a moment later through `ec2:CreateTags`, which does carry the tag, so
  the delete path stays gated on `ec2:ResourceTag`.
- **`nivis --target` does not restrict the graph** the way the name suggests.
  An early version of `lab/aws-probe.sh` used it to reach one resource and
  paid for the full 2.6 GiB upload anyway. The plan takes a `scope` variable
  instead, and `scope=cheap` drops every resource that needs the image.
- **`systems/baseline` must set `smol.profile` with `mkDefault`.** A plain
  assignment there conflicts with `systems/accepted` picking a profile, and
  the module system refuses rather than letting the more specific system win.
  Changing it to `mkDefault` leaves the evaluated value identical, so the
  baseline derivation hash and ledger line 1 are unaffected. Verified by
  comparing the toplevel store path before and after.
- **`system.disableInstallerTools` does not remove `nixos-rebuild`** on an EC2
  image. It only gates `environment.systemPackages` through
  `system.tools.<name>.enable`. `virtualisation/amazon-init.nix` puts
  `config.system.build.nixos-rebuild` on its service PATH, so the tool and
  its CPython stay in the closure until amazon-init goes too. Caught by a
  `system.forbiddenDependenciesRegexes` guard on its first outing, which
  turned a silent null result into a diagnosis.
- **amazon-init is not what injects the SSH key.** It is easy to assume so,
  and removing it looks alarming for contract check 1. The key comes from
  `ec2-metadata-fetcher`, a separate service, and check 1 keeps passing.
- **`amazon-ec2-utils` keeps a full CPython in any EC2 image.**
  `51-ec2-hvm-devices.rules` runs `ebsnvme-id`, a Python script, to map
  `xvd*` names onto NVMe devices. One udev rule holds 136.55 MiB. Nothing in
  the published ISO work hits this, which is why our floor sits higher.
- **A delta that is smaller than expected needs `nix why-depends` run again**,
  not a shrug. Experiment 005 aimed at a 136.55 MiB interpreter, saved 12.34
  MiB, and the explanation was a second holder nobody had looked for.
- **`runNixOSTest` hands each node a prebuilt `pkgs`**, so a strategy that
  installs `nixpkgs.overlays` from inside `config` fails gate 1 with
  "`nodes.target.nixpkgs.overlays` is defined multiple times while it's
  expected to be unique". It is the same trap as passing a prebuilt `pkgs` to
  `nixosSystem`, one layer down, and it blocks every overlay-based strategy
  including siraben's slim systemd and util-linux. Set
  `node.pkgsReadOnly = false` on the test.
- **`amazon-ec2-utils` has a custom `installPhase` that never calls
  `runHook postInstall`**, so a `postInstall` override on it silently does
  nothing. Use `preFixup`, which also lands before `patchShebangs` and so
  prevents the CPython reference rather than removing it afterwards. Its
  `installCheckPhase` runs `ebsnvme-id --help`, so `doInstallCheck` has to go
  too.
- **CPython has four separate holders in a stock EC2 NixOS image.**
  `nixos-rebuild` (twice over, through `systemPackages` and through
  amazon-init's service PATH), `ebsnvme-id` in `amazon-ec2-utils`, and
  `ec2metadata` in `cloud-utils`, which rides along with `growpart`. Removing
  any three of them saves nothing. Follow `nix why-depends` until it comes
  back empty rather than stopping at the first consumer.
- **Dropping `$out/kernel-modules` breaks the network before it breaks
  anything else.** The briefing's seed warns that ENA and NVMe must be in the
  initrd or built in; the detail that costs an experiment is that they are
  not symmetrical. `nvme` is in `boot.initrd.availableKernelModules`, so udev
  loads it in the initrd to find the root device. `ena` is in neither list,
  because nothing in the initrd needs a network. So the instance boots,
  mounts root, starts systemd, and then sits there unable to reach IMDS at
  169.254.169.254. Pin it with `boot.initrd.kernelModules = [ "ena" ]`, which
  force-loads it while the module still exists.
- **`system.systemBuilderCommands` needs `lib.mkAfter`** when removing
  something the builder creates. Without it the removal merges before
  `kernel.nix`'s own `ln -s $out/kernel-modules` and the symlink comes
  straight back, with the build succeeding and the closure unchanged.
- **`boot.kernelPatches` takes `structuredExtraConfig`**, not
  `extraStructuredConfig`, and every entry needs `lib.mkForce` because
  nixpkgs' `common-config.nix` already has an opinion about nearly all of
  them. Even then, disabling whole subsystems derails the `make config`
  dialogue: the answer script runs off the end and prints "Error in reading
  or end of file" several hundred times, naming no symbol.
- **`CONFIG_PACKET=m`, and dhcpcd cannot send DHCP without it.** With the
  module tree removed the link comes up, the driver is loaded, and
  `A start job is running for DHCP Client` repeats until the timeout with no
  error anywhere. Nothing in that symptom points at a kernel module. Add
  `af_packet` to `boot.initrd.kernelModules`.
- **Before removing a mechanism rather than a package, enumerate what depends
  on it.** `grep '=m' "$(nix build .#...kernel.configfile)"` against the
  services that start after switch-root produces the whole list in one pass.
  Doing it afterwards cost this lab two EC2 round trips across experiments
  015 and 016.
- **Gate 1 cannot see a missing device driver.** Under QEMU every device is
  virtio and built into the kernel, so a candidate with no ENA driver and no
  loadable `af_packet` passes all ten checks locally and fails to get a
  network on EC2. That boundary is the reason gate 2 exists, and it is worth
  stating when gate 1 passes a change that touches hardware support.
- **The closure is not the image.** `nixos/lib/make-disk-image.nix` defaults
  `copyChannel` to `true`, which puts a complete copy of the nixpkgs source
  tree into the image as a nix channel. It goes into the image's own store
  through `basePaths`, so it never appears in
  `system.build.toplevel` and no closure measurement can see it. It was 544
  MiB here. Measure the artefact that gets uploaded, not only the one
  `nix path-info` can report on.
- **`maintainers/scripts/ec2/amazon-image.nix` forces `diskSize` to 4096
  MiB** where make-disk-image's own default is `"auto"`. Overriding it means
  the EBS volume created from the snapshot is only as large as the image, so
  `growpart` has nothing to grow into. Size the root volume at launch with
  `root_block_device` instead, which is how a production AMI works anyway.
- **`image.modules.<name>` is an `attrsOf deferredModule`**, so a definition
  there merges with nixpkgs' own and applies only inside that image's
  evaluation. It is the right place to override an image builder without
  touching the system configuration.
- **Assert that a search-and-replace matched.** An unasserted replace in
  `lab/nivis-plan.nix` silently did nothing after the file had been
  reformatted, landing a variable's use without its declaration. It cost an
  experiment.
- **`nix build --print-out-paths` prints every output**, so a bare
  `path=$(nix build --print-out-paths ...)` on a multi-output package yields
  several lines and a path that does not exist. `lab/deploy-ec2.sh` pushed a
  static curl that way and it worked until the `man` output happened to get
  built, at which point gate 2 reported "no curl on PATH" and blamed the
  candidate. Pick the output that holds the binary, and fail loudly if the
  push fails rather than letting the contract report a missing client.
- **Turning a systemd feature off in the package is half the job.** NixOS
  still references what the feature would have installed, and the error is
  always a build failure naming a missing file under `${systemd}`. Some have
  a NixOS option (`systemd.coredump.enable`, `systemd.oomd.enable`); the ones
  in `upstreamSystemUnits` do not, and `systemd.suppressedSystemUnits` is the
  lever, because `enabledUpstreamSystemUnits` filters by it before copying.
- **`withQrencode` is not optional on a headless server.** It gates
  `systemd-bsod.service`, which NixOS puts in the initrd's unit list
  unconditionally. The most obviously useless feature in the list is the one
  that cannot be removed.
- **An overlay on `systemd` does not touch `systemdMinimal`.** They are
  separate nixpkgs attributes, so slimming one leaves the duplicate at full
  size.
- **Re-list the closure after an experiment that claimed to remove a path.**
  Experiment 31's note said it had removed GRUB; experiment 36's top-paths
  listing showed GRUB still there at 36.30 MiB, held by
  `switch-to-configuration` as well as by the system path. The rule from
  experiment 9 exists for this and was not followed.
- **Switching from GRUB to systemd-boot to escape Perl trades up, not down.**
  NixOS installs systemd-boot with `systemd-boot-builder.py`, so the 55.18
  MiB of perl and 36.30 MiB of GRUB become a 136 MiB CPython. One `grep` for
  `python` in `systemd-boot.nix` is cheaper than the experiment.
- **`switch-to-configuration` is the sole remaining holder of 127.53 MiB.**
  perl through `install-grub.pl`, GRUB through `grub-config.xml`,
  `systemd-minimal` through `dbus-lib` and `libfido2`, plus itself. Four
  separate lines of attack ended there. It cannot be removed because
  `system.build.images.amazon` calls it to install the bootloader, which is
  the lab's one `needs-upstream` item.
- **Refining a module `systems/accepted` already enables moves both sides of
  the comparison.** `lab/experiment.sh` measures the candidate against the
  accepted system, and both read the same module file, so the delta reads as
  exactly zero and the experiment is rejected while the saving is real but
  untracked and ungated. Experiment 40 hit this: `systems/accepted` quietly
  went from 501.82 to 489 MiB with nothing in the ledger to say so. Add an
  option and flip it in the candidate, so the two systems genuinely differ.

## `nix why-depends` without `--all` records one reason, not the reason

`FLOOR.md`'s holder column was filled in from single `nix why-depends`
runs. That shows one path to the store path, and the module system is full
of store paths with several independent holders: `file-5.48` had two,
`systemd-minimal` had five (#18, #20, #45, #47, #48), and after `smol.noPerl`
the holder of `gcc-16.2.0-lib` changed without anyone editing that row.

Trace with `--all` before deciding, and re-trace a holder recorded by an
earlier experiment rather than trusting the note. A removal aimed at a path
with a second holder passes both gates, logs a real but small delta, and
leaves the number in `FLOOR.md` looking unexplained. Experiment 49 is that
case exactly.

## `mkForce` on a service `path` also discards the default service path

`nixos/lib/systemd-lib.nix` gives every stage-2 service `coreutils`,
`findutils`, `gnugrep`, `gnused` and `systemd` through a `mkAfter`
definition of the same option. `lib.mkForce [ pkgs.curl ]` on
`systemd.services.<name>.path` wins over that too, so the unit runs with
`curl` alone and dies on the first `mkdir`.

Experiment 50 is the case: gate 1 passed, the EC2 instance never came up,
and the serial console said `mkdir: command not found`. When forcing a
service path, restate that list. Experiment 51 does.

## The store fills up, and the lab account cannot empty it

`/etc/nix/nix.conf` on this machine sets `keep-failed = true`,
`keep-outputs = true` and `keep-derivations = true`. Together they mean:

- every failed build leaves its build directory in `/nix/var/nix/builds`,
  owned by `nixbld`. It reached 8.6 GiB by experiment 57.
- every image this lab has ever built stays alive as long as its `.drv` is
  reachable from a root, so `nix store delete` refuses it and
  `nix-store --delete --ignore-liveness` is not permitted to a non-trusted
  user.

An overlay on a package as deep as `curl`, `util-linux` or `dbus` rebuilds
everything downstream of it, QEMU included, and that chain wants more than
10 GiB. When free space drops under about 15 GiB, stop and ask Pim for

```sh
sudo rm -rf /nix/var/nix/builds/*
sudo nix-collect-garbage --delete-older-than 7d
```

rather than letting a forty-minute build die on ENOSPC. Nothing in
`ledger.jsonl` depends on a store path still existing: every image is
rebuilt from the flake when it is needed.

## An overlay rebuilds the build world, not just the appliance

`nixpkgs.overlays` is how every package strategy here is written, and it is
right when the package sits deep in the appliance: systemd (#36), util-linux
(#48, #56), dbus (#48, #55), iproute2 (#53). Each of those rebuilds a
handful of things, or QEMU once.

`curl` is different. LLVM links libcurl for debuginfod, so an overlay on
curl rebuilds LLVM, clang, mesa and QEMU. Experiment 57 ran three hours and
reached `clang-21.1.8` before it was killed, for an expected 4.8 MiB.

Experiment 59 took most of the sting out of this: the image builder's VM
now comes from an unoverlaid nixpkgs, so a package override no longer
rebuilds QEMU, gtk4, mesa and pipewire. It does not help with LLVM, which
is a build input of the package itself rather than of the builder.

Before overriding a package, ask what takes it as a *build* input, not only
what references it at runtime:

```sh
nix why-depends --all .#nixosConfigurations.accepted-x86_64-linux.config.system.build.toplevel <path>   # runtime
nix-store --query --referrers-closure $(nix eval --raw nixpkgs#curl.drvPath)                            # build
```

When the package is referenced from one place in the image, override it
there instead. Experiment 58 does that and rebuilds one package.

## `prev.<attr>` does not escape an override you made in the same overlay

nixpkgs resolves its own definitions against the *final* package set. So
when an overlay does

```nix
systemd = prev.systemd.override { util-linux = final.util-linux; };
```

every attribute defined in terms of `systemd` picks the argument up, even
`systemdMinimal` and `systemdLibs`, which exist precisely to avoid that.
Writing `systemdMinimal = prev.systemdMinimal;` next to it changes
nothing: the value comes from the previous layer, but its definition is
still `self.systemd.override { ... }` with `self` the final set.

In experiment 65 that made a real cycle, since `linux-pam` takes
`systemd-minimal-libs` and a full util-linux takes `linux-pam`. Nix
reports `infinite recursion encountered` with a trace through
`sulogin-path`.

When a package is only reachable through a *string* in `/etc`, change the
string. That experiment took 8.72 MiB without touching a derivation.

