# 014: no-firewall

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noFirewall`
- **Source:** found by lab, experiment 013

## Hypothesis

Not a size hypothesis. Experiment 013 showed that removing the kernel module
tree leaves `firewall.service` unable to load netfilter, so the contract's
"no failed units" check fails. The firewall has to go first, and that is a
decision worth making explicitly rather than smuggling in as a side effect of
a size optimisation.

On EC2 the security group is already a stateful packet filter, enforced
outside the guest and unaffected by anything happening inside it.

## What changed

```nix
networking.firewall.enable = false;
```

## Numbers

| measure      | before      | after       | delta        |
| ------------ | ----------- | ----------- | ------------ |
| closure      | 900 314 800 | 892 396 888 | 7 917 912    |
| closure, MiB | 858.60      | 851.07      | 7.53, 0.9%   |

Small on its own. It exists to unlock experiment 017's 152.93 MiB.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **36.249s**. Teardown: all six resources destroyed.

## Decision

**Accepted**, profile `aggressive` only, with a warning in the option
description rather than a one-line trade-off note.

This is the first strategy in this lab whose cost is **security** rather than
functionality or convenience. The instance has no defence of its own. A
misconfigured security group is no longer caught by a second layer, and
anything listening on an unexpected port is reachable from wherever that
group allows.

On a machine whose only listening service is sshd, behind a group permitting
only 22, that is defensible. It is not something anyone should inherit by
enabling a profile without reading what is in it, and `REPORT.md` should say
so in the recommendations rather than in a table.

## Surprises

None technically. The surprise is structural: a size experiment turned into a
security decision, and the protocol handled it correctly by forcing it into
its own module with its own assertion, instead of letting
`smol.noKernelModules` quietly turn the firewall off as part of its
implementation.
