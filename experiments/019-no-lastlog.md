# 019: no-lastlog

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noLastlog`
- **Source:** siraben, backlog item `s8`

## Hypothesis

siraben reports that turning lastlog off drops sqlite. `programs/shadow.nix`
enables PAM's lastlog for the `login` service, which pulls in
`pam_lastlog2.so`, sqlite, a tmpfiles fragment and a
`lastlog2-import.service`.

It was also needed as a prerequisite: experiment 018 could not build
util-linux without systemd support while NixOS expected a tmpfiles fragment
from util-linux's `lastlog` output.

## What changed

```nix
security.pam.services.login.lastlog.enable = lib.mkForce false;
```

`login` is the only service with it enabled; the option's own default is
`false`.

## Numbers

| measure      | before      | after       | delta       |
| ------------ | ----------- | ----------- | ----------- |
| closure      | 732 042 408 | 732 039 064 | 3 344 bytes |

**3 344 bytes.** Effectively nothing, against a reported saving that
included sqlite. sqlite does not leave: something else in the closure holds
it, and this experiment did not find out what. That is a loose end, and it
belongs in `BACKLOG.md` rather than being quietly forgotten.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **34.391s**, the fastest recorded, though the spread across
experiments is wide enough that this means little on its own.

Teardown: all six resources destroyed.

## Decision

**Accepted**, on the letter of the rule: both gates pass and the closure went
down. It is the third prior-art replay in a row to under-deliver, and at 3
344 bytes it is comfortably inside BRIEFING §9's stop-criterion band.

Its real value is as a prerequisite for `smol.noDuplicateSystemd`, and that
is what the option description says.

## Surprises

A saving three orders of magnitude smaller than expected is worth the same
follow-up as a saving that is merely smaller: find out why. The answer is
that sqlite has another holder, which this experiment did not chase. Logged
as a backlog item rather than left as a footnote.
