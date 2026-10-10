# 020: no-duplicate-systemd

Rejected, build failed on the dependency guard. Second attempt at `e5`.

With `smol.noLastlog` in place the system built, and
`system.forbiddenDependenciesRegexes = [ "systemd-minimal" ]` caught that the
duplicate was still there:

```
System closure contains the following disallowed paths:
  /nix/store/...-systemd-minimal-libs-261.3
  /nix/store/...-systemd-minimal-261.3
```

`agetty` was one of three holders. The other two are `libfido2` and
`dbus-lib`, both reached through `switch-to-configuration`.

Without the guard this would have been accepted: the system was complete and
bootable, and the measurement would have reported the `agetty` saving as a
success.

Full account, including what would unblock it:
`experiments/018-no-duplicate-systemd.md`.
