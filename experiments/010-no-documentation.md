# 010: no-documentation

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noDocumentation`
- **Source:** natkr, backlog item `n1`

## Hypothesis

First item on natkr's list, and the first prior-art replay this lab has run.
`documentation.enable = false` removes man pages, info pages, docbook
documentation and the generated NixOS manual. Nothing on a headless
appliance reads any of it.

## What changed

```nix
documentation.enable = false;
```

## Numbers

| measure           | before        | after         | delta         |
| ----------------- | ------------- | ------------- | ------------- |
| closure           | 1 002 256 328 | 903 873 504   | 98 382 824    |
| closure, MiB      | 955.86        | 861.99        | 93.87, 9.8%   |
| image, raw VHD    | 1 805 258 752 | 1 706 692 608 | 98 566 144    |
| image, MiB        | 1721.49       | 1627.49       | 94.00, 5.5%   |

natkr reports this as part of an ISO going from 458 to 183 MiB, without a
per-step breakdown, so there is no published figure to compare against. 93.87
MiB on a 955.86 MiB system is a larger share than it would have been on the
baseline, which is what the replay order does to percentages: run the same
step later and it looks bigger.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **36.405s**, down from 38.080s.

Three consecutive measurements now: 40.0s, 38.1s, 36.4s. That is a trend
rather than noise, and it is worth saying plainly that the lab did not
predict it. Documentation is not read at boot, so a 1.7s improvement from
removing it is not obviously explicable by less work being done. The more
likely cause is a smaller `/nix/store` to scan and fewer paths for
systemd-tmpfiles and the activation script to walk. Worth a dedicated
measurement later rather than a guess now.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass, closure down 9.8%.

Profile: `safe` and `aggressive`. An image that nobody logs into to read a
man page loses nothing, and a production base image is exactly that.

## Surprises

None in the result. One in the context: this is the first prior-art item run,
and it came tenth. The first six accepted strategies were all platform
defaults that neither natkr nor siraben could have seen, because an ISO has
no EC2 module. Replaying the published list first would have been the
obvious plan and the slower one.
