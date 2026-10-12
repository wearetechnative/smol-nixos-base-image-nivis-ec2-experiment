{ config, lib, ... }:
let
  cfg = config.smol.noLvm;
in
{
  options.smol.noLvm.enable = lib.mkEnableOption ''
    turning off LVM2.

    `services.lvm.enable` defaults to true in NixOS, and it puts
    `lvm2-2.03.41-bin` at 2.61 MiB in the closure through `system-units`
    and a tmpfiles fragment, plus the device-mapper udev rules. It also
    pulls `util-linux-minimal-2.42.3-bin` with it, which is a second
    util-linux build.

    This image's root filesystem is a plain ext4 partition on a single EBS
    volume, created by `make-disk-image` with `partitionTableType =
    "legacy+gpt"`. There is no physical volume, no volume group and no
    logical volume, and `growpart` resizes the partition directly, which is
    contract check 9.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: an instance whose extra EBS volumes carry LVM metadata
    cannot activate them. `cryptsetup` is already gone (#31), and
    device-mapper targets in general are unavailable on this image.
    Requires: nothing.
    Source: found by lab, exp #60, backlog item `e24`
  '';

  config = lib.mkIf cfg.enable {
    services.lvm.enable = false;

    system.forbiddenDependenciesRegexes = [ "-lvm2-" ];
  };
}
