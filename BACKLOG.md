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
| n8 | `system.etc.overlay` + `services.userborn` to drop Perl | part of the ISO 458 to 183 MiB | **needs-upstream**: implemented in #37 and gate 1 green, but Perl stays because `install-grub.pl` holds it. Blocked behind `s6` |

n7 needed exactly the EC2-specific work the briefing predicted, and then
some: `ena`, `af_packet`, `fuse` and `configfs` all had to be force-loaded in
the initrd. Three attempts, two of them failed EC2 deployments. See
`experiments/017-no-kernel-modules.md`.

## Phase 1: replay siraben

Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>
(183 → 91 MiB, every step boot-verified)

| # | hypothesis | reported saving | status |
| - | ---------- | --------------- | ------ |
| s1 | slim systemd as a nixpkgs overlay | large | todo |
| s2 | minimal util-linux as a nixpkgs overlay | large | todo |
| s3 | dbus without X11, reusing the slim systemd | medium | todo |
| s4 | xz compression for squashfs, initrd and kernel (`-9 -e --check=crc32`) | medium | todo |
| s5 | trim the initrd module set | medium | todo |
| s6 | `system.switch.enable = false` (appliance track only) | 13.79 MiB measured | **needs-upstream**, see below |
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
| e9 | `nix.enable = false` on the appliance track, plus the `register-nix-paths` override | unknown | todo |
| e10 | `icu4c-78.3`, 39.69 MiB; nothing known yet about what pulls it in | explained | accepted #26: it came from Nix itself |
| e11 | `grub-2.14`, 36.30 MiB. An EC2 image boots from a snapshot, so does a bootloader belong in the closure at all? | explained, **not removed** | two holders: the system path, removed by #31, and `switch-to-configuration` through `install-grub.sh` and `grub-config.xml`, which is blocked behind `s6` |

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

## needs-upstream

Items that cannot be done here, with the nixpkgs change that would unlock
each. BRIEFING §9's stop criterion 2 is satisfied by an item reaching this
list with a concrete change named.

### s6, `system.switch.enable = false`

`config.system.build.images.amazon` builds its disk image by booting a
builder VM, chrooting into the new root and running
`/nix/var/nix/profiles/system/bin/switch-to-configuration boot` to install
the bootloader. With the program gone the chroot fails and the builder VM
panics, so the AMI cannot be produced at all. Gate 1 passes, because it never
builds an image.

What would unlock it: the `system.build.images.*` builders should install the
bootloader without requiring `config.system.switch.enable`, or should use a
build-time-only `switch-to-configuration` that does not enter the runtime
closure.

**This one item is worth 127.53 MiB**, which is 24.8% of the current 515.03
MiB closure. `switch-to-configuration` is the sole remaining holder of all
of these:

| MiB   | path | item |
| ----- | ---- | ---- |
| 55.18 | `perl-5.42.3` | `n8`, through `install-grub.pl` |
| 36.30 | `grub-2.14` | `e11`, through `grub-config.xml` |
| 22.26 | `systemd-minimal-261.3` | `e5`, through `dbus-lib` and `libfido2` |
| 13.79 | `switch-to-configuration` itself | `s6` |

Each was pursued separately and each ended at the same place. The modules
are written and their gate 1 runs are green; they are not enabled in any
profile because on their own they save nothing.

### New loose ends

| # | what | why it matters |
| - | ---- | -------------- |
| e12 | find what holds `sqlite` after PAM's lastlog is off | siraben's `s8` reports sqlite leaving with lastlog; here it stays, and experiment 19 saved 3344 bytes instead |
| e13 | build systemd with `withFido2 = false` | `libfido2` is one of three holders of the duplicate `systemd-minimal`; an appliance has no security key |
| e14 | find out why `dbus` links `systemd-minimal` rather than the systemd already in the closure | the third holder, and the last one before `e5` can be retried |

Phase 2 items are seeded from BRIEFING §9. New ones come from
`nix why-depends` and `nix path-info -rS` on the largest remaining paths of
`systems/accepted`, and must be written here before they are tried.
