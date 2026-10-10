{ config, lib, ... }:
let
  cfg = config.smol.noInstallerTools;
in
{
  options.smol.noInstallerTools.enable = lib.mkEnableOption ''
    removing `nixos-rebuild`, `nixos-generate-config`, `nixos-install`,
    `nixos-enter` and `nixos-option` from `environment.systemPackages`
    through `system.disableInstallerTools`.

    On its own this saves nothing: `virtualisation.amazon-init` holds a
    second reference to `nixos-rebuild`, so the tool and its CPython stay in
    the closure. It therefore asserts `smol.noAmazonInit`.

    Measured saving (appliance track, EC2): 12.34 MiB closure, ledger #5.
    Far less than the 136.55 MiB CPython it was aimed at: `amazon-ec2-utils`
    holds a second reference to the interpreter through a udev rule. See
    BACKLOG.md item `e8`.
    Trade-offs: the target cannot rebuild itself. That is the definition of
    the appliance track, where updates replace the AMI, but it makes the
    system unusable on the mutable track.
    Requires: `smol.noAmazonInit`, and the appliance track.
    Source: found by lab, exp #003 and #005
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.smol.track == "appliance";
        message = ''
          smol.noInstallerTools removes nixos-rebuild, which the mutable
          track needs for contract check 6. Set smol.track = "appliance" or
          disable this option.
        '';
      }
      {
        assertion = config.smol.noAmazonInit.enable;
        message = ''
          smol.noInstallerTools saves nothing without smol.noAmazonInit:
          virtualisation.amazon-init puts nixos-rebuild on its PATH, so the
          tool and its CPython stay in the closure. Enable
          smol.noAmazonInit too. Found the hard way in experiment 003, where
          the forbiddenDependenciesRegexes guard failed the build.
        '';
      }
    ];

    system.disableInstallerTools = true;

    system.forbiddenDependenciesRegexes = [ "nixos-rebuild" ];
  };
}
