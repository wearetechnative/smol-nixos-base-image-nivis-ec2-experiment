# 061: no-bash-completion

- **Track:** appliance
- **Contract:** 1 (the whole contract reruns; `lab/verify.sh` is `sh`)
- **Module:** `smol.noBashCompletion`
- **Source:** backlog item `e25`

## Hypothesis

`programs.bash.completion.enable` defaults to true and `/etc/bashrc`
sources `bash-completion-2.18.0`, 1.21 MiB. The etc entry holds it whether
or not anyone ever presses tab, and this machine is driven by a script
over SSH.

## What changed

[`modules/smol/no-bash-completion.nix`](../modules/smol/no-bash-completion.nix):
`programs.bash.completion.enable = false`, guarded with
`"-bash-completion-"`.

## Numbers

| measure    | before | after  | delta        |
| ---------- | ------ | ------ | ------------ |
| closure    | 298.51 | 297.26 | 1.25, 0.4%   |
| image, raw | 422.11 | 424.11 | **-2.00**    |

The image got *bigger* by 2 MiB while the closure shrank by 1.25.
`make-disk-image` sizes the volume with `diskSize = "auto"` plus 128 MiB
of slack and then rounds, so image size is quantised and not monotone in
closure size. Experiment 58 saw the other half of the same effect: 2.84
MiB of closure left and the image did not move at all.

This is the first accepted experiment where one of the two measures went
the wrong way. `lab/experiment.sh` accepts on either measure improving,
which is the rule BRIEFING §8.3 sets, and the closure is the honest result
here.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.55s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. 1.25 MiB, with an image that rounded upward.

## Surprises

The image measurement has a granularity of about 2 MiB and the lab has now
seen it in both directions. Anything smaller than that in the image column
should be read as noise, and `REPORT.md` should say so.
