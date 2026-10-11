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

Closure 489.07 MiB at ledger #41, from a 1516.25 MiB baseline. 63 paths are
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

### Not yet justified, therefore backlog

Under BRIEFING §9.3 these are backlog items rather than floor entries,
because "it is there" is not a reason.

| MiB   | path | what is known |
| ----- | ---- | ------------- |
| 10.54 | `file-5.48` | on `fetch-ec2-metadata.service`'s PATH, which is the service that makes contract check 1 pass. Whether it is actually called is unknown |
| 10.31 | `gcc-16.2.0-lib` | libstdc++ and libgcc. Which consumer needs C++ is unknown |
| 8.72  | `util-linux-minimal-2.42.3-bin` | a second util-linux build, like the systemd duplicate. Holder not traced |
| 7.20  | `linux-headers-static-7.2` | kernel headers in a runtime closure is suspicious |
| 5.90  | `sqlite-3.53.3` | survived `smol.noLastlog` (#19), reached through `lslogins`. Holder not fully traced |
| 5.68  | `sudo-1.9.17p2` | `security.sudo.enable` defaults on. A single-user appliance reached as root may not need it |
| 4.24  | `db-5.3.28` | Berkeley DB, two versions of it |
| 4.12  | `elfutils-0.195` | unexamined |
| 3.61  | `db-4.8.30` | the second Berkeley DB |
| 2.93  | `glibc-locales-2.44-25` | siraben's `s7` would cut this to C.UTF-8 only |

Ten unexplained paths, 63.25 MiB between them. **Stop criterion 3 is not
met**, and criterion 2 cannot be met until each of these is accepted,
rejected or marked `needs-upstream`.

## Mutable track

Not started. BRIEFING §3 puts it after the appliance track reaches its floor,
and whether it is wanted at all is still an open question for Pim.
