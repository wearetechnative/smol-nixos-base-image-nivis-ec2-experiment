# 072: xz-initrd

- **Track:** appliance
- **Contract:** every check, after a reboot the initrd has to come back from
- **Module:** `smol.xzInitrd`
- **Source:** backlog item `s4`, from BRIEFING §6

## Hypothesis

`initrd-linux-6.18.55` was 21.87 MiB, the fourth largest path in the
closure, and it is a compressed archive: its size is a compression ratio,
not a payload. NixOS compresses with zstd, which is fast to decompress and
compresses less than xz.

`-9 -e --check=crc32` is what the kernel documentation asks for. The check
matters: the kernel's xz decompressor has no CRC64, which is xz's default,
and an initrd the kernel cannot read is an unbootable machine.

## What changed

[`modules/smol/xz-initrd.nix`](../modules/smol/xz-initrd.nix), two NixOS
options:

```nix
boot.initrd.compressor = "xz";
boot.initrd.compressorArgs = [ "-9" "-e" "--check=crc32" ];
```

## Numbers

| measure    | before | after  | delta       |
| ---------- | ------ | ------ | ----------- |
| closure    | 278.50 | 274.27 | 4.23, 1.5%  |
| image, raw | 398.10 | 386.10 | 12.00, 3.0% |

The initrd itself: **21.87 to 17.64 MiB**, 19.3%.

## Gate 1, local

Pass, 10 of 10, including the reboot run.

## Gate 2, EC2

Pass. Boot **15.23s**, against 12.76s at #68.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted: both gates pass and both sizes went down. The cost is **2.5
seconds of boot time**, which is the first accepted experiment to make the
machine measurably slower, and the module says so.

Whether that is the right trade depends on how the image is used. An
appliance that is replaced rather than reconfigured boots once per deploy
and 4.23 MiB of closure is free. An autoscaling group boots it on every
scale-out, and there 2.5 seconds is the expensive half. `smol.xzInitrd` is
one option and it can be turned off without touching anything else, which
is the point of the module layout.

## Surprises

The image moved three times as much as the closure, 12.00 against 4.23.
That is the quantisation from #68 to #71 working in our favour this time:
the VHD is sparse and CHS-rounded, so a 4 MiB closure change can cross a
boundary and read as 12.
