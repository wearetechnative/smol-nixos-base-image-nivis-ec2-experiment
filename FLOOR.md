# FLOOR

Every store path larger than 1 MiB in `systems/accepted`, with a one-line
reason it cannot go (BRIEFING §9.3).

A path listed here without a convincing reason is not a floor entry, it is a
`BACKLOG.md` item. Stop criterion 2 is not met while any such path exists,
and several below are honestly marked as backlog rather than floor.

Sizes are MiB, bytes divided by 1048576. Through ledger #48 the closure
totals in this file were bytes divided by 1000000 and labelled MiB; the
per-path sizes were always correct. Regenerate the raw list with:

```sh
nix path-info -r --json --json-format 1 \
  "$(nix eval --raw .#nixosConfigurations.accepted-x86_64-linux.config.system.build.toplevel.outPath)"
```

`just measure` reports only the 20 largest, which is no longer the whole
list of paths over 1 MiB.

## Appliance track

Closure 304.39 MiB at ledger #58, from a 1516.25 MiB baseline, 79.9% off.
38 paths are over 1 MiB.

### Genuine floor

| MiB   | path | why it stays |
| ----- | ---- | ------------ |
| 52.04 | `systemd-261.3` | already built with 20 features off (#36). It is PID 1, journald, logind, udev and timesyncd, and contract checks 2, 3 and 6 are about things it does |
| 33.93 | `glibc-2.44-25` | the C library |
| 24.77 | `initrd-linux-6.18.55` | the initrd must carry a systemd userland, because `smol.noKernelModules` force-loads `ena`, `af_packet`, `fuse` and `configfs` there |
| 21.97 | `linux-6.18.55` | the kernel image. A trimmed config was tried in #12 and derails nixpkgs' `make config` dialogue |
| 13.98 | `util-linux-2.42.3-lib` | libmount, libblkid and libuuid, which systemd links |
| 9.60  | `util-linux-2.42.3-bin` | `findmnt` is contract check 7, `agetty` is the console |
| 9.00  | `openssl-3.5.8` | sshd and the TLS trust that contract check 5 exercises |
| 8.78  | `openssh-10.5p1` | the only way in. The whole contract runs over it |
| 7.10  | `bash-interactive-5.3p15` | the login shell, and `lab/verify.sh` is `sh` |
| 4.85  | `e2fsprogs-1.47.4` | `fsck` at boot and `resize2fs` for `growpart`, which is contract check 9 |
| 4.45  | `systemd-minimal-libs-261.3` | `pam_timestamp_check` in linux-pam. systemd takes `pam` as a build input, so pointing pam at the real systemd is a cycle |
| 4.44  | `shadow-4.20.2` | `login` and the PAM stack SSH sessions go through |
| 3.70  | `ncurses-6.6` | terminfo for an interactive SSH session |
| 3.43  | `gawk-5.4.1` | `lab/verify.sh` uses `awk` in checks 3 and 9 |
| 2.71  | `kbd-2.9.0` | `console.enable = false` does not remove it: `systemd-261.3` references it directly, for `systemd-vconsole-setup` |
| 2.03  | `tzdata-2026d` | referenced by `libcap` and by six units. Contract check 6 is about the clock |
| 1.87  | `linux-pam-1.7.2` | sshd and `login` both authenticate through it |
| 1.80  | `bash-5.3p15` | `/bin/sh`, and every unit script's shebang |
| 1.67  | `coreutils-9.11` | on the default path of every systemd service, as #50 demonstrated the hard way |

### Traced, with a decision still owed

Direct referrers, not `nix why-depends` chains, taken from the same
`path-info` dump on 2026-10-12. A path with several referrers needs all of
them gone, which is what experiments 18 through 48 kept re-learning.

| MiB   | path | referrers | next move |
| ----- | ---- | --------- | --------- |
| 10.31 | `gcc-16.2.0-lib` | `db-4.8`, `db-5.3`, `gmp`, `gptfdisk`, `make-initrd-ng`, `nixos-init`, `nsncd` | seven referrers, so it follows the others rather than leading |
| 8.72  | `util-linux-minimal-2.42.3-bin` | `etc-systemd-system.conf`, `lvm2-scripts`, `systemd-generator-environment.json` | a second util-linux build. The `lvm2` referrer goes with `services.lvm.enable = false` |
| 7.20  | `linux-headers-static-7.2` | every `security-wrapper-*` | `security.wrappers` must stay: pam_unix needs `unix_chkpwd` or login loops. The seven wrappers that are not `unix_chkpwd`, `mount` or `umount` could go, but the derivation stays either way |
| 4.36  | `iproute2-7.1.0` | `ip` on the DHCP path | floor since #53, which cut the four packages it dragged behind it |
| 3.61  | `db-4.8.30` | `linux-pam` | pam's own Berkeley DB backend |
| 2.93  | `glibc-2.44-25-bin` | activation script, `shadow`, `system-path` | `smol.minimalSystemPackages` puts `glibc` on the path for `getent` |
| 2.93  | `glibc-locales-2.44-25` | locale support | siraben's `s7` would cut this to C.UTF-8 only |
| 2.61  | `lvm2-2.03.41-bin` | `system-units`, `tmpfiles.d` | `services.lvm.enable = false`. The root filesystem is a plain partition |
| 2.32  | `procps-4.0.7` | `system-path` | on the minimal package list. `ps` is a debugging convenience, not a contract check |
| 2.12  | `libcap-2.78` | systemd | floor, pending a check that nothing else holds it |
| 2.07  | `util-linux-minimal-2.42.3-lib` | the minimal bin above | follows it |
| 2.02  | `pcre2-10.48` | `gnugrep` | `grep -P`. Contract checks use plain patterns |
| 1.99  | `libunistring-1.4.2` | `libidn2`, which **glibc** references for IDN in `getaddrinfo` | floor. #58 proved it is not curl's: it stays with curl's `idnSupport` off |
| 1.46  | `nsncd-1.5.3` | `nscd.service` | NixOS runs nsncd as its NSS cache. Whether `getent` (contract check 4) still works without it is untested |
| 1.46  | `libxml2-2.15.4` | `libarchive` | and libarchive is held by systemd |
| 1.42  | `e2fsprogs-1.47.4-bin` | the e2fsprogs above | follows it |
| 1.26  | `curl-8.22.0` | `fetch-ec2-metadata.service` | contract check 1 depends on it |
| 1.21  | `bash-completion-2.18.0` | `etc-bashrc` | `programs.bash.completion.enable = false` |
| 1.15  | `zstd-1.5.7` | systemd, for compressed journals | floor |
| 1.15  | `libfido2-1.17.0` | `openssh` | hardware security keys. The lab authenticates with a plain ed25519 key |
| 1.08  | `make-initrd-ng-0.1.0` | the initrd build | floor |

`db-5.3.28`, `iptables-lib`, `libbpf` and `elfutils` left in #53 and #54,
12.72 MiB between them. `xauth` and its five `libX*`, plus `fontconfig`, left in #55. Roughly 33
MiB sits in rows that still have a named next move. **Stop criteria 2
and 3 are both not met**, and this table is the reason.

## Mutable track

Not started. BRIEFING §3 puts it after the appliance track reaches its floor,
and whether it is wanted at all is still an open question for Pim.
