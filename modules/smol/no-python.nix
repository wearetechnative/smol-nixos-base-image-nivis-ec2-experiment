{ config, lib, ... }:
let
  cfg = config.smol.noPython;
in
{
  options.smol.noPython.enable = lib.mkEnableOption ''
    removing the CPython interpreter from an EC2 image. A stock NixOS EC2
    system carries a full 136.55 MiB CPython for the sake of exactly two
    scripts, neither of which the machine needs to boot or to be managed:

    - `ebsnvme-id` in `amazon-ec2-utils`, run by
      `70-ec2-nvme-devices.rules` to turn an EBS volume's attachment name
      into a `/dev/sdX` symlink on Nitro.
    - `ec2metadata` in `cloud-utils`, which ships in the same output as
      `growpart` and is pulled in with it by `growpart.service`.

    Both are stripped, along with the two udev rules that call the first.
    Everything else stays: `ec2udev-vbd` and `ec2nvme-nsid` are shell,
    `growpart` itself is shell, and the `queue/io_timeout` tuning in the NVMe
    rules is reliability rather than naming and must not be lost.

    Measured saving (appliance track, EC2): 136.87 MiB closure,
    137.00 MiB raw image, ledger #9. Boot time also fell from about 40s to
    38.1s, the first change in this lab to move it measurably.
    Trade-offs: no `/dev/sdX` or `/dev/xvdX` symlink for an NVMe-backed EBS
    volume, so anything addressing a volume by its attachment name breaks.
    The root filesystem is found by label and does not care. No
    `ec2metadata` command on the target, which is a convenience for humans
    rather than something the system uses.
    Requires: `smol.noInstallerTools`, which removes the third consumer.
    Source: found by lab, exps #005, #007 and #008, by following
    `nix why-depends` to the interpreter four times over
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.smol.noInstallerTools.enable;
        message = ''
          smol.noPython saves nothing while nixos-rebuild is present: it is a
          Python program and holds the interpreter on its own. Enable
          smol.noInstallerTools too.
        '';
      }
    ];

    nixpkgs.overlays = [
      (final: prev: {
        amazon-ec2-utils = prev.amazon-ec2-utils.overrideAttrs (old: {
          # preFixup, not postInstall: this package's installPhase is custom
          # and never calls `runHook postInstall`, so a postInstall hook
          # silently does nothing at all.
          preFixup = (old.preFixup or "") + ''
            rm -f "$out/bin/ebsnvme-id"
            sed -i '/ebsnvme-id/d' "$out/lib/udev/rules.d/70-ec2-nvme-devices.rules"
          '';

          # installCheckPhase runs `$out/bin/ebsnvme-id --help`.
          doInstallCheck = false;
        });

        cloud-utils = prev.cloud-utils.overrideAttrs (old: {
          # postFixup, because this package does its own moveToOutput and
          # wrapProgram there and the file does not reach $guest until then.
          postFixup = (old.postFixup or "") + ''
            rm -f "$guest/bin/ec2metadata" "$guest/bin/.ec2metadata-wrapped"
            rm -f "$out/bin/ec2metadata"
          '';
        });
      })
    ];

    system.forbiddenDependenciesRegexes = [ "python3-3" ];
  };
}
