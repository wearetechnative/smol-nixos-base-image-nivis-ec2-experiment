# 011: no-default-packages

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noDefaultPackages`
- **Source:** natkr, backlog item `n2`

## Hypothesis

natkr's second step. `environment.defaultPackages` is what NixOS installs on
every system whether or not anything asked: perl, rsync, strace and friends.
On an appliance nothing asks.

## What changed

```nix
environment.defaultPackages = lib.mkForce [ ];
```

## Numbers

| measure           | before      | after       | delta        |
| ----------------- | ----------- | ----------- | ------------ |
| closure           | 903 873 504 | 900 314 800 | 3 558 704    |
| closure, MiB      | 861.99      | 858.60      | 3.39, 0.4%   |

**3.39 MiB against an expectation in the tens.** The smallest accepted result
so far, and the second prior-art replay in a row to under-deliver against its
ISO context.

The reason is visible in what is left. `perl-5.42.3` is still in the closure
at 55.18 MiB after this experiment: removing it from `defaultPackages` does
not remove it, because something else on an EC2 system pulls it in anyway.
That is natkr's item `n8` territory, `system.etc.overlay` plus
`services.userborn`, and it is now clearly the right way to go after perl
rather than this.

The pattern from experiment 005 repeats: **a package with more than one
holder does not leave when one holder does.** The list is: nixos-rebuild
(four holders, experiments 3 to 9), perl (at least two, this one), and
presumably more.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **37.749s**, up from 36.405s.

That breaks the downward run of 40.0, 38.1, 36.4. With 37.7 the series reads
as noise around 37s rather than a trend, and the reading in experiment 010
that called it a trend was premature on three samples. Recorded here as a
correction: boot time has not been shown to respond to closure size.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass and the closure went down, which is the
standard. Worth flagging that at 0.4% this is the first result inside the
stop-criterion band of BRIEFING §9 ("saved less than 1% or less than 2 MiB"),
though at 3.39 MiB it clears the absolute threshold and one result does not
start the count.

Profile: `aggressive` only. A production base image where someone may need
`rsync` or `strace` to diagnose a problem should keep them.

## Surprises

Two prior-art replays run, two under-deliveries. Neither is wrong on its own
terms; both were measured on an ISO with no EC2 module, and the parts of
their saving that matter here were already gone or are held by something the
ISO never had. The order this lab happened to take, platform defaults first
and the published list second, makes the published steps look small.

The honest framing for `REPORT.md`: these numbers are not comparable to
natkr's, and presenting them side by side without that caveat would be
misleading.
