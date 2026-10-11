{ config, lib, ... }:
let
  cfg = config.smol.noDuplicateSystemd;
in
{
  options.smol.noDuplicateSystemd.enable = lib.mkEnableOption ''
    building `util-linux` without systemd support, so the image stops
    carrying a second systemd.

    A stock image has both `systemd` at 63.02 MiB and
    `systemd-minimal-libs` at 22.26 MiB. The second one is there because
    `agetty` in `util-linux-bin` links against libsystemd, and nixpkgs builds
    that against `systemdMinimal` rather than the real systemd to avoid a
    dependency cycle: systemd needs util-linux for libmount and libblkid.

    Pointing `util-linux` at the full systemd would close that cycle and is
    not an option. Dropping the support removes the second build outright.

    Measured saving (appliance track, EC2): 22.11 MiB closure, 24.00 MiB
    raw image, ledger #48.

    Experiments #18, #20 and #47 each found another holder. `agetty` was
    only the first; `libfido2` and `dbus-lib` came through
    `switch-to-configuration` and left with it in #45, and `dbus` itself and
    `pam_timestamp_check` turned up after that.

    Requires: `smol.noLastlog`. util-linux ships its systemd units,
    tmpfiles and sysusers fragments in its `lastlog` output, and NixOS adds
    that output to `systemd.tmpfiles.packages` whenever PAM's lastlog is on.
    Without systemd support the fragment does not exist and the `etc`
    derivation fails to build.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `e5`, and siraben's warning that a slim systemd must be an
    overlay or consumers pull a second full build
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.security.pam.services.login.lastlog.enable;
        message = ''
          smol.noDuplicateSystemd builds util-linux without systemd support,
          so its lastlog output ships no tmpfiles fragment, and NixOS still
          expects one while PAM's lastlog is on. The etc derivation fails
          with "lib/tmpfiles.d: No such file or directory". Enable
          smol.noLastlog too. Found in experiment 018.
        '';
      }
    ];

    nixpkgs.overlays = [
      (final: prev: {
        util-linux = prev.util-linux.override { systemdSupport = false; };

        # dbus links libsystemd and nixpkgs builds it against systemdMinimal
        # to avoid a cycle. There is no cycle here: systemd takes `pam` as an
        # input but not `dbus`, so dbus can use the real systemd, which is
        # already in the closure.
        dbus = prev.dbus.override { systemdMinimal = final.systemd; };
      })
    ];

    # Matches systemd-minimal-261.3 and deliberately not
    # systemd-minimal-libs-261.3. That one is held by pam_timestamp_check in
    # linux-pam, and systemd takes `pam` as a build input, so pointing
    # linux-pam at the real systemd is a genuine cycle. 4.45 MiB of floor
    # with a reason, rather than a target.
    system.forbiddenDependenciesRegexes = [ "systemd-minimal-[0-9]" ];
  };
}
