# e15: where the twenty seconds went

Backlog item `e15` asked why boot time fell from 34.4s at ledger #19 to
14.3s at #25, when #25 was an image-only strategy. The answer is that it
did not fall because of #25, and the record cannot say what it did fall
for.

Three deploys, same closure, everything held constant except the image.
No ledger lines: nothing was measured that a strategy could be accepted or
rejected on, and BRIEFING §12 keeps the ledger for that.

## What was tested

| image | virtual size | VHD file | boot |
| ----- | ------------ | -------- | ---- |
| accepted, auto-sized, no channel | ~390 MiB | 398 MB | **13.30s** |
| same closure, `diskSize = "4096"` | 4 GiB | 438 MB | **13.44s** |
| same closure, `diskSize = "4096"` *and* `copyChannel = true` | 4 GiB | **1002 MB** | **14.17s** |

A fourth run of the accepted image an hour later: **14.14s**.

The two hypotheses `e15` was written on are both refuted:

- **Geometry.** A 4 GiB filesystem instead of a 390 MiB one costs 0.14s,
  which is inside the run-to-run spread. EBS volumes restored from a
  snapshot are lazily loaded, so a bigger volume looked like a plausible
  cost. It is not one at this size.
- **The channel.** 604 MB of extra files, some 40000 of them, costs
  0.03s against the accepted image measured the same way. Whatever the
  nixpkgs source in the image does, it does not slow the boot down.

## What the boot actually is now

```
Startup finished in 1.659s (kernel) + 3.613s (initrd) + 8.868s (userspace) = 14.141s

5.680s dhcpcd.service
4.430s sys-devices-virtual-dmi-id.device
4.388s sys-module-configfs.device
4.384s dev-ttyS2.device        (and ttyS0, ttyS1, ttyS3, all ~4.38s)
4.269s dev-nvme0n1p1.device
```

The machine spends its userspace time waiting for dhcpcd to get a lease
and for a handful of device units to settle. Both are the same on the
image with the channel, which is what makes the comparison clean.

## Why the original question cannot be answered

The pre-#25 ledger lines have a total and nothing else. The lab recorded
`systemd-analyze`'s single number and threw the breakdown away, so there
is no way back to which service cost those twenty seconds, and the system
that ran them differed from today's by twenty-six accepted strategies.

The plausible remaining explanation is that the time was in userspace
services that have since been removed: `register-nix-paths` loading a
database with the channel's paths in it, the SSM agent, and the units that
came with the 57 packages `smol.minimalSystemPackages` later cut to 16.
That is a hypothesis and it is not in the ledger, so it is not a result.

`lab/deploy-ec2.sh` now appends `systemd-analyze` and
`systemd-analyze blame` to every gate 2 log, so the next time a number
moves, the lab will know where it moved.

## Decision

`e15` closed as **not reproducible**, with the measurements above.
