# 047 and 048: no-duplicate-systemd

Accepted at #48, after experiments 18, 20 and 47 each found another holder.

- **Module:** `smol.noDuplicateSystemd`
- **Source:** siraben, backlog item `e5`

## The hunt, in full

`systemd-minimal` is a second systemd build that nixpkgs uses to avoid
dependency cycles. Removing it took four experiments because it had five
holders, found one at a time:

| holder | reached through | removed by |
| ------ | --------------- | ---------- |
| `agetty` | `util-linux-bin` | `systemdSupport = false` on util-linux, #18 |
| `libfido2` | `switch-to-configuration` -> `systemd` | #45 |
| `dbus-lib` | `switch-to-configuration` | #45 |
| `dbus` | its own user socket unit | this experiment |
| `pam_timestamp_check` | `linux-pam` | **not removed, see below** |

## What changed

util-linux without systemd support, plus:

```nix
dbus = prev.dbus.override { systemdMinimal = final.systemd; };
```

nixpkgs builds dbus against `systemdMinimal` to avoid a cycle. There is no
cycle: systemd takes `pam` as a build input but not `dbus`, so dbus can use
the real systemd, which is already in the closure.

`linux-pam` cannot have the same treatment. systemd depends on pam, so
pointing pam at the real systemd is a genuine cycle. `systemd-minimal-libs`
at 4.45 MiB stays, and it is floor with a reason rather than a target.

## Numbers

| measure      | before      | after       | delta        |
| ------------ | ----------- | ----------- | ------------ |
| closure, MiB | 386.38      | 364.27      | 22.11, 6.1%  |
| image, MiB   | 506.13      | 482.13      | 24.00, 4.7%  |

## Cost

The dbus override rebuilt QEMU and its GUI dependencies, because
`make-disk-image` builds the image inside a QEMU VM. Roughly an hour of
compilation for 22 MiB. That is siraben's warning about overlays made
concrete: the saving is permanent, the rebuild is one-off, and without a
binary cache it is not free.

## Experiment 47

Rejected, build failed on the dependency guard, which caught `dbus` and
`pam_timestamp_check` still holding `systemd-minimal` after the two
`switch-to-configuration` holders had gone. The guard has now caught an
incomplete removal four times in this lab.

## Gates

Both pass at #48. Boot time 14.134s. Teardown complete.
