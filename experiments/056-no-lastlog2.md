# 056: no-lastlog2

- **Track:** appliance
- **Contract:** 7 (`findmnt` lives in the same package)
- **Module:** `smol.noLastlog.withLastlog2`
- **Source:** found by lab, exp #56, revisiting why #19 measured nothing

## Hypothesis

Experiment 19 turned off PAM's lastlog module and saved 3344 bytes, with
`sqlite-3.53.3` at 5.90 MiB still in the closure. The referrer dump says
why: sqlite is referenced by `util-linux-bin`, `util-linux-lib` and
`util-linux-lastlog`, not by anything in PAM. The holder was never the PAM
configuration, it was the util-linux build, which ships `liblastlog2`
whatever `/etc/pam.d` says. `lslogins` links it.

## What changed

A second option on the module that owns the question, defaulting to the
behaviour `accepted` had so the two could be compared:

```nix
util-linux = prev.util-linux.override { withLastlog = false; };
```

which configures with `--disable-liblastlog2 --disable-pam-lastlog2`.
sqlite stays a `buildInput` upstream, unconditionally, but nothing in the
built package references it any more, so it leaves the closure.

Its default is `false` now that it has been measured.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 313.04 | 307.24 | 5.80, 1.9% |
| image, raw | 440.11 | 432.11 | 8.00, 1.8% |

`sqlite-3.53.3` left. This is siraben's reported `s8` saving, three and a
half years and thirty-seven experiments after it was first tried here.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.94s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted.

## Surprises

The image number in ledger line 56 was written as 0 and corrected
afterwards. Overriding util-linux rebuilds everything downstream of it,
QEMU included, and QEMU pulls pipewire, whose `test-context` suite timed
out while the machine was running a NixOS test at the same time. The
measure step recorded no image; gate 2 rebuilt it successfully minutes
later and passed. Both images were then rebuilt and `stat`-ed from the same
store paths gate 2 used, and the ledger line carries a `note` field saying
so.

Two things follow. `lab/measure.sh` returns 0 for an image it could not
build, which is indistinguishable from an image that shrank to nothing, and
`lab/experiment.sh` accepted a 100% image saving without blinking. That is
a protocol defect, and it is in `BACKLOG.md` as `e16`.
