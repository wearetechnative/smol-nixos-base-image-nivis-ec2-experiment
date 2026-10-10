{ config, lib, ... }:
let
  cfg = config.smol.noDocumentation;
in
{
  options.smol.noDocumentation.enable = lib.mkEnableOption ''
    removing man pages, info pages, docbook documentation and the generated
    NixOS manual through `documentation.enable = false`. First item on
    natkr's list, and the one with the least to argue about: nothing on a
    headless appliance reads a man page.

    Measured saving (appliance track, EC2): 93.87 MiB closure,
    94.00 MiB raw image, ledger #10.
    Trade-offs: no `man` on the target. `nixos-help` and the generated option
    documentation go too, though neither is reachable without a browser.
    Requires: nothing.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item n1
  '';

  config = lib.mkIf cfg.enable {
    documentation.enable = false;
  };
}
