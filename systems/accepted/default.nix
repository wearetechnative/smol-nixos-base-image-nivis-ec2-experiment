# baseline + every accepted smol.* strategy. The current best.
#
# `aggressive` is every strategy that has passed both gates, which is what
# "accepted" means. Membership lives in modules/smol/profiles.nix.
{ ... }:
{
  imports = [ ../baseline ];

  smol.profile = "aggressive";
}
