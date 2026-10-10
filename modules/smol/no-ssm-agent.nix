{ config, lib, ... }:
let
  cfg = config.smol.noSsmAgent;
in
{
  options.smol.noSsmAgent.enable = lib.mkEnableOption ''
    removing the AWS Systems Manager agent, which
    `virtualisation/amazon-image.nix` enables by default. It is a Go binary
    of roughly 110 MiB, and it exists to give Session Manager access and
    inventory reporting to instances that are managed through SSM.

    Measured saving (appliance track, EC2): 110.33 MiB closure,
    114.00 MiB raw image, ledger #6.
    Trade-offs: no Session Manager shell, no SSM inventory, no Run Command,
    no patch reporting. If the production fleet is managed through SSM this
    belongs in neither profile; the lab verifies over SSH and never uses it.
    Requires: nothing.
    Source: found by lab, exp #006, from `nix why-depends` on the baseline
  '';

  config = lib.mkIf cfg.enable {
    services.amazon-ssm-agent.enable = lib.mkForce false;

    system.forbiddenDependenciesRegexes = [ "amazon-ssm-agent" ];
  };
}
