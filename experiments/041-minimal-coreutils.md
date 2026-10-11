# 040 and 041: minimal-coreutils

Two ledger lines, one result. Accepted at #41.

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.minimalSystemPackages.fullCoreutils`
- **Source:** found by lab, listing the closure after experiment 39

## Hypothesis

Both `coreutils-9.11` and `coreutils-full-9.11` are in the closure. Other
things depend on the plain build, so asking for the full one in
`environment.systemPackages` adds 12 MiB of utilities nothing on this image
calls.

## Numbers

| measure      | before      | after       | delta        |
| ------------ | ----------- | ----------- | ------------ |
| closure      | 526 195 992 | 512 829 376 | 13 366 616   |
| closure, MiB | 501.82      | 489.07      | 12.75, 2.5%  |
| image, MiB   | 614.16      | 600.16      | 14.00, 2.3%  |

## Experiment 40: rejected, and the reason is about the protocol

The first attempt simply edited the package list in
`smol.minimalSystemPackages`, which `systems/accepted` already enables.

```
closure 489 MiB -> 489 MiB (0 MiB, 0.00%)
neither closure nor image is smaller than accepted
```

**Both sides of the comparison moved.** `lab/experiment.sh` measures the
candidate against the accepted system and both read the same module file, so
the delta was exactly zero while the saving was entirely real: `accepted`
went from 501.82 to 489 MiB with nothing in the ledger to say so, and no
gate had run against it.

That is the worst failure mode this protocol has, because it is silent. A
rejected experiment that still changes the accepted system puts an unmeasured,
ungated change into the tree and reports nothing.

The fix is an option. `fullCoreutils` defaults to `true`, the candidate sets
it `false`, and the two systems genuinely differ. After acceptance the
default flips, which is how promotion works for every other strategy here.

`CLAUDE.md` and `GOTCHAS.md` now both say this: a candidate must differ from
`systems/accepted` by something `accepted` does not already have.

## Gate 1, local

Pass at #41.

## Gate 2, EC2

Pass at #41. Boot time **12.999s**. Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive`, through `smol.minimalSystemPackages`.

## Surprises

The interesting part is not the 12 MiB. It is that a protocol built to make
every number traceable to a gated experiment had a hole in it, and the hole
only showed because the delta came out suspiciously round at zero. Had the
module edit also changed something else slightly, the experiment would have
been accepted and the ledger would have attributed the wrong saving to it.
