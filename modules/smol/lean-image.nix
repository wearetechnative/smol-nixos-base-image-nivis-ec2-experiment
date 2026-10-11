{ config, lib, ... }:
let
  cfg = config.smol.leanImage;
in
{
  options.smol.leanImage.enable = lib.mkEnableOption ''
    building the disk image without the things the stock EC2 image builder
    puts in it by default and never measures.

    The closure is not the image. Every experiment in this lab until now
    measured `system.build.toplevel`, and the raw VHD stayed about 900 MiB
    larger than that number could explain. Reading
    `nixos/lib/make-disk-image.nix` says why:

    - `copyChannel` defaults to `true`, so the image carries a complete copy
      of the nixpkgs source tree as a nix channel. It is added to the
      image's own store through `basePaths`, so it never appears in the
      system closure and no measurement here could see it. An appliance with
      no Nix has no use for a channel.
    - `diskSize` is forced to a fixed 4096 MiB by
      `maintainers/scripts/ec2/amazon-image.nix`, where make-disk-image's own
      default is `"auto"`, which sizes the filesystem to its contents plus
      `additionalSpace`.

    Both are changed here by extending `image.modules.amazon`, which is a
    `deferredModule` and therefore merges with nixpkgs' own definition. The
    override applies only inside the image evaluation; the system
    configuration is untouched.

    Measured saving (appliance track, EC2): **544.14 MiB of raw image**,
    1400.35 to 856.21 MiB, 38.9%, with no change to the closure at all.
    Boot time also fell from 36.4s to 14.3s, ledger #25.
    Trade-offs: no `nix-channel` on the target, which matters only on the
    mutable track, and a root filesystem sized to its contents rather than to
    4 GiB. `growpart` still grows the partition to fill whatever EBS volume
    the instance is launched with, so the running machine is unaffected.
    Requires: nothing.
    Source: found by lab, exp #022, by reading the image builder rather than
    the closure
  '';

  config = lib.mkIf cfg.enable {
    image.modules.amazon =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        system.build.amazonImage = lib.mkForce (
          import
            (
              # nixpkgs' make-disk-image installs the bootloader by chrooting
              # into the new root and running
              # /nix/var/nix/profiles/system/bin/switch-to-configuration, so
              # an image can only be built from a system that carries that
              # program. It is needed at image-build time and never at run
              # time, and carrying it costs 127.53 MiB: it is the sole
              # remaining holder of perl, GRUB, systemd-minimal and
              # btrfs-progs. Experiments 18, 20, 21 and 37 each ended here.
              #
              # The builder VM already has the full build closure at
              # /nix/store, which is a superset of what the image contains.
              # Bind-mounting it over the image's store for the duration of
              # the bootloader step makes the installer reachable inside the
              # chroot without copying anything into the image, so nothing
              # is added to the runtime closure.
              #
              # Patched rather than vendored: the substitution is the whole
              # diff, it is checked with --replace-fail so a nixpkgs change
              # breaks the build loudly rather than silently reverting to
              # the old behaviour, and the other 800 lines stay upstream's.
              pkgs.runCommand "make-disk-image-bootloader-without-stc.nix" { } ''
                      substitute ${pkgs.path}/nixos/lib/make-disk-image.nix $out \
                        --replace-fail \
                          'NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root $mountPoint -- /nix/var/nix/profiles/system/bin/switch-to-configuration boot' \
                          'mkdir -p $mountPoint/nix/store
                mount --bind /nix/store $mountPoint/nix/store
                NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root $mountPoint -- ''${config.system.build.installBootLoader} ''${config.system.build.toplevel}
                umount $mountPoint/nix/store'
              ''
            )
            {
              inherit lib config pkgs;

              name = config.image.baseName;
              inherit (config.image) baseName;

              format = "vpc";
              fsType = "ext4";
              partitionTableType = if config.ec2.efi then "efi" else "legacy+gpt";

              # The two changes this strategy exists for.
              copyChannel = false;
              diskSize = "auto";
              additionalSpace = "128M";

              # The stock builder writes a configuration.nix into the image so
              # someone can rebuild from it. Nothing on the appliance track can.
              configFile = null;

              postVM = ''
                mkdir -p $out/nix-support
                echo "file vpc $diskImage" >> $out/nix-support/hydra-build-products
              '';
            }
        );
      };
  };
}
