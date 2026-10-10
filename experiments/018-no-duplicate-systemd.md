# 018 and 020: no-duplicate-systemd

Two ledger lines, one story. Both rejected.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noDuplicateSystemd`
- **Source:** siraben, backlog item `e5`

## Hypothesis

The image carries two systemds: `systemd` at 63.02 MiB and
`systemd-minimal-libs` at 22.26 MiB. `nix why-depends` put the second behind
`agetty`:

```
nixos-system
└── activate: ... util-linux-2.42.3-bin
    └── bin/agetty: ...systemd-minimal-libs-261.3/lib
```

nixpkgs builds util-linux against `systemdMinimal` rather than the real
systemd to avoid a cycle: systemd needs util-linux for libmount and libblkid.
Building util-linux without systemd support at all should remove the second
copy.

## What changed

```nix
util-linux = prev.util-linux.override { systemdSupport = false; };
system.forbiddenDependenciesRegexes = [ "systemd-minimal" ];
```

## Experiment 018: rejected, build failed

```
/nix/store/...-util-linux-2.42.3-lastlog/lib/tmpfiles.d: No such file or directory
```

util-linux ships its systemd units, tmpfiles and sysusers fragments in its
`lastlog` output, and `security/pam.nix` adds that output to
`systemd.tmpfiles.packages` whenever PAM's lastlog is on. Without systemd
support the fragment does not exist.

Split off as `smol.noLastlog`, experiment 019, which is siraben's `s8` and
was going to be needed anyway.

## Experiment 020: rejected, build failed on the guard

With lastlog gone the system built, and the dependency guard caught that the
job was not done:

```
System closure contains the following disallowed paths:
  /nix/store/...-systemd-minimal-libs-261.3
  /nix/store/...-systemd-minimal-261.3
```

`agetty` was one of three holders. The other two:

| holder | path |
| ------ | ---- |
| `libfido2` | `switch-to-configuration` -> `systemd` -> `libsystemd-shared.so` -> `libfido2` -> `systemd-minimal-libs` |
| `dbus-lib` | `switch-to-configuration` -> `dbus-1.16.2-lib` -> `systemd-minimal` |

Both reach the closure through `switch-to-configuration`, which the appliance
track has no use for. That became experiment 021.

## Decision

**Rejected twice, and now blocked.** Experiment 021 showed that
`switch-to-configuration` cannot be removed either, because the amazon image
builder calls it, so `e5` is waiting on an upstream change.

The remaining route, for whoever picks this up:

1. Build systemd with `withFido2 = false`. An appliance has no security key.
   That removes the `libfido2` holder without touching
   `switch-to-configuration`.
2. Work out why `dbus` links `systemd-minimal` rather than the systemd
   already in the closure, and whether `dbus.override` can be pointed at the
   latter without creating a cycle.

Both belong in a `smol.slimSystemd` strategy rather than here.

## Surprises

Third time in this lab that a large path turned out to have several holders,
after CPython with four and perl with at least two. The pattern is now
reliable enough to plan around: **before writing a module to remove a large
path, list every holder first**, with `nix why-depends` run once per holder
rather than once per path. Experiment 018 would never have been written that
way.

The dependency guard paid for itself again. Experiment 020 built a complete,
bootable system that still contained both systemds; without the guard the
measurement would have shown a 22 MiB saving from `agetty` alone and the
experiment would have been accepted as a success.
