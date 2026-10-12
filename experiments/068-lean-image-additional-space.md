# 068 to 071: how big the image really is

One accepted experiment and three rejected ones, which together answer a
question this lab had been assuming an answer to.

- **Track:** appliance
- **Module:** `smol.leanImage.additionalSpace` (#68); #69 to #71 left no
  module behind
- **Source:** found by lab, backlog item `e16`

## Where it started

The closure was 278.50 MiB and the image 400.10 MiB. 120 MiB of the
difference had never been explained, and `make-disk-image` sizes with
`diskSize = "auto"` plus `additionalSpace`, which `smol.leanImage` had set
to `128M` since #25. Cutting the slack looked like ~96 MiB.

## #68: additionalSpace 128M to 32M

Accepted, and it bought **2.00 MiB**, not 96.

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 278.50 | 278.50 | 0          |
| image, raw | 400.10 | 398.10 | 2.00, 0.5% |

Gate 1 and gate 2 pass; boot 12.76s. Contract check 9 is the one that
matters, and `growpart` still expands the root to the 8 GiB volume the
launch sizes.

## #69 and #70: 1 KiB blocks

The automatic sizing charges two filesystem blocks per inode:

```sh
diskUsage=$(( (diskUsage + 2 * numInodes) * ${blockSize} ))
```

The accepted closure has **13016 files**, so at 4096 bytes that term alone
is 101.7 MiB. At 1024 it would be 25.4.

#69 was rejected by the protocol: `${cfg.blockSize}` interpolated an
integer into a string, the image did not build, and the check added after
#56 caught it instead of logging a 100% saving.

#70 built the image and the image build failed inside the VM:

```
grub-install: error: cannot copy ... No such file or directory
```

The estimate shrank, the filesystem's own metadata did not shrink with it,
and the bootloader step ran out of room.

## #71: one block per inode instead of two

Rejected: **neither measure moved**. The image came out at exactly the
same apparent size, and 64 KiB smaller in allocated bytes.

## What all of this established

`qemu-img convert -O vpc` writes a **sparse** VHD, and the `vpc` format
rounds the virtual size to a CHS geometry. So:

- the apparent size this lab records jumps in steps of about 2 MiB, which
  is the quantisation #58 and #61 had already seen from both sides;
- the bytes that actually exist are the bytes the filesystem holds;
- the automatic sizing only has to be *large enough*. Making it tighter
  wins nothing and eventually breaks the build.

Measured on the two images from #71:

| | apparent | allocated |
| --- | --- | --- |
| accepted | 417438208 | 396668928 |
| candidate | 417438208 | 396603392 |

The image is its contents. There is no image-side lever left that is not
also a closure-side lever, and `BACKLOG.md` items `e3` and `e6` are now
the only two that could change that: a compressed store, or a compressed
upload. `gzip` of the current VHD is 161 MiB against 398 apparent, so the
compression is there to be had; VM Import will not accept it, which is
what `e6` has to answer.

## Decision

#68 accepted. #69, #70 and #71 rejected, and the two options they added to
`smol.leanImage` were removed again: a knob that cannot move a number does
not belong in the module.
