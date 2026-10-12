# 058: slim-curl

The accepted run. Its two failed predecessors are written up in
[`057-slim-curl.md`](057-slim-curl.md), and they are most of the story.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.slimCurl`
- **Source:** backlog item `e23`

## What changed

[`modules/smol/slim-curl.nix`](../modules/smol/slim-curl.nix) builds curl
without GSSAPI at all three places that reference it, and overrides the
two consumers rather than curl itself:

```nix
smol.noUserDataDecompression.curl = pkgs.curl.override { gssSupport = false; };

nixpkgs.overlays = [
  (final: prev: {
    systemd = prev.systemd.override { curl = final.curl.override { gssSupport = false; }; };
    amazon-ec2-utils = prev.amazon-ec2-utils.override { curl = final.curl.override { gssSupport = false; }; };
  })
];
```

`final.curl` is still the stock attribute, so `pkgs.curl` is byte-identical
in `accepted` and `candidate` and the lab builds one curl instead of LLVM,
clang, mesa and QEMU. That distinction is the whole content of experiment
57.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 307.24 | 304.39 | 2.84, 0.9% |
| image, raw | 432.11 | 432.11 | 0, byte-identical |

`krb5-1.22.2-lib` left. The image did not move at all: `make-disk-image`
sizes the volume with `diskSize = "auto"` plus 128 MiB, and 2.84 MiB
disappears inside that rounding. It is the first accepted experiment whose
image is the same size to the byte, which is worth noticing rather than
hiding: the closure is what shrank.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 13.61s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. 2.84 MiB for three package rebuilds, after two attempts that cost
most of a day between them.
