{ config, lib, ... }:
let
  cfg = config.smol;

  # Which profiles a strategy belongs to. Add an entry here only after the
  # strategy's module is imported in ./default.nix and the strategy has been
  # accepted through both gates (BRIEFING §8).
  #
  # Example once `smol.noDocumentation` exists:
  #   noDocumentation = [ "safe" "aggressive" ];
  #   noNix           = [ "aggressive" ];
  strategies = {
    emptyHwdb = [ "aggressive" ];
    leanImage = [
      "safe"
      "aggressive"
    ];
    noDefaultPackages = [ "aggressive" ];
    noBashCompletion = [ "aggressive" ];
    noDocumentation = [
      "safe"
      "aggressive"
    ];
    noDuplicateSystemd = [ "aggressive" ];
    noEditor = [ "aggressive" ];
    noFirewall = [ "aggressive" ];
    noKernelModules = [ "aggressive" ];
    noLastlog = [ "aggressive" ];
    minimalSystemPackages = [ "aggressive" ];
    noNix = [ "aggressive" ];
    noFlakeRegistry = [
      "safe"
      "aggressive"
    ];
    noAmazonInit = [ "aggressive" ];
    noInstallerTools = [ "aggressive" ];
    noLvm = [ "aggressive" ];
    noPerl = [ "aggressive" ];
    noPython = [ "aggressive" ];
    noSudo = [ "aggressive" ];
    noSwitchToConfiguration = [ "aggressive" ];
    noX11 = [ "aggressive" ];
    noUserDataDecompression = [ "aggressive" ];
    noSsmAgent = [ "aggressive" ];
    slimCurl = [ "aggressive" ];
    slimOpenssh = [ "aggressive" ];
    slimIproute2 = [ "aggressive" ];
    slimSystemd = [ "aggressive" ];
  };
in
{
  # Attribute names here are static on purpose: deriving them from
  # `cfg.profile` makes the module system recurse on itself.
  config.smol = lib.mapAttrs (_: profiles: {
    enable = lib.mkDefault (lib.elem cfg.profile profiles);
  }) strategies;
}
