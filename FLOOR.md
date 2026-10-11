# FLOOR

Every store path larger than 1 MiB in `systems/accepted`, with a one-line
reason it cannot go (BRIEFING §9.3).

A path listed here without a convincing reason is not a floor entry, it is a
`BACKLOG.md` item. Stop criterion 2 is not met while any such path exists,
and several below are honestly marked as backlog rather than floor.

Regenerate the raw list with:

```sh
just measure accepted | jq -r '.top_paths[] | "\(.bytes)\t\(.path)"'
```

## Appliance track

Closure 483.26 MiB at ledger #43, from a 1516.25 MiB baseline. 63 paths are
over 1 MiB; the 30 largest are listed, which is 374 MiB of the 489.

### Blocked behind one upstream change, not floor

`switch-to-configuration` is the sole remaining holder of all four. It
cannot be removed because `system.build.images.amazon` calls it to install
the bootloader. This is the lab's single `needs-upstream` item and it is
worth **127.53 MiB, 26% of the closure**.

| MiB   | path | held through |
| ----- | ---- | ------------ |
| 55.18 | `perl-5.42.3` | `install-grub.pl` |
| 36.30 | `grub-2.14` | `grub-config.xml` |
| 22.26 | `systemd-minimal-261.3` | `dbus-lib` and `libfido2` |
| 6.62  | `btrfs-progs-7.1` | `install-grub.pl` |
| 4.45  | `systemd-minimal-libs-261.3` | `agetty` in `util-linux-bin` |
| 3.64  | `perl-5.42.3-man` | with perl |

### Genuine floor

| MiB   | path | why it stays |
| ----- | ---- | ------------ |
| 52.04 | `systemd-261.3` | already built with 20 features off (#36). It is PID 1, journald, logind, udev and timesyncd, and contract checks 2, 3 and 6 are about things it does |
| 33.93 | `glibc-2.44-25` | the C library |
| 24.77 | `initrd-linux-6.18.55` | the initrd must carry a systemd userland, because `smol.noKernelModules` force-loads `ena`, `af_packet`, `fuse` and `configfs` there |
| 21.97 | `linux-6.18.55` | the kernel image. A trimmed config was tried in #12 and derails nixpkgs' `make config` dialogue |
| 13.98 | `util-linux-2.42.3-lib` | libmount, libblkid and libuuid, which systemd links |
| 9.61  | `util-linux-2.42.3-bin` | `findmnt` is contract check 7, `agetty` is the console |
| 9.00  | `openssl-3.5.8` | sshd and the TLS trust that contract check 5 exercises |
| 8.78  | `openssh-10.5p1` | the only way in. The whole contract runs over it |
| 7.10  | `bash-interactive-5.3p15` | the login shell, and `lab/verify.sh` is `sh` |
| 4.85  | `e2fsprogs-1.47.4` | `fsck` at boot and `resize2fs` for `growpart`, which is contract check 9 |
| 4.44  | `shadow-4.20.2` | `login` and the PAM stack SSH sessions go through |
| 4.36  | `iproute2-7.1.0` | `ip`, used by the DHCP path |
| 3.70  | `ncurses-6.6` | terminfo for an interactive SSH session |
| 3.43  | `gawk-5.4.1` | `lab/verify.sh` uses `awk` in checks 3 and 9 |

### Traced, with a decision still owed

`nix why-depends` run on each, 2026-10-11. Knowing the holder is not the
same as having a reason to keep it, so these stay out of the floor until
each is accepted, rejected or marked `needs-upstream`.

| MiB   | path | holder | verdict |
| ----- | ---- | ------ | ------- |
| 10.54 | `file-5.48` | on `fetch-ec2-metadata.service`'s PATH | that service makes contract check 1 pass; whether it calls `file` is still unknown |
| 10.31 | `gcc-16.2.0-lib` | `perl-5.42.3-env` | leaves with perl, so blocked behind `s6` |
| 8.72  | `util-linux-minimal-2.42.3-bin` | `systemd-generator-environment.json` | a second util-linux build, like the systemd duplicate. Not yet attacked |
| 7.20  | `linux-headers-static-7.2` | `suid-sgid-wrappers.service` | the wrapper builder. `security.wrappers` must stay: pam_unix needs `unix_chkpwd` or login loops |
| 5.90  | `sqlite-3.53.3` | `lslogins` in `util-linux-bin` | survived `smol.noLastlog` (#19). Needs util-linux built without it |
| 4.24  | `db-5.3.28` | `arpd` in `iproute2` | iproute2 is kept for `ip`; `arpd` is not used |
| 4.12  | `elfutils-0.195` | not traced | |
| 3.61  | `db-4.8.30` | not traced | the second Berkeley DB |
| 2.93  | `glibc-locales-2.44-25` | locale support | siraben's `s7` would cut this to C.UTF-8 only |

57.57 MiB across nine paths, after `sudo` was removed in experiment #43.
One is blocked upstream, two are untraced and the rest have a holder but no
decision. **Stop criteria 2 and 3 are both not met**, and this table is the
reason.

## Mutable track

Not started. BRIEFING §3 puts it after the appliance track reaches its floor,
and whether it is wanted at all is still an open question for Pim.
