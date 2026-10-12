{ config, lib, ... }:
let
  cfg = config.smol.xzInitrd;
in
{
  options.smol.xzInitrd.enable = lib.mkEnableOption ''
    compressing the initrd with xz instead of zstd.

    `initrd-linux-6.18.55` is 21.87 MiB, the fourth largest path in the
    closure, and it is a compressed archive: its size is a compression
    ratio, not a payload. NixOS defaults to zstd, which decompresses
    quickly and compresses less than xz does.

    `-9 -e --check=crc32` is what the kernel's own documentation asks for.
    The CRC32 check matters: the kernel's xz decompressor does not
    implement CRC64, which is xz's default, and an initrd it cannot read
    is an unbootable machine.

    What it costs is boot time. xz decompression is single-threaded and
    slower than zstd by several times, and it happens before anything else
    does. Gate 2 measures the boot, so the trade is visible rather than
    assumed.

    Measured saving (appliance track, EC2): 4.23 MiB closure, 12.00 MiB
    raw image, ledger #72. The initrd went from 21.87 to 17.64 MiB.
    Trade-offs: **2.5 seconds of boot time**, 12.76s to 15.23s on a
    t3.micro, measured by gate 2. The
    appliance is replaced rather than reconfigured, so it boots once per
    deploy, but an autoscaling group boots it on every scale-out.
    Requires: nothing.
    Source: backlog item `s4`, from BRIEFING §6
  '';

  config = lib.mkIf cfg.enable {
    boot.initrd.compressor = "xz";
    boot.initrd.compressorArgs = [
      "-9"
      "-e"
      "--check=crc32"
    ];
  };
}
