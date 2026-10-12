{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.smol.minimalSystemPackages;
in
{
  options.smol.minimalSystemPackages.enable = lib.mkEnableOption ''
    replacing `environment.systemPackages` with an explicit list of what this
    appliance actually runs. A stock EC2 NixOS has 57 packages on the system
    path, among them `man-db`, `bind`, `nano`, `shared-mime-info`,
    `hicolor-icon-theme`, `sound-theme-freedesktop`, `fontconfig`,
    `cryptsetup`, `lvm2`, `bcache-tools`, `kexec-tools` and GRUB's install
    tools. None of them has a caller on a headless machine that is replaced
    rather than reconfigured.

    This is `mkForce` on the whole list rather than a set of options, which
    BRIEFING §5 asks to avoid. The reason is that the contributions come from
    a dozen modules with no common switch, and filtering the list in place
    is self-referential and makes the module system recurse. The explicit
    list is also the honest form: it says what the appliance needs rather
    than what it happens not to have removed.

    Services are unaffected. `sshd`, `dhcpcd` and `dbus` reference their own
    packages from their unit definitions, so they keep working whether or not
    the package is on anyone's PATH.

    Measured saving (appliance track, EC2): 57.32 MiB closure, 86.03 MiB
    raw image, ledger #31. 57 packages down to 16. `smol.minimalSystemPackages.fullCoreutils = false` takes a further 12
    MiB, ledger #41.
    Trade-offs: no `man`, no editor, no `host` or `dig`, no LVM, LUKS or
    bcache tooling, and the bootloader cannot be reinstalled from the running
    system. Anything that shells out to one of these breaks, which on this
    image means checking the EC2 boot path and the verification contract,
    both of which gate 1 covers.
    Requires: nothing.
    Source: <https://natkr.com/2026-06-19-nixos-but-smol/>, backlog item `n5`
  '';

  options.smol.minimalSystemPackages.fullCoreutils = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether to install `coreutils-full` rather than plain `coreutils`.
      Both are already in the closure, because other things depend on the
      plain build, so the full one costs 12 MiB for utilities nothing on
      this image calls.

      It is an option rather than a straight change to the package list so
      that the two can be measured against each other. Refining a module
      `systems/accepted` already enables moves both sides of the comparison
      at once, and `lab/experiment.sh` correctly reports a delta of zero.
    '';
  };

  options.smol.minimalSystemPackages.withProcps = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether `procps` stays on the system path.

      It is 2.32 MiB and `system-path` is its only referrer, so it is
      there for a person who has logged in: `ps`, `free`, `uptime`,
      `sysctl`. Nothing on the image calls any of them, and neither does
      the contract. `systemctl status` answers the same questions through
      PID 1, which is where the appliance's processes actually live.

      An option rather than a straight change to the package list, so the
      two could be measured against each other: experiment 40 is why. The
      default is `false` since ledger #74, which measured 2.33 MiB.
    '';
  };

  options.smol.minimalSystemPackages.extra = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = ''
      Packages to keep on the system path alongside the minimal set. The
      list is installed with `mkForce`, so nothing can be added to it the
      ordinary way; this is the seam for the things that genuinely have to
      be added back. `lab/test-support/qemu.nix` uses it for `netcat`, which
      the NixOS test driver needs and the appliance does not.
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkForce (
      cfg.extra
      ++ [
        config.systemd.package
        pkgs.util-linux
        (if cfg.fullCoreutils then pkgs.coreutils-full else pkgs.coreutils)
        pkgs.bashInteractive
        pkgs.gnused
        pkgs.gnugrep
        pkgs.gawk
        pkgs.findutils
        pkgs.glibc
        # A separate wrapper derivation, not an output of glibc. The
        # contract's DNS check calls `getent`, and experiments 28 and 29
        # passed the HTTPS check while failing the DNS one: the static curl
        # the harness pushes is musl and resolves names without NSS, so only
        # the `getent` check tells the truth about name resolution here.
        pkgs.getent
        pkgs.e2fsprogs
        pkgs.kmod
        pkgs.shadow
        pkgs.iproute2
        # networking.resolvconf is on, and dhcpcd calls resolvconf to install
        # nameservers. Without it /etc/resolv.conf is never written, and
        # contract check 4 fails while check 5 still passes, because the
        # static curl the harness pushes is musl and resolves DNS itself.
        # Experiment 28.
        pkgs.openresolv
        pkgs.less
      ]
      ++ lib.optional cfg.withProcps pkgs.procps
    );
  };
}
