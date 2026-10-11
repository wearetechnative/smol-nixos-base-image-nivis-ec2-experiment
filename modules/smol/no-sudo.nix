{ config, lib, ... }:
let
  cfg = config.smol.noSudo;
in
{
  options.smol.noSudo.enable = lib.mkEnableOption ''
    removing sudo. `security.sudo.enable` defaults on, and the appliance has
    one account, root, reached over SSH with a key injected from instance
    metadata. There is nobody to escalate from.

    `security.wrappers` itself stays, and must: pam_unix needs
    `unix_chkpwd` or login fails and getty loops. Only sudo's own wrapper
    goes.

    Measured saving (appliance track, EC2): 5.81 MiB closure, 8.00 MiB raw
    image, ledger #43.
    Trade-offs: no privilege escalation at all. On an image where the only
    login is root this changes nothing in practice, and on any image where
    it is not, it changes everything. A production base image that creates
    an unprivileged admin user needs sudo.
    Requires: nothing.
    Source: found by lab, exp #43, from `FLOOR.md`'s unexplained paths
  '';

  config = lib.mkIf cfg.enable {
    security.sudo.enable = false;
  };
}
