# Neutralises the parts of `virtualisation/amazon-image.nix` that only make
# sense on a real EC2 instance, so the same system modules can boot under the
# NixOS test driver.
#
# Everything forced here is something gate 1 cannot prove; gate 2 on EC2 is
# what covers it (BRIEFING §8). Keep this list short and justified: every
# entry is a hole in the local gate.
{ config, lib, ... }:
{
  # The test driver supplies its own root device and bootloader.
  fileSystems = lib.mkForce { };
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.grub.device = lib.mkForce "nodev";

  # amazon-init and the IMDS fetchers have no metadata service to talk to.
  systemd.services.amazon-init.enable = lib.mkForce false;
  systemd.services.fetch-ec2-metadata.enable = lib.mkForce false;
  systemd.services.apply-ec2-data.enable = lib.mkForce false;

  # growpart grows the EC2 root partition; the test driver hands the VM a
  # whole-disk filesystem with no partition table, so it has nothing to do.
  systemd.services.growpart.enable = lib.mkForce false;

  # test-instrumentation.nix owns the serial console under the test driver.
  systemd.services."serial-getty@ttyS0".enable = lib.mkForce false;

  # qemu-vm.nix turns timesyncd off because the VM takes its clock from the
  # host. The contract requires a synchronised clock, so turn it back on and
  # let it talk to the gateway node. Skipped when the image picked another NTP
  # client, which owns the option itself.
  services.timesyncd.enable = lib.mkIf (!config.services.chrony.enable) (lib.mkForce true);

  virtualisation.diskSize = lib.mkDefault 4096;
  virtualisation.memorySize = lib.mkDefault 1024;
}
