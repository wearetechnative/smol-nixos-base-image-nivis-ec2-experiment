# 005: no-installer-tools

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noInstallerTools`
- **Source:** found by lab, experiments 003 and 005

## Hypothesis

Experiment 003's regression guard showed that
`system.disableInstallerTools` could not remove `nixos-rebuild` while
`virtualisation.amazon-init` referenced it. Experiment 004 removed
amazon-init. This is the retry: with that reference gone, the option should
now drop `nixos-rebuild` and the 136.55 MiB CPython behind it.

## What changed

Unchanged from experiment 003, plus an assertion:

```nix
assertions = [
  { assertion = config.smol.track == "appliance"; ... }
  { assertion = config.smol.noAmazonInit.enable; ... }
];
system.disableInstallerTools = true;
system.forbiddenDependenciesRegexes = [ "nixos-rebuild" ];
```

The second assertion encodes experiment 003's finding, so nobody has to
rediscover it. BRIEFING §5 asks for an assertion rather than silently
enabling the other strategy, which is what this is.

## Numbers

| measure           | before        | after         | delta        |
| ----------------- | ------------- | ------------- | ------------ |
| closure           | 1 274 437 472 | 1 261 504 056 | 12 933 416   |
| closure, MiB      | 1215.40       | 1203.06       | 12.34, 1.0%  |
| image, raw VHD    | 2 081 009 664 | 2 068 426 752 | 12 582 912   |
| image, MiB        | 1984.49       | 1972.49       | 12.00, 0.6%  |

**The hypothesis was half wrong.** `nixos-rebuild` is gone, confirmed by the
guard passing, but the saving is 12.34 MiB rather than the 136.55 MiB that
CPython weighs. So CPython is still there, held by something else.

`nix why-depends` on the result:

```
nixos-system
└── etc/udev/rules.d -> udev-rules
    └── 51-ec2-hvm-devices.rules: KERNEL=="xvd*", PROGRAM=".../amazon-ec2-utils-2.2.0/bin/ec2u…
        └── bin/ebsnvme-id: #!/nix/store/...-python3-3.14.7/bin/python3
```

`amazon-ec2-utils` ships `ebsnvme-id`, a Python script, and
`51-ec2-hvm-devices.rules` runs it to map `xvd*` device names onto NVMe
devices. One udev rule, one Python script, a 136.55 MiB interpreter.

This is BRIEFING §2's warning made concrete: the published ISO floors never
had to carry EC2 device-naming machinery. New backlog item `e8`.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Instance `i-0671018db14d57d9c`, AMI `ami-0ef00007ae697cf4f`.

Ten checks on first boot, ten after reboot. Boot time **40.034s**, the
fastest so far, though the spread across experiments is under two seconds
and none of it is yet distinguishable from noise.

Teardown: all six resources destroyed.

## Decision

**Accepted.** 1.0% is small, but both gates pass and the system can no longer
be rebuilt in place, which is what the appliance track means. Keeping
`nixos-rebuild` out also keeps the guard in place, so it cannot drift back.

Profile: `aggressive` only. A production base image that is updated in place
needs this tool.

## Surprises

A 12.34 MiB result against a 136.55 MiB hypothesis is the useful kind of
wrong. Without checking `why-depends` afterwards, the obvious reading is "the
option worked, CPython must have been smaller than it looked". It had not
worked in the way intended at all, and the real holder of CPython is an EC2
device-naming utility that no ISO-shrinking exercise would ever have met.

Worth generalising: **the ledger's delta column does not explain itself.**
Re-run `why-depends` on the target path after every experiment aimed at a
specific dependency, not only when the result looks wrong.
