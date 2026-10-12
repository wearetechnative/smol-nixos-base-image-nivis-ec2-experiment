# baseline + every accepted smol.* strategy. The current best.
#
# `aggressive` is every strategy that has passed both gates, which is what
# "accepted" means. Membership lives in modules/smol/profiles.nix.
{ ... }:
{
  imports = [
    ../baseline

    # Not a `smol.*` toggle: it replaces an upstream module, and
    # `disabledModules` and `imports` cannot depend on an option. Ledger #67.
    ../../modules/smol/wrappers-without-propagation.nix
  ];

  smol.profile = "aggressive";
}
