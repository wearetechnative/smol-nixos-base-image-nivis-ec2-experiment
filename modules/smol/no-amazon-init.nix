{ config, lib, ... }:
let
  cfg = config.smol.noAmazonInit;
in
{
  options.smol.noAmazonInit.enable = lib.mkEnableOption ''
    removing `virtualisation.amazon-init`, the service that reads EC2
    user-data and, when it looks like a NixOS configuration, applies it with
    `nixos-rebuild switch`. Because it does, it puts `nixos-rebuild` on the
    service's PATH, which is what keeps a full CPython interpreter in an
    image that has no other use for one.

    Measured saving (appliance track, EC2): 101.10 MiB closure,
    110.03 MiB raw image, ledger #4.
    Trade-offs: user-data is no longer executed. An instance can no longer be
    reconfigured at launch, which is the whole point of the appliance track
    but removes a mechanism a production fleet may depend on. SSH key
    injection is unaffected: that is `ec2-metadata-fetcher`, a different
    service.
    Requires: nothing, but `smol.noInstallerTools` requires this.
    Source: found by lab, exp #004, after exp #003's dependency guard caught
    that `system.disableInstallerTools` alone does not remove `nixos-rebuild`
  '';

  config = lib.mkIf cfg.enable {
    virtualisation.amazon-init.enable = lib.mkForce false;
  };
}
