{ lib, ... }:
{
  imports = [
    ./profiles.nix
    # One file per strategy (BRIEFING §5). Append here when a strategy is added.
    ./empty-hwdb.nix
    ./lean-image.nix
    ./minimal-system-packages.nix
    ./nitro-kernel.nix
    ./no-default-packages.nix
    ./no-kernel-modules.nix
    ./no-lastlog.nix
    ./no-nix.nix
    ./no-perl.nix
    ./no-documentation.nix
    ./no-python.nix
    ./no-duplicate-systemd.nix
    ./no-firewall.nix
    ./no-flake-registry.nix
    ./no-amazon-init.nix
    ./no-installer-tools.nix
    ./slim-systemd.nix
    ./no-ssm-agent.nix
    ./no-switch-to-configuration.nix
  ];

  options.smol = {
    profile = lib.mkOption {
      type = lib.types.enum [
        "none"
        "safe"
        "aggressive"
      ];
      default = "none";
      description = ''
        Bundle of accepted size-reduction strategies to enable.

        `none` is the untouched baseline. `safe` enables every accepted
        strategy whose trade-offs are acceptable for a production base image.
        `aggressive` adds the strategies that cost functionality or
        supportability. Membership is defined in `modules/smol/profiles.nix`
        and every member has measured numbers in its own option description.
      '';
    };

    track = lib.mkOption {
      type = lib.types.enum [
        "appliance"
        "mutable"
      ];
      default = "appliance";
      description = ''
        Which track this system targets (BRIEFING §3). `appliance` has no Nix
        on the target, an immutable `/etc` and no switch-to-configuration;
        updates replace the AMI. `mutable` keeps Nix and in-place updates.
        Strategies incompatible with a track assert against it.
      '';
    };
  };
}
