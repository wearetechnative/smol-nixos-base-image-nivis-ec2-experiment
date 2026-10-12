{ config, lib, ... }:
let
  cfg = config.smol.noNscd;
in
{
  options.smol.noNscd.enable = lib.mkEnableOption ''
    turning off the name service cache daemon.

    NixOS runs `nsncd-1.5.3`, 1.46 MiB, as `nscd.service`. It is a cache in
    front of NSS, not a part of it: the modules themselves are glibc
    plugins that each process loads. This image's `nsswitch.conf` is

    ```
    passwd:    files systemd
    group:     files [success=merge] systemd
    hosts:     mymachines files myhostname dns
    ```

    `files` reads `/etc/passwd`, `systemd` and `mymachines` come from
    systemd's own NSS plugins, and `dns` goes to the resolver. None of
    them needs a daemon, and there is one user and no directory service.

    NixOS asserts that loading NSS modules requires `nscd`, and names the
    way out itself: `system.nssModules = lib.mkForce []`. Experiment 63 hit
    that assertion. So this module drops systemd's NSS plugins along with
    the daemon, and sets `nsswitch.conf` to the sources that remain:

    ```
    passwd:    files
    group:     files
    hosts:     files dns
    ```

    `systemd` and `mymachines` resolve dynamic users and nspawn machines.
    No unit on this image sets `DynamicUser` and there are no containers,
    so both answer for a population of zero.

    Contract check 4 is `getent hosts`, which is exactly the path this
    changes, so gate 1 answers the question rather than an argument about
    it.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: every NSS lookup goes to the source, and `DynamicUser`
    units would no longer resolve to a name. On a machine with a directory
    service or dynamic users both are real costs; here the sources are two
    files and a resolver that caches for itself, and there are no dynamic
    users.
    Requires: nothing.
    Source: found by lab, exp #63, backlog item `e27`
  '';

  config = lib.mkIf cfg.enable {
    services.nscd.enable = false;

    system.nssModules = lib.mkForce [ ];

    system.nssDatabases = {
      passwd = lib.mkForce [ "files" ];
      group = lib.mkForce [ "files" ];
      shadow = lib.mkForce [ "files" ];
      hosts = lib.mkForce [
        "files"
        "dns"
      ];
      services = lib.mkForce [ "files" ];
    };

    system.forbiddenDependenciesRegexes = [ "-nsncd-" ];
  };
}
