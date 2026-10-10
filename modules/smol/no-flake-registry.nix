{ config, lib, ... }:
let
  cfg = config.smol.noFlakeRegistry;
in
{
  options.smol.noFlakeRegistry.enable = lib.mkEnableOption ''
    dropping the system flake registry. A flake-built NixOS pins its own
    nixpkgs into `/etc/nix/registry.json`, which drags the entire nixpkgs
    source checkout into the system closure so that `nix run nixpkgs#...`
    resolves offline. An appliance has no Nix and never resolves a flake
    reference, so the registry buys nothing and costs a fifth of the closure.

    Measured saving (appliance track, EC2): 199.75 MiB closure,
    504.12 MiB raw image, ledger #2.
    Trade-offs: `nix registry list` is empty and a bare `nixpkgs#` reference
    no longer resolves on the target. Irrelevant without Nix, and a mutable
    target can set the registry at runtime.
    Requires: nothing.
    Source: found by lab, exp #002, from `nix why-depends` on the baseline
  '';

  config = lib.mkIf cfg.enable {
    nix.registry = lib.mkForce { };

    # No forbiddenDependenciesRegexes guard here: this removes a data file's
    # reference to a source tree, not a package family, and the store path is
    # called "source", which is far too generic to match on safely.
  };
}
