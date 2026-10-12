# 074: no-procps

- **Track:** appliance
- **Contract:** every check reruns; none of them calls `ps`
- **Module:** `smol.minimalSystemPackages.withProcps`
- **Source:** found by lab, exp #74, from `FLOOR.md`'s referrer table

## Hypothesis

`procps-4.0.7` is 2.32 MiB and `system-path` is its only referrer, so it
is on the image for a person who has logged in: `ps`, `free`, `uptime`,
`sysctl`. Nothing on the appliance calls any of them and neither does
`lab/verify.sh`. `systemctl status` answers the same questions through PID
1, which is where this machine's processes live.

## What changed

A `withProcps` option on `smol.minimalSystemPackages`, defaulting to the
behaviour `accepted` had so the two differed by exactly it, now `false`.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 271.81 | 269.48 | 2.33, 0.9% |
| image, raw | 392.10 | 386.10 | 6.00, 1.5% |

`systemd-minimal-libs` did not leave with it: `dhcpcd` and `linux-pam`
reference it too.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.48s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. Under 1% and under 3 MiB, which is the third of the last four
and is what BRIEFING §9's first stop criterion is watching for.
