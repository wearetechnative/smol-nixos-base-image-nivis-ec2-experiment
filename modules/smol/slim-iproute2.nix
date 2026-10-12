{ config, lib, ... }:
let
  cfg = config.smol.slimIproute2;

  dropped = [
    "db"
    "iptables"
    "elfutils"
    "libbpf"
  ];
in
{
  options.smol.slimIproute2.enable = lib.mkEnableOption ''
    building `iproute2` without its optional dependencies.

    `ip` is kept: dhcpcd uses it and it is how the address and the default
    route get set. What comes with it in a stock build is four packages
    this image never calls:

    | package | what in iproute2 wants it | size |
    | ------- | ------------------------- | - |
    | `db-5.3.28` | `arpd`, an ARP cache daemon | 4.24 MiB |
    | `elfutils-0.195` | loading BPF programs through `tc` | 4.12 MiB |
    | `libbpf-1.7.0` | the same | 2.18 MiB |
    | `iptables-1.8.13-lib` | `tc`'s `xt` action, which calls into xtables | 2.18 MiB |

    `elfutils` is reached twice from iproute2, directly and through `libbpf`,
    and a third time from systemd, which is built with BPF support. Both
    stay until that is turned off as well, so this strategy's own saving is
    `db` and `iptables` only, and the guard names those two. Experiment 52
    guarded `elfutils` and `libbpf` as well and failed the build, correctly:
    they were still there.

    iproute2 has no configure flags for these. They are plain `buildInputs`
    that its configure script probes for, so the overlay filters them out of
    the list and lets the probe fail, which is what the upstream build
    already does on a static host platform.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: no `arpd`, no `tc` BPF actions, no `tc` xtables action. The
    firewall is already off (`smol.noFirewall`), nothing here shapes
    traffic, and `arpd` has no caller on this image or in NixOS.
    Requires: nothing.
    Source: found by lab, exp #52, from `FLOOR.md`'s referrer table
  '';

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        iproute2 = prev.iproute2.overrideAttrs (old: {
          buildInputs =
            let
              kept = builtins.filter (d: !(builtins.elem (lib.getName d) dropped)) old.buildInputs;
              removed = (builtins.length old.buildInputs) - (builtins.length kept);
            in
            assert lib.assertMsg (removed == builtins.length dropped) ''
              smol.slimIproute2 expected to filter ${toString (builtins.length dropped)}
              build inputs out of iproute2 and filtered ${toString removed}. The
              derivation's input list has changed; re-read
              pkgs/by-name/ip/iproute2/package.nix before adjusting this.
            '';
            kept;
        });
      })
    ];

    system.forbiddenDependenciesRegexes = [
      "-iptables-"
      "-db-5[.]3"
    ];
  };
}
