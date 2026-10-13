# REPORT

How small a NixOS EC2 base image gets while still booting on Nitro,
deploying through nivis, and passing a ten-check contract over SSH.

The lab ran 75 numbered experiments between 2026-10-09 and 2026-10-13: one
frozen baseline, 39 accepted, 33 rejected and 2 left undecided because
gate 2 was skipped. Four more attempts were abandoned before they measured
anything and so have no ledger line, which §4 and §5 describe. The lab is
closed: this file and `GOTCHAS.md` are what the next project inherits.

## 1. Result

| measure | baseline | final | off |
| ------- | -------- | ----- | --- |
| closure | 1516.25 MiB | **266.39 MiB** | 82.4% |
| raw VHD, uploaded to S3 | 2598.64 MiB | **380.10 MiB** | 85.4% |
| boot, t3.micro, guest-measured | 40.8s | 14.1s | 65% |

Both numbers matter and they are not the same thing. The closure is what
the machine is; the VHD is what gets uploaded, imported as an EBS snapshot
and stored as an AMI, and it is the number that costs money.

Every figure above is in `ledger.jsonl`, one line per experiment, and
nothing is claimed here that is not in it (BRIEFING §12).

### How to read the numbers

- **MiB is bytes divided by 1048576.** Several notes divided by 1000000
  through ledger #48 and said MiB; corrected at #51.
- **The image measure is quantised at about 2 MiB.** `qemu-img convert -O
  vpc` writes a sparse, CHS-rounded VHD, so a closure change of a few MiB
  can read as 0, as 2, or as 12 in the image column. #58 removed 2.84 MiB
  of closure with a byte-identical image; #73 shrank the closure and the
  image grew 6 MiB. Below about 2 MiB, read the closure.
- **Apparent size is not allocated size.** `stat -c %s` on the VHD reports
  the virtual disk; `du --block-size=1` reports what exists. The lab
  records the first, consistently, and the gap is 5 to 10 percent.

## 2. Where the size went

| # | strategy | closure MiB | image MiB |
| --- | --- | --- | --- |
| 2 | `no-flake-registry` | 199.75 | +0.00 |
| 17 | `no-kernel-modules` | 152.93 | +0.00 |
| 9 | `no-python` | 136.91 | +0.00 |
| 6 | `no-ssm-agent` | 110.33 | +0.00 |
| 4 | `no-amazon-init` | 101.10 | +0.00 |
| 10 | `no-documentation` | 93.83 | +0.00 |
| 26 | `no-nix` | 87.54 | +94.02 |
| 46 | `no-perl` | 58.75 | +68.02 |
| 31 | `minimal-system-packages` | 57.60 | +86.02 |
| 45 | `no-switch-to-configuration` | 54.66 | +56.01 |
| 36 | `slim-systemd` | 37.97 | +46.01 |
| 48 | `no-duplicate-systemd` | 22.45 | +24.01 |
| 39 | `empty-hwdb` | 13.21 | +16.00 |
| 41 | `minimal-coreutils` | 12.75 | +14.00 |
| 5 | `no-installer-tools` | 12.33 | +0.00 |
| 51 | `no-user-data-decompression` | 11.40 | +8.00 |
| 65 | `no-duplicate-util-linux` | 8.72 | +6.00 |
| 14 | `no-firewall` | 7.55 | +0.00 |
| 67 | `wrappers-without-propagation` | 7.20 | +12.00 |
| 55 | `no-x11` | 6.94 | +12.00 |
| 53 | `slim-iproute2` | 6.89 | +10.00 |
| 54 | `slim-systemd-no-libbpf` | 6.64 | +8.00 |
| 60 | `no-lvm` | 5.88 | +8.00 |
| 43 | `no-sudo` | 5.82 | +8.00 |
| 56 | `no-lastlog2` | 5.80 | +8.00 |
| 72 | `xz-initrd` | 4.23 | +12.00 |
| 11 | `no-default-packages` | 3.39 | +0.00 |
| 75 | `openssh-server-only` | 3.09 | +6.00 |
| 58 | `slim-curl` | 2.84 | +0.00 |
| 49 | `no-editor` | 2.50 | +4.00 |
| 73 | `c-locale-only` | 2.46 | -6.00 |
| 74 | `no-procps` | 2.33 | +0.00 |
| 64 | `no-nscd` | 1.46 | +4.00 |
| 62 | `slim-openssh` | 1.38 | +2.00 |
| 61 | `no-bash-completion` | 1.25 | -2.00 |
| 19 | `no-lastlog` | 0.00 | +0.00 |
| 25 | `lean-image` | 0.00 | +544.14 |
| 59 | `pristine-builder-vm` | 0.00 | +2.00 |
| 68 | `lean-image-additional-space` | 0.00 | +2.00 |

39 accepted, closure 1249.87 MiB, image 1052.26 MiB

The totals do not sum to the difference between baseline and final,
because later experiments measure against a smaller system and some
savings overlap.

Six strategies account for 794 MiB of the 1250, and all six are the same
finding stated six ways: **a stock NixOS EC2 image carries the tools to
rebuild itself.** The flake registry, the nixpkgs channel, Python, Perl,
the SSM agent, `amazon-init`, `nixos-rebuild`, `switch-to-configuration`
and 57 packages on the system path are all there so the running machine
can reconfigure itself. An appliance that is replaced rather than
reconfigured needs none of them.

## 3. The floor

`FLOOR.md` lists every path over 1 MiB with the reason it stays. The
shape of what is left:

| MiB | what |
| --- | ---- |
| 52.55 | `systemd`, already built with 21 features off |
| 33.93 | `glibc` |
| 21.97 | the kernel |
| 17.64 | the initrd, xz-compressed |
| 23.55 | `util-linux`, lib and bin |
| 10.31 | `gcc-lib`, held by six unrelated packages |
| 9.00 | `openssl` |
| 5.65 | `openssh`, server programs only |
| 7.10 | `bash-interactive` |

That is the machine. What remains above 1 MiB and *could* still go is
about 20 MiB, and every piece of it needs a nixpkgs change rather than a
NixOS option: see §5.

## 4. What did not work

33 rejections, and they fall into four groups.

**The guard did its job (4).** `system.forbiddenDependenciesRegexes` is
set by each module to name what should have left. It caught #3
(`nixos-rebuild` still present), #20 and #47 (`systemd-minimal` had more
holders), #52 (`elfutils` had a third holder) and #57 (`krb5` had two
more referrers). Writing the guard for what you *hope* leaves, rather
than what you know leaves, is what makes it useful.

**The lab's own defects (6).** Wrong build phase, an unasserted string
replacement that silently matched nothing, a measurement that compared
only closures, an image that failed to build and was logged as a 100%
saving, an integer interpolated into a string, and a `mkForce` that
removed more than it meant to. Each produced a protocol change; see §6.

**Genuinely too far (5).** A trimmed kernel config derails nixpkgs'
`make config`. Dropping the module tree needs `ena`, `af_packet`, `fuse`
and `configfs` force-loaded in the initrd and the firewall off. An
auto-sized image with no slack left `growpart` nothing to grow into.

**Upstream in the way (the rest).** §5.

## 5. What belongs upstream

Four findings that a nixpkgs or NixOS change would unlock. All four are
reproducible from this repository.

1. **Setuid wrappers propagate `linuxHeaders` into the runtime closure.**
   `nixos/modules/security/wrappers/wrapper.nix` takes `linuxHeaders` as a
   `buildInputs` entry; the static stdenv writes
   `nix-support/propagated-build-inputs` into the output; the activation
   script copies the wrapper out of that package, so the file and its 7.20
   MiB of kernel headers stay. The binary itself never references them.
   One `postFixup = "rm -rf $out/nix-support"` fixes it, and this costs
   **every NixOS system with a setuid wrapper**, not just small ones.
   Ledger #67.

2. **The systemd / linux-pam / util-linux cycle forces a second
   util-linux.** nixpkgs calls systemd with `util-linux = util-linuxMinimal`
   to break it, and NixOS then writes that build into PID 1's `PATH` and
   the generator environment, so the image carries two util-linux builds.
   The lab removed the 8.72 MiB `bin` output by changing the two PATHs
   (#65); the remaining 2.47 MiB is referenced by the systemd binary and
   needs the cycle broken. Overriding the package instead is an infinite
   recursion, because `systemdMinimal` resolves `systemd` from the final
   package set.

3. **`pkgs.bash` is `bashInteractive`.** 7.10 MiB against 1.80 for
   `bashNonInteractive`, which is already in every closure as
   `runtimeShell`. Pointing `environment.binsh`, `users.defaultUserShell`,
   `environment.shells`, the system path and `amazon-ec2-utils` at the
   non-interactive build still leaves two referrers, both hardcoded:
   stage 2's `prepare-root` shebang and `networking.localCommands`.
   Backlog `e28`.

4. **`make-disk-image`'s automatic sizing cannot be tuned usefully, and
   its inode allowance is misleading.** It charges two filesystem blocks
   per inode; with 13016 files that is 101.7 MiB of a 398 MiB estimate,
   which reads like the image is mostly slack. It is not: the VHD is
   sparse, so the estimate only has to be large enough. Halving the
   allowance moved the allocated size by 64 KiB (#71), and a 1 KiB block
   size ran the bootloader step out of space (#70). Worth a comment
   upstream so the next person does not spend three experiments on it.

Two further items are blocked rather than upstream-shaped: a compressed
store (`e3`) and any non-ext4 root (`e7`) both hit
`make-disk-image`'s assertion that a partition table implies ext4.

## 6. How the lab worked, and what the method cost

The protocol is BRIEFING §8: one strategy per experiment, measured against
a frozen baseline, two gates, and a ledger line whatever the outcome. Four
changes to it came out of failures, and each one paid for itself:

1. **Referrer dumps instead of `nix why-depends`.** The old method
   recorded one holder per path, from a run without `--all`. Three of
   `FLOOR.md`'s rows had stale holders by #49. A full
   `nix path-info -r --json` dump, read as "who references this", found
   both of the largest savings of the last ten experiments, and both were
   *strings* rather than code: a PATH entry in `/etc/systemd/system.conf`
   (#65, 8.72 MiB) and a 60-byte metadata file (#67, 7.20 MiB).
   `why-depends` points at packages, which is why it missed them.

2. **The protocol refuses an unmeasured image.** `lab/measure.sh` reports
   0 for an image it could not build, which is indistinguishable from an
   image that shrank to nothing. #56 was logged as a 100% image saving
   that way. `lab/experiment.sh` now stops when either image measures 0.

3. **The image builder stopped dragging the appliance's overlays.**
   `make-disk-image` runs inside QEMU and was being handed the overlaid
   `pkgs`, so every package override rebuilt QEMU, gtk4, mesa and
   pipewire first: an hour per experiment, and #57 never finished at all.
   Its `vmTools` now comes from an unoverlaid nixpkgs (#59). Runs went
   from about an hour to about twenty minutes.

4. **Gate 2 records the boot breakdown.** The lab kept
   `systemd-analyze`'s total and threw the rest away, which is why
   backlog `e15` could not be answered from the record. Every gate 2 log
   now carries `systemd-analyze` and `systemd-analyze blame`.

The cost of the method, honestly: 33 rejections, of which 6 were the
lab's own bugs and 3 were measurement traps. Roughly a third of the
elapsed time went into rebuilds that a better-shaped image builder would
have avoided, which is why item 3 above matters more than its 2 MiB.

## 7. Boot time

It is not a function of size. Backlog `e15` tested the two obvious
hypotheses on one closure and refuted both: a 4 GiB filesystem instead of
390 MiB costs 0.14s, and putting the 604 MB nixpkgs channel back in costs
0.03s. The 34.4s to 14.3s fall at #25 was not caused by #25, and the
record cannot say what caused it.

What the boot is now:

```
1.659s kernel + 3.613s initrd + 8.868s userspace = 14.141s
5.680s dhcpcd.service
4.430s sys-devices-virtual-dmi-id.device
4.38s  ttyS0..ttyS3, configfs, nvme0n1p1
```

`dhcpcd` waiting for a lease and a handful of device units settling are
the floor. The only size/speed trade the lab found is `smol.xzInitrd`:
4.23 MiB of closure for **2.5 seconds** of boot (#72).

## 8. For the next project

The next project builds a configurable, optimised EC2 base image. What
this lab would hand it:

**Take the strategies, not the systems.** `modules/smol/*.nix` are 36
independent NixOS options, each with its measured saving and its
trade-off in its own `mkEnableOption` text. `systems/accepted` is only
one point in that space.

**The three-profile split is the right shape, and `safe` is underused.**
Today `smol.profile = "safe"` holds three strategies and `aggressive`
holds thirty. A production base image wants a middle: everything whose
trade-off is "this machine is replaced, not reconfigured" is safe for an
appliance and wrong for a machine people log into. The dividing question
for each option is not how much it saves but **who is expected to log in
and what they are expected to do there**.

**Four options need a second look before they go into production**, and
each is marked in its module:

- `smol.xzInitrd` costs 2.5s of boot. Wrong for an autoscaling group,
  free for an image deployed once.
- `smol.minimalSystemPackages` leaves 16 packages. Anything that shells
  out to a tool breaks, and that is where a configurable image needs a
  real list rather than this one.
- `smol.noNscd` drops systemd's NSS plugins; correct here because nothing
  sets `DynamicUser`, wrong the moment something does.
- `smol.noKernelModules` force-loads four modules in the initrd. Any
  hardware or filesystem beyond this one needs that list revisited.

**Keep both gates and the contract.** `lab/verify.sh` is one script run
identically by the local NixOS test and by the real instance, which is
what stopped the two from drifting. Three experiments passed gate 1 and
failed gate 2; without the second gate they would have shipped.

**Keep the ledger discipline.** Every experiment, including the failures,
has a line and a note. Most of what is useful in this report came from
the rejections.

## 9. Open questions

- The mutable track was never started. BRIEFING §3 puts it after the
  appliance track reaches its floor, and whether it is wanted at all is
  still Pim's call.
- aarch64 / Graviton is wired into the flake and never built. Nothing in
  the strategies is x86-specific, and nothing proves that.
- The last eight accepted experiments did not all fall under 1% or 2 MiB,
  so BRIEFING §9's first stop criterion was not met when the lab closed.
  It stopped because the backlog was empty and the remaining items need
  upstream changes, not because the curve flattened.
