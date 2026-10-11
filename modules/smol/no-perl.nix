{ config, lib, ... }:
let
  cfg = config.smol.noPerl;
in
{
  options.smol.noPerl.enable = lib.mkEnableOption ''
    replacing the two activation scripts that are written in Perl.
    `setup-etc.pl` builds `/etc` on every boot and `update-users-groups.pl`
    reconciles users and groups; between them they are the reason a stock
    NixOS carries a 55.18 MiB Perl.

    `system.etc.overlay` mounts `/etc` as an overlay instead of populating
    it with a script, and `services.userborn` does users and groups in a
    small C program.

    Measured saving (appliance track, EC2): **none, blocked upstream**.
    Ledger #37 measured 0.05% *more* closure and 2 MiB less image, and
    gate 1 passed. Perl does not leave: `install-grub.pl` is Perl too, and
    `switch-to-configuration` holds it. That is the same `needs-upstream`
    item as `e5` and `e11`, recorded in BACKLOG.md as `s6`.
    Not enabled in any profile, because on its own it costs a little and
    saves nothing. It is kept so that the day `s6` is unblocked, the perl
    removal is one toggle rather than a rediscovery.

    Trade-offs: `/etc` becomes an overlay mount, which is what the appliance
    track wants anyway, and users are created by userborn rather than the
    legacy script. Both are supported NixOS paths rather than hacks.
    Requires: systemd in the initrd, which `system.etc.overlay` needs and
    which this image already has.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item `n8`
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = ''
          system.etc.overlay requires systemd in the initrd. Set
          boot.initrd.systemd.enable = true or disable smol.noPerl.
        '';
      }
    ];

    system.etc.overlay.enable = true;
    services.userborn.enable = true;
  };
}
