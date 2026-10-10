{ config, lib, ... }:
let
  cfg = config.smol.noSwitchToConfiguration;
in
{
  options.smol.noSwitchToConfiguration.enable = lib.mkEnableOption ''
    removing `switch-to-configuration` through `system.switch.enable =
    false`. It is the program that activates a new system generation in
    place, which is precisely the thing the appliance track does not do:
    updates replace the AMI.

    It is also a surprisingly expensive thing to keep. It links dbus, and
    through the systemd it is built against it reaches `libfido2`, and both
    of those drag a second systemd build back into the closure. Experiments
    18 and 20 could not remove that duplicate while this was present.

    Measured saving (appliance track, EC2): **blocked upstream**, not
    accepted. 19.56 MiB measured and gate 1 green, but the image cannot be
    built: `system.build.images.amazon` runs
    `/nix/var/nix/profiles/system/bin/switch-to-configuration` inside a
    chroot to install the bootloader, and panics without it. See ledger #21
    and `experiments/021-no-switch-to-configuration.md`.
    Trade-offs: the system cannot be switched to another generation at all,
    including rolling back to the previous one from the bootloader menu
    entry. On the appliance track that is already true in spirit; this makes
    it true in fact.
    Requires: the appliance track. Asserts against `smol.track = "mutable"`.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `s6`
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.smol.track == "appliance";
        message = ''
          smol.noSwitchToConfiguration removes the program that activates a
          new generation, which the mutable track needs for contract
          check 6. Set smol.track = "appliance" or disable this option.
        '';
      }
    ];

    system.switch.enable = false;
  };
}
