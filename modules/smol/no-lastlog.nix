{ config, lib, ... }:
let
  cfg = config.smol.noLastlog;
in
{
  options.smol.noLastlog.enable = lib.mkEnableOption ''
    turning off PAM's lastlog module. `programs/shadow.nix` enables it for
    the `login` service, which pulls `pam_lastlog2.so` in, and with it
    sqlite, a tmpfiles fragment and a `lastlog2-import.service`.

    The appliance is reached over SSH and nobody reads "last login" on it.

    Measured saving (appliance track, EC2): 3344 bytes, ledger #19.
    Effectively nothing: sqlite stays in the closure through another holder,
    so siraben's reported win does not reproduce here. Its value is as a
    prerequisite for `smol.noDuplicateSystemd`, not as a saving.
    Trade-offs: `/var/log/wtmp` is not updated by PAM and `lastlog` reports
    nothing. On a machine with one user and no console logins that is no
    loss, but it is a real audit signal to give up on a machine where people
    do log in.
    Requires: nothing. `smol.noDuplicateSystemd` requires it, because the
    lastlog output is where util-linux's systemd fragments live.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `s8`
  '';

  options.smol.noLastlog.withLastlog2 = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether util-linux is built with liblastlog2 and `pam_lastlog2.so`.

      Turning the PAM module off, which is what `enable` does, leaves the
      library in the package, and `lslogins` in `util-linux-bin` links it.
      That is why `sqlite-3.53.3` survived ledger #19 and why that
      experiment measured 3344 bytes: the holder was never PAM, it was the
      build.

      With this false, util-linux configures with `--disable-liblastlog2`
      and `--disable-pam-lastlog2`, and sqlite has no runtime referrer left.

      It is a separate option from `enable` so that it could be measured
      against an `accepted` that still had it, which experiment 40 is the
      reason for. The default is `false` since ledger #56: 5.80 MiB closure
      and 8.00 MiB raw image, which is the saving #19 was supposed to find.
    '';
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.login.lastlog.enable = lib.mkForce false;

    nixpkgs.overlays = lib.mkIf (!cfg.withLastlog2) [
      (final: prev: {
        util-linux = prev.util-linux.override { withLastlog = false; };
      })
    ];
  };
}
