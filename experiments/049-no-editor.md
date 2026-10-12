# 049: no-editor

- **Track:** appliance
- **Contract:** none exercised
- **Module:** `smol.noEditor`
- **Source:** found by lab, exp #49, while retracing `FLOOR.md`'s undecided paths

## Hypothesis

`file-5.48` is 10.54 MiB of libmagic and `FLOOR.md` recorded its holder as
`fetch-ec2-metadata.service`. Retracing it with `nix why-depends --all`
found a second, shorter path: `programs.nano` writes `/etc/nanorc`, nano
links `file`, and `/etc/nanorc` is in the system closure whether or not
nano is on anyone's PATH. `smol.minimalSystemPackages` (#31) took nano off
the system path but could not take it out of the closure, because the etc
entry holds it independently.

Expected roughly 12 MiB if nano were `file`'s only holder.

## What changed

[`modules/smol/no-editor.nix`](../modules/smol/no-editor.nix): a single
`programs.nano.enable = false`, with `system.forbiddenDependenciesRegexes =
[ "-nano-" ]` as the regression guard.

## Numbers

| measure    | before | after  | delta       |
| ---------- | ------ | ------ | ----------- |
| closure    | 347.40 | 344.90 | 2.50, 0.7%  |
| image, raw | 482.12 | 478.12 | 4.00, 0.8%  |

Paths that moved: `nano-8.6` and its own small inputs. **`file-5.48` did
not move.** That is the whole result of this experiment: it proved the
second holder is real and that it is the one that matters.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 12.92s, down from 14.13s at #48, which is inside the spread
these measurements have shown all along and is not claimed as a saving.

Teardown: instance, AMI and snapshot destroyed by `lab/deploy-ec2.sh`'s
trap; `STATE.md` live-resource table empty.

## Decision

Accepted. Both gates pass and both numbers went down, but it bought a fifth
of what the `FLOOR.md` line suggested, because `file` has a second holder.
Experiment 50 goes after that one.

## Surprises

`FLOOR.md` recorded one holder per path, from a single `nix why-depends`
run without `--all`. That reads as *the* reason a path is in the closure
when it is only *a* reason. Three of the undecided rows had changed holders
since they were written. Copied to `GOTCHAS.md`: trace with `--all`, and
re-trace before acting on a holder recorded in an earlier experiment.
