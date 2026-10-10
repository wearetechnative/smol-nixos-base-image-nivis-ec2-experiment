{ config, lib, ... }:
let
  cfg = config.smol.noFirewall;
in
{
  options.smol.noFirewall.enable = lib.mkEnableOption ''
    turning off the in-guest firewall and relying on the EC2 security group
    instead. On EC2 the security group is already a stateful packet filter
    sitting in front of the instance, enforced outside the guest and
    unaffected by anything that happens inside it.

    This exists because `smol.noKernelModules` needs it: netfilter is
    modular, so `firewall.service` cannot start once the module tree is
    gone. It is worth having on its own terms, but the measured saving is
    small and the reason to enable it is the one that follows.

    Measured saving (appliance track, EC2): 7.53 MiB closure, ledger #14.
    Small, as expected: the point of this option is what it unlocks.
    Trade-offs: real, and this is the first strategy in this lab where the
    trade-off is about security rather than convenience. The instance has no
    defence of its own. A misconfigured security group is no longer caught by
    a second layer, and anything listening on an unexpected port is reachable
    from wherever that group allows. On a machine whose only listening
    service is sshd, behind a group that permits only 22, that is a
    defensible position. It is not a default anyone should inherit without
    reading this paragraph.
    Requires: nothing. `smol.noKernelModules` requires it.
    Source: found by lab, exp #013, where gate 1 caught `firewall.service`
    failing with the module tree removed
  '';

  config = lib.mkIf cfg.enable {
    networking.firewall.enable = false;
  };
}
