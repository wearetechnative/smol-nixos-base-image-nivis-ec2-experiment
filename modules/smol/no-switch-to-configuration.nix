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

    Measured saving (appliance track, EC2): 54.65 MiB closure, 56.00 MiB raw
    image, ledger #45. GRUB, `systemd-minimal` and `btrfs-progs` leave
    together. Perl leaves too once `smol.noPerl` is on, which it could not
    be before this.

    This was `needs-upstream` after experiment 21 and is not any more.
    `smol.leanImage` owns the `make-disk-image` call, so the bootloader step
    is patched to bind-mount the builder's store over the image's store for
    the duration of the install. The installer becomes reachable inside the
    chroot without anything being copied into the image.

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
