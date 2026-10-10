{ config, lib, ... }:
let
  cfg = config.smol.noKernelModules;
in
{
  options.smol.noKernelModules.enable = lib.mkEnableOption ''
    dropping the kernel module tree from the system closure. The `toplevel`
    carries a `kernel-modules` symlink to the full 145.17 MiB tree, which is
    the single largest path in the image and the only reason it is there at
    all is so modules can be loaded at runtime.

    An EC2 instance loads what it needs in the initrd, which carries its own
    copy of the handful of modules that matter, and then never loads another
    one. The tree behind the symlink is dead weight from the moment the root
    filesystem is mounted.

    Measured saving (appliance track, EC2): 152.93 MiB closure, ledger #17.
    The largest single saving in this lab, and more than the module tree
    itself: the module dependency metadata and firmware go with it.
    Trade-offs: `modprobe` can load nothing. Any hardware or feature not
    already force-loaded in the initrd or built into the kernel is
    unreachable, permanently, and the symptom is a device that silently does
    not appear rather than an error. This option therefore pins `ena` into
    the initrd, and it is the strategy most likely to break an instance type
    other than the one it was tested on: a type with a different network or
    storage adapter needs its driver added to the same list.
    Requires: `smol.noFirewall`. Netfilter is modular, so
    `firewall.service` cannot start once the tree is gone, which gate 1
    caught in experiment 013. It also leans entirely on
    `boot.initrd.availableKernelModules` carrying ENA and NVMe, which
    `virtualisation/amazon-image.nix` already arranges.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item `n7`
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.networking.firewall.enable;
        message = ''
          smol.noKernelModules leaves firewall.service unable to load
          netfilter, which fails the verification contract's "no failed
          units" check. Enable smol.noFirewall, or keep the module tree.
        '';
      }
    ];

    # Without the module tree, udev can load nothing after switch-root, and
    # in the initrd it only loads what the root device needs. Everything
    # this system needs later has to be force-loaded while the modules still
    # exist.
    #
    # kernelModules rather than availableKernelModules: the point is to load
    # these, not to make them available for a udev probe that will never
    # happen.
    boot.initrd.kernelModules = [
      # The network adapter. Without it the instance boots, mounts root, and
      # then sits unable to reach IMDS. Experiment 015.
      "ena"

      # CONFIG_PACKET=m, and dhcpcd needs an AF_PACKET socket to send a DHCP
      # request at all. Without it the link comes up and "A start job is
      # running for DHCP Client" never finishes. Experiment 016, and the
      # harder of the two to guess from the symptom.
      "af_packet"

      # CONFIG_FUSE_FS=m and CONFIG_CONFIGFS_FS=m. systemd mounts configfs
      # during early boot and the image has a fuse mount unit.
      "fuse"
      "configfs"
    ];

    # mkAfter, because the system builder's own `ln -s` for kernel-modules
    # otherwise merges after this and puts the symlink straight back.
    system.systemBuilderCommands = lib.mkAfter ''
      rm -f $out/kernel-modules
    '';
  };
}
