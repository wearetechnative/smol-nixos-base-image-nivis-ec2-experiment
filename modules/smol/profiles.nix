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
  };
in
{
  # Attribute names here are static on purpose: deriving them from
  # `cfg.profile` makes the module system recurse on itself.
  config.smol = lib.mapAttrs (_: profiles: {
    enable = lib.mkDefault (lib.elem cfg.profile profiles);
  }) strategies;
}
