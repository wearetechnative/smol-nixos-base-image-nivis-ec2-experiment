{ config, lib, ... }:
let
  cfg = config.smol.noDefaultPackages;
in
{
  options.smol.noDefaultPackages.enable = lib.mkEnableOption ''
    emptying `environment.defaultPackages`, the set NixOS installs on every
    system whether or not anything asks for it: perl, rsync, strace and
    friends. natkr's second step.

    Measured saving (appliance track, EC2): 3.39 MiB closure, ledger #11.
    Far smaller than natkr's ISO context suggests, because most of what
    `defaultPackages` pulls in is also pulled in by something else on an EC2
    system. perl in particular survives it; see BACKLOG.md item `n8`.
    Trade-offs: none of those commands exist on the target. Anything shelling
    out to one of them breaks, which on this image means checking that
    nothing in the EC2 boot path does. The verification contract uses only
    coreutils, systemd and util-linux, all of which arrive by other routes.
    Requires: nothing.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item n2
  '';

  config = lib.mkIf cfg.enable {
    environment.defaultPackages = lib.mkForce [ ];
  };
}
