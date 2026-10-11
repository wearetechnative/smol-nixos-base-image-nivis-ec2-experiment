{ config, lib, ... }:
let
  cfg = config.smol.slimSystemd;
in
{
  options.smol.slimSystemd.enable = lib.mkEnableOption ''
    building systemd with the features an appliance uses and no others.
    `systemd` is 63.02 MiB and the largest path left, and a stock build
    carries homed, portabled, importd, repart, sysupdate, vmspawn, oomd,
    coredump, cryptsetup, TPM2, FIDO2, qrencode and the remote journal
    tooling, none of which this image has a caller for.

    This is a `nixpkgs.overlays` entry rather than an override on
    `systemd.package`, which is the whole point: an override would leave
    every consumer linking the stock build and the image would carry two
    systemds instead of one. It is why the flake never hands a prebuilt
    `pkgs` to `nixosSystem`, and why gate 1 sets `node.pkgsReadOnly = false`.

    What stays, and why:

    - `withAnalyze`, because `lab/deploy-ec2.sh` measures boot time with
      `systemd-analyze` and the ledger would lose a column without it.
    - `withTimedated`, because contract check 6 calls `timedatectl`.
    - `withTimesyncd`, because check 6 is about the clock being synchronised.
    - `withLogind`, because SSH sessions are logind sessions.
    - `withMachined`, because `/etc/nsswitch.conf` lists `mymachines` and
      losing the module breaks `getent`, which is contract check 4.
    - `withQrencode`, which looks like the most obviously useless feature on
      a headless server and is not optional: it gates
      `systemd-bsod.service`, and NixOS puts that unit in the initrd's list
      unconditionally. Without it `initrd-units` fails to build with
      `missing .../example/systemd/system/systemd-bsod.service`. libqrencode
      is small; fighting the unit list is not.

    Measured saving (appliance track, EC2): 36.98 MiB closure, 46.00 MiB
    raw image, ledger #36.
    Trade-offs: no coredumps, no systemd-homed, no portable services, no
    `systemd-repart`, no TPM2 or FIDO2 unlocking, no remote journal upload.
    Each is a capability a production base image might want; none is
    reachable on a machine that is replaced rather than administered.
    Requires: nothing.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `s1`
  '';

  config = lib.mkIf cfg.enable {
    # Turning a feature off in the package is only half of it. NixOS still
    # references what the feature would have installed, and the failure is
    # always the same shape: a build error naming a missing file under
    # ${systemd}. Each of these was found one build at a time, in
    # experiments 32 to 35.
    #
    # Two have their own NixOS option:
    systemd.coredump.enable = false;
    systemd.oomd.enable = false;

    # The rest are in `upstreamSystemUnits`, which NixOS copies
    # unconditionally. `suppressedSystemUnits` is filtered out of that list
    # before the copy, so it is the right lever rather than keeping the
    # feature just to satisfy a unit nothing will start.
    systemd.suppressedSystemUnits = [
      "systemd-importd.service"
      "systemd-importd.socket"
      "systemd-portabled.service"
    ];

    nixpkgs.overlays = [
      (final: prev: {
        systemd = prev.systemd.override {
          withApparmor = false;
          withAudit = false;
          withCoredump = false;
          withCryptsetup = false;
          withDocumentation = false;
          withFido2 = false;
          withFirstboot = false;
          withHomed = false;
          withImportd = false;
          withLibarchive = false;
          withOomd = false;
          withPasswordQuality = false;
          withPolkit = false;
          withPortabled = false;
          withRemote = false;
          withRepart = false;
          withShellCompletions = false;
          withSysupdate = false;
          withTpm2Tss = false;
          withVmspawn = false;
        };
      })
    ];
  };
}
