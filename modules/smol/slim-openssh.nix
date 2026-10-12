{ config, lib, ... }:
let
  cfg = config.smol.slimOpenssh;
in
{
  options.smol.slimOpenssh.enable = lib.mkEnableOption ''
    building openssh without hardware security key support.

    `withFIDO` pulls `libfido2-1.17.0`, 1.15 MiB, for the `ecdsa-sk` and
    `ed25519-sk` key types. Those need a physical authenticator plugged
    into the machine doing the authentication, and the only thing that
    authenticates here is `lab/deploy-ec2.sh`, with an ephemeral ed25519
    key it generates per run.

    `libfido2` has been in and out of this closure before: it was one of
    the holders of the duplicate `systemd-minimal` until `smol.slimSystemd`
    set `withFido2 = false` in #36, and it came straight back through
    openssh.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: no `-sk` key types. A deployment that authenticates with a
    YubiKey cannot reach this image.
    Requires: nothing.
    Source: found by lab, exp #62, backlog item `e26`
  '';

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        openssh = prev.openssh.override { withFIDO = false; };
      })
    ];

    system.forbiddenDependenciesRegexes = [ "-libfido2-" ];
  };
}
