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

  options.smol.leanImage.additionalSpace = lib.mkOption {
    type = lib.types.str;
    default = "32M";
    description = ''
      Free space `make-disk-image` leaves in the filesystem on top of its
      contents, with `diskSize = "auto"`.

      It is slack inside the artefact that gets uploaded to S3 and imported
      as an EBS snapshot, and it is not what the instance runs on: the root
      volume is sized at launch by `rootVolumeGb` in `lab/nivis-plan.nix`,
      8 GiB by default, and `growpart` with `resize2fs` expands the
      filesystem into it on first boot. That is contract check 9, so every
      gate 2 run proves the expansion still happens.

      make-disk-image's own default is `512M`; `smol.leanImage` used `128M`
      from #25 and `32M` since #68, which measured 2.00 MiB rather than the
      96 MiB the arithmetic suggests. Experiments 69 to 71 went looking for
      the rest and found that there is nothing there to win: the automatic
      sizing only has to be large enough, `qemu-img convert -O vpc` writes
      a sparse VHD, and the bytes that exist are the bytes the filesystem
      actually holds. Cutting the inode allowance in half moved the
      allocated size of the image by 64 KiB. The image is its contents.
    '';
  };

  options.smol.leanImage.pristineBuilderVm = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the VM that builds the image comes from an unoverlaid
      nixpkgs.

      The image's contents come from `pkgs`, which carries every smol
      overlay, and that is not changed by this. The VM is a QEMU and a
      kernel whose only job is to hold a loop device, and taking those from
      `import pkgs.path { }` instead is what stops a systemd or util-linux
      override from rebuilding QEMU, gtk4, mesa and pipewire before the
      image can be measured. Experiments 48, 55 and 58 each paid about an
      hour for that; 57 could not finish at all.

      It is not a pure refactor, which is why it is an option and not a
      straight change: the image built this way is 2 MiB smaller and
      differs in 154 million bytes, so the builder VM does reach the
      result. Ledger #59 measured it and passed both gates, and the default
      is `true` since.
    '';
  };

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
              inherit lib config;

              pkgs =
                if cfg.pristineBuilderVm then
                  pkgs.extend (
                    _: _: {
                      inherit (import pkgs.path { inherit (pkgs.stdenv.hostPlatform) system; })
                        vmTools
                        ;
                    }
                  )
                else
                  pkgs;

              name = config.image.baseName;
              inherit (config.image) baseName;

              format = "vpc";
              fsType = "ext4";
              partitionTableType = if config.ec2.efi then "efi" else "legacy+gpt";

              # The two changes this strategy exists for.
              copyChannel = false;
              diskSize = "auto";
              inherit (cfg) additionalSpace;

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
