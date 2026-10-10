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

    Measured saving (appliance track, EC2): not yet accepted. Experiments
    #18 and #20 both failed. Removing `agetty`'s reference is not enough:
    `libfido2` and `dbus-lib` each hold a copy too, and both reach the
    closure through `switch-to-configuration`. Retry after
    `smol.noSwitchToConfiguration`.
    Trade-offs: `agetty` no longer talks to systemd, and util-linux stops
    shipping its own systemd units, tmpfiles and sysusers fragments. On a
    machine reached over SSH rather than a console that is cheap, but it is
    the kind of change whose breakage shows up as a failed unit rather than
    an error, which is what the contract's check 3 is for.
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
      })
    ];

    system.forbiddenDependenciesRegexes = [ "systemd-minimal" ];
  };
}
