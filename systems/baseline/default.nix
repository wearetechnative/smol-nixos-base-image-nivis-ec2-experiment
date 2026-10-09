# Stock EC2 configuration as nivis would deploy it.
#
# FROZEN after phase 0 (BRIEFING §4). Every measurement in ledger.jsonl is
# relative to this system. Changing it invalidates the whole ledger and
# requires a new contract epoch plus Pim's approval.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/virtualisation/amazon-image.nix") ];

  smol.profile = "none";
  smol.track = "appliance";

  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
