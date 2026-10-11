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
          import (pkgs.path + "/nixos/lib/make-disk-image.nix") {
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
