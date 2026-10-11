{ config, lib, ... }:
let
  cfg = config.smol.noNix;
in
{
  options.smol.noNix.enable = lib.mkEnableOption ''
    removing Nix itself through `nix.enable = false`. The appliance track is
    defined by having no Nix on the target, and until now it had 162.9 MiB
    of it: `nix-2.34.8` and its closure, including the 39.69 MiB `icu4c`
    that experiment 25 left unexplained.

    `nix why-depends` finds it behind a tmpfiles fragment:

        etc/tmpfiles.d/00-nixos.conf
          -> tmpfiles.d/nix-daemon.conf
            -> nix-2.34.8

    Nothing on an appliance reads the store through Nix. The store is still
    there and still mounted; what goes is the daemon, the CLI and everything
    they link.

    Measured saving (appliance track, EC2): 87.54 MiB closure, 94.02 MiB
    raw image, ledger #26. Less than the 162.9 MiB `nix` closure, because
    much of what Nix links is shared with the rest of the system.
    Trade-offs: no `nix` command, no nix-daemon, no garbage collection, and
    nothing can be built or substituted on the target. The store becomes a
    read-only artefact of the image. This is the appliance track taken
    literally, and it is the single clearest line between the two tracks.
    Requires: the appliance track. Asserts against `smol.track = "mutable"`.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item `n3`
  '';

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.smol.track == "appliance";
        message = ''
          smol.noNix removes Nix, which the mutable track needs for contract
          check 6. Set smol.track = "appliance" or disable this option.
        '';
      }
    ];

    nix.enable = false;

    system.forbiddenDependenciesRegexes = [ "-nix-2\\." ];
  };
}
