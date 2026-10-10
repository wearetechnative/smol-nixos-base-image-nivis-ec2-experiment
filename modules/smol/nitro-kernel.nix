{ config, lib, ... }:
let
  cfg = config.smol.nitroKernel;
in
{
  options.smol.nitroKernel.enable = lib.mkEnableOption ''
    a kernel configured for a Nitro instance instead of for arbitrary
    hardware. The stock NixOS kernel ships a 145.17 MiB module tree, of which
    115 MiB is `drivers`: 15 MiB of media, 13 of GPU, 15 of sound, and a long
    tail of buses and sensors that no virtual machine has ever had.

    What an EC2 Nitro instance actually needs is ENA for the network, NVMe
    for storage and ext4 for the root filesystem. Those are built in rather
    than left modular, so nothing has to be loaded at runtime to reach the
    root device.

    virtio and 9p stay built in too, and that is not an oversight: gate 1
    boots this same kernel under QEMU, so a kernel that only works on Nitro
    cannot be tested locally. One kernel has to satisfy both gates.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: no sound, no graphics, no USB, no wireless, no infiniband, no
    industrial IO, no sensors, and a short list of filesystems. On an
    instance type with different hardware this kernel may not boot at all,
    which is why it is named for Nitro rather than for EC2.
    Requires: nothing, but `smol.noKernelModules` requires this.
    Source: BACKLOG.md item `e1`, and natkr's `n7` for the follow-up
  '';

  config = lib.mkIf cfg.enable {
    boot.kernelPatches = [
      {
        name = "smol-nitro";
        patch = null;
        # mkForce throughout: nixpkgs' common-config.nix already has an
        # opinion about nearly every one of these, and a structured kernel
        # config conflicts rather than merges.
        structuredExtraConfig =
          let
            on = lib.mkForce lib.kernel.yes;
            off = lib.mkForce lib.kernel.no;
          in
          {
            # --- what the machine cannot boot without --------------------
            # Built in, not modular: nothing should need loading to reach
            # the root device.
            NET_VENDOR_AMAZON = on;
            ENA_ETHERNET = on;
            BLK_DEV_NVME = on;
            NVME_CORE = on;
            EXT4_FS = on;

            # Gate 1 runs this same kernel under QEMU.
            VIRTIO = on;
            VIRTIO_PCI = on;
            VIRTIO_BLK = on;
            VIRTIO_NET = on;
            VIRTIO_CONSOLE = on;
            VIRTIO_BALLOON = on;
            NET_9P = on;
            NET_9P_VIRTIO = on;
            FUSE_FS = on;
            VIRTIO_FS = on;

            # The serial console is how a failed boot is diagnosed at all.
            SERIAL_8250 = on;
            SERIAL_8250_CONSOLE = on;

            # --- whole subsystems a virtual machine has no use for -------
            SOUND = off;
            DRM = off;
            AGP = off;
            MEDIA_SUPPORT = off;
            IIO = off;
            INFINIBAND = off;
            WLAN = off;
            STAGING = off;
            HWMON = off;
            WATCHDOG = off;
            BT = off;
            CAN = off;
            HAMRADIO = off;
            MEMSTICK = off;
            MMC = off;
            PCMCIA = off;
            PARPORT = off;
            GAMEPORT = off;
            INPUT_JOYSTICK = off;
            INPUT_TABLET = off;
            INPUT_TOUCHSCREEN = off;
            SURFACE_PLATFORMS = off;
          };
      }
    ];
  };
}
