# 073: c-locale-only

- **Track:** appliance
- **Contract:** every check; `LANG` changes for every process on the machine
- **Module:** `smol.cLocaleOnly`
- **Source:** siraben, backlog item `s7`

## Hypothesis

`glibc-locales-2.44-25` is 2.93 MiB and every unit references it, because
NixOS puts `LOCALE_ARCHIVE` in systemd's manager environment. The archive
is built from `i18n.supportedLocales`, which was `C.UTF-8` *and*
`en_US.UTF-8`.

Nothing on this image reads a message catalogue: there is no
documentation since #10, no interactive tooling beyond a shell, and
`lab/verify.sh` compares bytes rather than translated strings.

## What changed

[`modules/smol/c-locale-only.nix`](../modules/smol/c-locale-only.nix):

```nix
i18n.defaultLocale = lib.mkForce "C.UTF-8";
i18n.supportedLocales = lib.mkForce [ "C.UTF-8/UTF-8" ];
```

## Numbers

| measure    | before | after  | delta        |
| ---------- | ------ | ------ | ------------ |
| closure    | 274.27 | 271.81 | 2.46, 0.9%   |
| image, raw | 386.10 | 392.10 | **-6.00**    |

The locale archive shrank; the image rounded up a step. That is the
sparse, CHS-rounded VHD from #68 to #71 again, and it is the second time
an accepted experiment has read larger on the image while the closure
fell. The closure is the honest number for a change of this size.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 15.16s, unchanged from #72 within the spread.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted.
