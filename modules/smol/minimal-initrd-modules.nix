{ config, lib, ... }:
let
  cfg = config.smol.minimalInitrdModules;
in
{
  options.smol.minimalInitrdModules.enable = lib.mkEnableOption ''
    cutting `boot.initrd.availableKernelModules` down to what a Nitro
    instance can actually have. The stock list is 35 modules: IDE and SATA
    controllers, USB host controllers of three generations, MMC, PS/2
    keyboards and eight separate USB HID drivers. A Nitro instance has an
    NVMe disk and an ENA adapter.

    `ena` is not in this list and must not be: `smol.noKernelModules` pins it
    through `boot.initrd.kernelModules`, which force-loads it rather than
    leaving it for a udev probe that will never happen.

    Measured saving (appliance track, EC2): **not accepted**. Ledger #42
    measured 1.41 MiB closure and 4.00 MiB image, and gate 1 panicked: the
    test VM mounts its nix store over virtio and 9p, and this list removes
    the modules for both. Making it pass would need an escape hatch like
    `smol.minimalSystemPackages.extra`, which is a lot of machinery for 1.41
    MiB, inside BRIEFING §9's stop-criterion band.

    Kept, not enabled, because the finding is worth more than the saving:
    **the initrd module list has to satisfy both gates**, exactly like the
    kernel config in experiment 12. The initrd's 24.77 MiB is its systemd
    userland, not its modules, which are 2.7 MiB in total.
    Trade-offs: this initrd can reach an NVMe root filesystem and nothing
    else. An instance type with SATA or IDE storage will not boot, and the
    symptom is a kernel panic at root mount rather than a message about a
    missing module. Narrower than `smol.noKernelModules` and for the same
    reason.
    Requires: nothing, but it only makes sense alongside
    `smol.noKernelModules`.
    Source: <https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6>,
    backlog item `s5`
  '';

  config = lib.mkIf cfg.enable {
    # ext4 stays because CONFIG_EXT4_FS=m in this kernel, so the root
    # filesystem driver is itself a module the initrd has to carry.
    boot.initrd.availableKernelModules = lib.mkForce [
      "nvme"
      "ext4"
    ];
  };
}
