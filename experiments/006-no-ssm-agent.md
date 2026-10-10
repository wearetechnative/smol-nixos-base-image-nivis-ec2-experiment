# 006: no-ssm-agent

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noSsmAgent`
- **Source:** found by lab, from `nix why-depends` on the baseline

## Hypothesis

`amazon-ssm-agent-3.3.5226.0` is 110.09 MiB, the fourth largest path in the
baseline. `virtualisation/amazon-image.nix` enables it by default, and
`nix why-depends` shows it held by a single config file:

```
nixos-system
└── etc/amazon/ssm/amazon-ssm-agent.json -> amazon-ssm-agent-3.3.5226.0/...
```

It is a Go binary providing Session Manager, Run Command, inventory and
patch reporting to instances managed through AWS Systems Manager. The lab
verifies over SSH and uses none of it.

## What changed

```nix
services.amazon-ssm-agent.enable = lib.mkForce false;
system.forbiddenDependenciesRegexes = [ "amazon-ssm-agent" ];
```

## Numbers

| measure           | before        | after         | delta         |
| ----------------- | ------------- | ------------- | ------------- |
| closure           | 1 261 504 056 | 1 145 813 008 | 115 691 048   |
| closure, MiB      | 1203.06       | 1092.73       | 110.33, 9.2%  |
| image, raw VHD    | 2 068 426 752 | 1 948 912 640 | 119 514 112   |
| image, MiB        | 1972.49       | 1858.49       | 114.00, 5.8%  |

The delta matches the package's own size almost exactly, which is what a
clean single-consumer removal looks like. Contrast experiment 005, where it
did not.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Instance `i-01f40d7523043af98`, AMI `ami-098652af85630340c`.

Ten checks on first boot, ten after reboot. Boot time **40.063s**.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass, closure down 9.2%.

Profile: `aggressive` only, and this one deserves a warning rather than a
default. A production fleet managed through Systems Manager loses Session
Manager access, Run Command and patch reporting. For a base image at
wearetechnative that is a question for whoever owns the fleet, not a saving
the lab should bank on their behalf. It belongs in `REPORT.md`'s
recommendations as an explicit "only if you do not use SSM".

## Surprises

None. This is the uninteresting kind of experiment: a default that was never
examined, holding 110 MiB for a service nobody in this lab uses.

Worth noting what it says about the baseline, though. `amazon-ssm-agent`,
`amazon-init` and the flake registry are all **defaults of the platform
rather than of NixOS**. Together they accounted for 421 MiB of the 1516 MiB
baseline, and none of them appear on the natkr or siraben lists, because an
ISO has no platform. The first quarter of this lab's savings came from
auditing what the EC2 module turns on, not from any published technique.
