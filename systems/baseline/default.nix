# Stock EC2 configuration as nivis would deploy it.
#
# FROZEN after phase 0 (BRIEFING §4). Every measurement in ledger.jsonl is
# relative to this system. Changing it invalidates the whole ledger and
# requires a new contract epoch plus Pim's approval.
{
  modulesPath,
  lib,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/amazon-image.nix") ];

  # mkDefault so systems/candidate and systems/accepted can pick a profile
  # without fighting this. The evaluated value here is unchanged, so the
  # baseline derivation and ledger line 1 are unaffected.
  smol.profile = lib.mkDefault "none";
  smol.track = lib.mkDefault "appliance";

  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
