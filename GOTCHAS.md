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
