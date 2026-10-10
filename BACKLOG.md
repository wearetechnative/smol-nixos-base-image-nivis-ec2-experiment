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
| n3 | `nix.enable = false`, plus overriding `register-nix-paths` | part of 458 → 183 MiB | todo |
| n4 | `programs.ssh` option stub + `disabledModules` on `programs/ssh.nix` | part of 458 → 183 MiB | todo |
| n5 | trim `environment.systemPackages` to what the contract needs | part of 458 → 183 MiB | todo |
| n6 | trim `system.extraDependencies` | part of 458 → 183 MiB | todo |
| n7 | remove `$out/kernel-modules` from the system closure | part of 458 → 183 MiB | todo |
| n8 | `system.etc.overlay` + `services.userborn` to drop Perl | part of 458 → 183 MiB | todo |

n7 is expected to need EC2-specific work: ENA and NVMe must move into the
initrd or the kernel first (GOTCHAS.md).

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
| s6 | `system.switch.enable = false` (appliance track only) | medium | todo |
| s7 | C.UTF-8 only, no locale archive | medium | todo |
| s8 | lastlog off, which drops sqlite | small | todo |
| s9 | empty hwdb | small | todo |

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
| e1 | custom Nitro kernel config: ENA and NVMe built in, unused subsystems off | up to 145.17 MiB | in progress, exp #012 |
| e2 | networkd instead of dhcpcd | unknown | todo |
| e3 | erofs or squashfs compressed store | unknown | todo |
| e4 | dropbear instead of openssh | unknown | todo |
| e5 | remove remaining duplicate util-linux and systemd builds | unknown | todo |
| e6 | image compression at AMI registration time | unknown | todo |
| e7 | filesystem choice for the root volume | unknown | todo |
| e8 | drop every Python script, so CPython leaves the image | 136.55 MiB | accepted #9, 136.87 MiB |
| e9 | `nix.enable = false` on the appliance track, plus the `register-nix-paths` override | unknown | todo |
| e10 | `icu4c-78.3`, 39.69 MiB; nothing known yet about what pulls it in | unknown | todo |
| e11 | `grub-2.14`, 36.30 MiB. An EC2 image boots from a snapshot, so does a bootloader belong in the closure at all? | unknown | todo |

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

Phase 2 items are seeded from BRIEFING §9. New ones come from
`nix why-depends` and `nix path-info -rS` on the largest remaining paths of
`systems/accepted`, and must be written here before they are tried.
