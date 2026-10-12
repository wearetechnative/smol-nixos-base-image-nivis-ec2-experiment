# BACKLOG

Hypotheses not yet tried, each with its source and the saving its source
reports. One line becomes one experiment, one branch, one ledger entry.

Statuses: `todo`, `accepted #<ledger id>`, `rejected: <reason>`,
`needs-upstream: <what nixpkgs change would unlock it>`.

Every item must end up in one of those four states before stop criterion 2
(BRIEFING §9) is met.

## Phase 1: replay natkr

Source: <https://natkr.com/2026-06-19-nixos-but-smol/> (ISO 458 → 183 MiB)

| # | hypothesis | reported saving | status |
| - | ---------- | --------------- | ------ |
| n1 | `documentation.enable = false` | part of the ISO 458 to 183 MiB | accepted #10, 93.87 MiB |
| n2 | `environment.defaultPackages = [ ]` | part of the ISO 458 to 183 MiB | accepted #11, only 3.39 MiB |
| n3 | `nix.enable = false`, plus overriding `register-nix-paths` | part of the ISO 458 to 183 MiB | accepted #26, 87.54 MiB; `register-nix-paths` needed no override once the registry was gone |
| n4 | `programs.ssh` option stub + `disabledModules` on `programs/ssh.nix` | part of 458 → 183 MiB | todo |
| n5 | trim `environment.systemPackages` to what the contract needs | part of the ISO 458 to 183 MiB | accepted #31, 57.32 MiB; 57 packages down to 16 |
| n6 | trim `system.extraDependencies` | part of 458 → 183 MiB | todo |
| n7 | remove `$out/kernel-modules` from the system closure | part of the ISO 458 to 183 MiB | accepted #17, 152.93 MiB, after three attempts |
| n8 | `system.etc.overlay` + `services.userborn` to drop Perl | part of the ISO 458 to 183 MiB | accepted #46, 58.00 MiB; saved nothing in #37 until `s6` landed |

n7 needed exactly the EC2-specific work the briefing predicted, and then
some: `ena`, `af_packet`, `fuse` and `configfs` all had to be force-loaded in
the initrd. Three attempts, two of them failed EC2 deployments. See
`experiments/017-no-kernel-modules.md`.

## Phase 1: replay siraben

Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>
(183 → 91 MiB, every step boot-verified)

| # | hypothesis | reported saving | status |
| - | ---------- | --------------- | ------ |
| s1 | slim systemd as a nixpkgs overlay | large | accepted #36, 38.24 MiB; 20 features off |
| s2 | minimal util-linux as a nixpkgs overlay | large | todo |
| s3 | dbus without X11, reusing the slim systemd | medium | todo |
| s4 | xz compression for squashfs, initrd and kernel (`-9 -e --check=crc32`) | medium | todo, now the only initrd lever left |
| s5 | trim the initrd module set | medium | rejected #42: the modules are 2.7 MiB of a 24.77 MiB initrd, and gate 1 needs the virtio and 9p ones |
| s6 | `system.switch.enable = false` (appliance track only) | 13.79 MiB predicted | accepted #45, 54.65 MiB, after patching the image builder |
| s7 | C.UTF-8 only, no locale archive | medium | low value here: `glibc-locales` is 2.93 MiB after `n5`, todo |
| s8 | lastlog off, which drops sqlite | small | accepted #19, but only 3344 bytes: sqlite stays |
| s9 | empty hwdb | small | accepted #39, 13.21 MiB |

## Platform defaults, found by auditing the baseline

Not on either prior-art list: an ISO has no platform to configure. Together
these were 421 MiB of the 1516 MiB baseline, and they were the first quarter
of the lab's savings.

| # | hypothesis | measured | status |
| - | ---------- | -------- | ------ |
| p1 | drop the system flake registry, which pins the nixpkgs source | 199.75 MiB | accepted #2 |
| p2 | drop `virtualisation.amazon-init`, which puts `nixos-rebuild` on a service PATH | 101.10 MiB | accepted #4 |
| p3 | drop the installer tools, once p2 has removed the other reference | 12.34 MiB | accepted #5 |
| p4 | drop the AWS Systems Manager agent | 110.33 MiB | accepted #6 |

## Phase 2: explore (BRIEFING §9)

| # | hypothesis | expected saving | status |
| - | ---------- | --------------- | ------ |
| e1 | custom Nitro kernel config: ENA and NVMe built in, unused subsystems off | the module tree is already gone via n7; what is left is the 21.97 MiB bzImage and the 28.52 MiB initrd | rejected #12, kconfig dialogue derails; revisit with a different technique |
| e2 | networkd instead of dhcpcd | unknown | todo |
| e3 | erofs or squashfs compressed store | unknown | todo |
| e4 | dropbear instead of openssh | unknown | todo |
| e5 | remove the duplicate systemd builds | 22.26 MiB | rejected #18 and #20, blocked behind s6; a different route is written up in experiments/018 |
| e6 | image compression at AMI registration time | unknown | todo |
| e15 | why boot time fell from 36.4s to 14.3s when the channel left the image | not a size item, but the largest unexplained effect in the lab | todo |
| e16 | read the rest of `make-disk-image.nix` for other defaults nothing overrides, now that `copyChannel` turned up 544 MiB | unknown | todo |
| e7 | filesystem choice for the root volume | unknown | todo |
| e8 | drop every Python script, so CPython leaves the image | 136.55 MiB | accepted #9, 136.87 MiB |
| e9 | `nix.enable = false` on the appliance track | duplicate of `n3` | accepted #26, 87.54 MiB |
| e10 | `icu4c-78.3`, 39.69 MiB; nothing known yet about what pulls it in | explained | accepted #26: it came from Nix itself |
| e11 | `grub-2.14`, 36.30 MiB | removed | two holders: the system path (#31) and `switch-to-configuration` (#45) |

`n8`, `system.etc.overlay` plus `services.userborn`, is now the priority
among the natkr items: `perl-5.42.3` is 55.18 MiB and the third largest path
left, and experiment 011 showed that taking it out of `defaultPackages` does
not shift it.

Item `e8` was the clearest example of BRIEFING §2's warning that our floor
sits above the published ISO numbers, and it is now settled: the interpreter
was held by four separate consumers, two of them EC2-specific, and it took
experiments 5, 7, 8 and 9 to get rid of it. `e10` and `e11` are the two
largest remaining paths with no explanation at all, which under BRIEFING §9.3
makes them backlog items rather than floor entries.

## Found by reading the image builder

The closure is not the image. These came from reading
`nixos/lib/make-disk-image.nix` rather than from `nix why-depends`, and none
of them are visible in a closure measurement.

| # | hypothesis | measured | status |
| - | ---------- | -------- | ------ |
| i1 | `copyChannel = false`: the image ships a full nixpkgs source tree as a nix channel | part of 544.14 MiB | accepted #25 |
| i2 | `diskSize = "auto"` with the root volume sized at launch instead | part of 544.14 MiB | accepted #25 |
| i3 | `configFile = null`: the image carries a `configuration.nix` nothing can rebuild from | part of 544.14 MiB | accepted #25 |

## Solved by patching the image builder, not by waiting for upstream

### s6, `system.switch.enable = false`

**Was `needs-upstream`. It is not any more.**

`config.system.build.images.amazon` installs the bootloader by chrooting
into the new root and running `switch-to-configuration`, so an image could
only be built from a system that carried it. Four separate experiments, 18,
20, 21 and 37, each ended at that one program.

`smol.leanImage` owns the `make-disk-image` call, so the fix was ours. The
builder VM has the full build closure at `/nix/store`, a superset of what
the image contains, so bind-mounting it over the image's store for the
duration of the bootloader step makes the installer reachable inside the
chroot without copying anything into the image.

| # | item | measured |
| - | ---- | -------- |
| 45 | `s6` itself, taking GRUB, `systemd-minimal`'s other holders and `btrfs-progs` | 54.65 MiB |
| 46 | `n8`, perl, the same module that saved nothing in #37 | 58.00 MiB |

112.65 MiB between them, against the 127.53 MiB the four experiments had
predicted.

**Still worth proposing upstream**, because every NixOS EC2 image pays this
cost: `make-disk-image` should install the bootloader without requiring
`config.system.switch.enable` in the runtime closure. It is no longer a
blocker here, so it belongs in `REPORT.md`'s recommendations rather than on
this list.

### New loose ends

| # | what | why it matters |
| - | ---- | -------------- |
| e12 | ~~find what holds `sqlite` after PAM's lastlog is off~~ | answered in #56: the util-linux build, not PAM. `withLastlog = false` removed it |
| e13 | ~~build systemd with `withFido2 = false`~~ | done in #36; `libfido2` came back through openssh, which is `e20` |
| e14 | ~~find out why `dbus` links `systemd-minimal`~~ | answered in #48: nixpkgs builds it against `systemdMinimal` to avoid a cycle that does not exist here |
| e22 | ~~make the protocol distinguish an image it could not build from an image of size zero~~ | done the same day: `lab/experiment.sh` now stops when either image measures 0, which is what experiment 56 needed |
| e23 | build `curl` without GSSAPI and without IDN | `krb5-1.22.2-lib` at 2.80 MiB and `libunistring` at 1.99 MiB are referenced by curl alone, and nothing here authenticates to Kerberos or resolves an internationalised name |
| e24 | `services.lvm.enable = false` | `lvm2-2.03.41-bin` at 2.61 MiB is referenced by `system-units` and `tmpfiles.d`; the root filesystem is a plain partition |
| e25 | `programs.bash.completion.enable = false` | `bash-completion-2.18.0` at 1.21 MiB is referenced by `etc-bashrc` |
| e26 | build `openssh` with `withFIDO = false` | `libfido2-1.17.0` at 1.15 MiB; the lab authenticates with a plain ed25519 key |
| e27 | find whether `nsncd` can go | 1.46 MiB on `nscd.service`. NixOS runs it as the NSS cache and contract check 4 is `getent`, so this needs gate 1 to answer rather than a guess |

Phase 2 items are seeded from BRIEFING §9. New ones come from
`nix why-depends` and `nix path-info -rS` on the largest remaining paths of
`systems/accepted`, and must be written here before they are tried.
