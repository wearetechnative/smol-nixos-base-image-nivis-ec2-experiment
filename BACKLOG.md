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
| n1 | `documentation.enable = false` | part of 458 → 183 MiB | todo |
| n2 | `environment.defaultPackages = [ ]` | part of 458 → 183 MiB | todo |
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

## Phase 2: explore (BRIEFING §9)

| # | hypothesis | expected saving | status |
| - | ---------- | --------------- | ------ |
| e1 | custom Nitro kernel config: ENA and NVMe built in, no loadable modules | unknown, likely large | todo |
| e2 | networkd instead of dhcpcd | unknown | todo |
| e3 | erofs or squashfs compressed store | unknown | todo |
| e4 | dropbear instead of openssh | unknown | todo |
| e5 | remove remaining duplicate util-linux and systemd builds | unknown | todo |
| e6 | image compression at AMI registration time | unknown | todo |
| e7 | filesystem choice for the root volume | unknown | todo |

Phase 2 items are seeded from BRIEFING §9. New ones come from
`nix why-depends` and `nix path-info -rS` on the largest remaining paths of
`systems/accepted`, and must be written here before they are tried.
