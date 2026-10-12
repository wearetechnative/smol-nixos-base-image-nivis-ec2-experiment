# 065: no-duplicate-util-linux

- **Track:** appliance
- **Contract:** 7 and 9 (`findmnt`, and `growpart` calling into fsck tooling)
- **Module:** `smol.noDuplicateUtilLinux`
- **Source:** found by lab, exp #65, from `FLOOR.md`'s referrer table

## Hypothesis

The closure carries two util-linux builds: `util-linux-2.42.3-bin` at
9.60 MiB and `util-linux-minimal-2.42.3-bin` at 8.72 MiB. nixpkgs calls
systemd with `util-linux = util-linuxMinimal` to break a cycle, and NixOS
then puts `config.systemd.package.util-linux` on PID 1's `PATH` and on
every generator's. Those two files are the minimal build's only referrers.

## The attempt that did not get a ledger line

The obvious move is to override the package:

```nix
systemd = prev.systemd.override { util-linux = final.util-linux; };
```

`nix` answers `error: infinite recursion encountered`, and it is right.
`systemdMinimal` and `systemdLibs` are defined in all-packages as
`systemd.override { ... }` against the *final* package set, so the
argument propagates into them; `linux-pam` takes `systemd-minimal-libs`;
and the full util-linux takes `linux-pam`. Pinning
`systemdMinimal = prev.systemdMinimal` does not help, for the same reason:
its definition still resolves `systemd` from the final fixpoint.

It never reached a build, so there is no ledger line for it. BRIEFING §12.

## What changed

[`modules/smol/no-duplicate-util-linux.nix`](../modules/smol/no-duplicate-util-linux.nix)
changes no package at all. It replaces the two PATHs:

```nix
systemd.generatorPath = lib.mkForce (config.system.fsPackages ++ [ pkgs.util-linux ] ++ sshd);
systemd.managerEnvironment.PATH = lib.mkForce (lib.makeBinPath (...the same...));
```

`sshd` is kept in the list because `nixos/modules/services/networking/ssh/sshd.nix`
adds it to `generatorPath` for `systemd-ssh-generator`, and `mkForce`
would otherwise drop it.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 294.42 | 285.70 | 8.72, 3.0% |
| image, raw | 418.11 | 412.11 | 6.00, 1.4% |

Exactly the `bin` output. The minimal build's other outputs stay and are
floor until the cycle above is solved: `systemd` links its `lib` at 2.07
MiB and has `sulogin`, `nologin`, `mount`, `umount`, `swapon` and
`swapoff` compiled in from its `login`, `mount` and `swap` outputs, 0.40
MiB together. Those are references from the binary, not from a PATH.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 13.55s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. The largest single saving since #48, and it changes no package:
the duplicate was reachable only through two strings in `/etc`.

## Surprises

`prev.<attr>` in an overlay is not an escape hatch from your own override.
The previous layer's *value* is what you get, but that value was computed
from definitions that reference the final set, so an argument you injected
downstream still arrives. Copied to `GOTCHAS.md`.
