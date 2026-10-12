{ config, lib, ... }:
let
  cfg = config.smol.slimOpenssh;

  # Everything openssh installs that only a client runs. `sshd`,
  # `sshd-session`, `sshd-auth`, `ssh-keygen` for the host keys, `scp` and
  # `sftp-server` for the harness's file push all stay.
  clientBinaries = [
    "ssh"
    "ssh-add"
    "ssh-agent"
    "ssh-keyscan"
    "ssh-keysign"
    "ssh-pkcs11-helper"
    "ssh-sk-helper"
    "sftp"
  ];
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

  options.smol.slimOpenssh.serverOnly = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to delete openssh's client programs from the package.

      The appliance is connected *to*. It never opens an outbound SSH
      session, so `ssh`, `ssh-add`, `ssh-agent`, `ssh-keyscan`,
      `ssh-keysign`, `ssh-pkcs11-helper`, `ssh-sk-helper` and `sftp` are
      3.92 MiB of programs with no caller. `scp` and `sftp-server` stay:
      the verification harness pushes a static curl to the machine, which
      runs `scp -t` on this side.

      It is `rm` appended to `installCheckPhase` rather than a build flag,
      because openssh has no flag for it and the removal has to run after
      the package's own check, which greets `$out/bin/ssh -V`. The package is one build with one set of
      shared code, so the saving is the binaries themselves and nothing
      else leaves with them.
    '';
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        openssh = (prev.openssh.override { withFIDO = false; }).overrideAttrs (
          old:
          lib.optionalAttrs cfg.serverOnly {
            # Appended to the install check rather than to postInstall or
            # postInstallCheck. openssh's own check greets `$out/bin/ssh
            # -V`, so the removal has to come after it, and the package
            # replaces `installCheckPhase` wholesale without calling
            # `runHook postInstallCheck`, so that hook never fires.
            installCheckPhase = old.installCheckPhase + ''
              rm -f ${lib.concatMapStringsSep " " (b: "$out/bin/" + b) clientBinaries}
            '';
          }
        );
      })
    ];

    system.forbiddenDependenciesRegexes = [ "-libfido2-" ];
  };
}
