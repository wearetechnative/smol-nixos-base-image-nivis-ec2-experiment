{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.smol.noDuplicateUtilLinux;

  utilLinux = [ pkgs.util-linux ];
  sshd = lib.optional config.services.openssh.enable config.services.openssh.package;
in
{
  options.smol.noDuplicateUtilLinux.enable = lib.mkEnableOption ''
    putting the util-linux this image already has on PID 1's `PATH` and on
    the generators', so the second build's `bin` output stops being
    reachable.

    The closure holds `util-linux-2.42.3-bin` at 9.60 MiB *and*
    `util-linux-minimal-2.42.3-bin` at 8.72 MiB. The minimal one has
    exactly two referrers, `etc-systemd-system.conf` and
    `systemd-generator-environment.json`, and both come from NixOS putting
    `config.systemd.package.util-linux` on a PATH. nixpkgs calls systemd
    with `util-linux = util-linuxMinimal` to break a cycle, and that
    choice leaks out through those two files.

    This replaces the two PATHs and nothing else. Overriding the systemd
    package instead is the obvious move and it does not work:
    `systemdMinimal` and `systemdLibs` are `systemd.override { ... }`
    against the final package set, so the argument propagates to them,
    `linux-pam` takes `systemd-minimal-libs`, and the full util-linux
    takes `linux-pam`. That is a real cycle and nix says so; it was tried
    before this and never reached a build, so it has no ledger line.

    The minimal build's small outputs stay: `systemd` links its `lib` at
    2.07 MiB and has `sulogin`, `mount`, `umount`, `swapon` and `swapoff`
    paths compiled in, 0.40 MiB between them. Those are references from
    the binary and need a systemd rebuild to move, which is what the cycle
    blocks.

    Measured saving (appliance track, EC2): 8.72 MiB closure, 6.00 MiB
    raw image, ledger #65.
    Trade-offs: generators and PID 1 resolve `fsck`, `mount` and friends
    through the full build. It is the same version from the same
    derivation with more features compiled in.
    Requires: nothing. Unlike the package-level version, this needs no
    cycle broken, because it changes no package.
    Source: found by lab, exp #65, from `FLOOR.md`'s referrer table
  '';

  config = lib.mkIf cfg.enable {
    systemd.generatorPath = lib.mkForce (config.system.fsPackages ++ utilLinux ++ sshd);

    systemd.managerEnvironment.PATH = lib.mkForce (
      lib.makeBinPath (config.system.fsPackages ++ utilLinux ++ sshd)
    );

    system.forbiddenDependenciesRegexes = [ "-util-linux-minimal-2[.][0-9.]*-bin" ];
  };
}
