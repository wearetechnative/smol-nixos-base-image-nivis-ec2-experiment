{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.smol.emptyHwdb;
in
{
  options.smol.emptyHwdb.enable = lib.mkEnableOption ''
    shipping an empty udev hardware database. `/etc/udev/hwdb.bin` is 13.21
    MiB of vendor and model properties for USB devices, PCI cards, keyboards,
    pointing devices, accelerometers and the rest. A Nitro instance has an
    ENA adapter and an NVMe disk, neither of which needs a lookup table to be
    recognised.

    There is no NixOS option for this: `services/hardware/udev.nix` builds
    `hwdb.bin` from the `hwdb.d` files of udev and every package in
    `services.udev.packages`, and wires it to `environment.etc` with no
    switch. The override replaces the file with a database generated the same
    way from a single placeholder entry, so it is a valid database that
    matches nothing rather than an empty file udev has to cope with.

    Measured saving (appliance track, EC2): 13.21 MiB closure, 16.00 MiB
    raw image, ledger #39.
    Trade-offs: udev applies no hardware properties. On a machine with
    peripherals that means wrong keyboard mappings, missing device names and
    no model metadata; on a virtual machine with two virtual devices it means
    nothing.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `s9`
  '';

  config = lib.mkIf cfg.enable {
    environment.etc."udev/hwdb.bin".source = lib.mkForce (
      pkgs.runCommand "hwdb-empty.bin"
        {
          preferLocalBuild = true;
          allowSubstitutes = false;
        }
        ''
          mkdir -p etc/udev/hwdb.d
          # systemd-hwdb writes nothing at all when it finds no input and
          # exits successfully, so one trivial entry is needed to get a
          # valid database out of it rather than no file.
          printf 'smol:placeholder:\n SMOL_HWDB_EMPTY=1\n' \
            > etc/udev/hwdb.d/00-smol-empty.hwdb
          ${pkgs.buildPackages.systemd}/bin/systemd-hwdb --root=$(pwd) update
          mv etc/udev/hwdb.bin $out
        ''
    );
  };
}
