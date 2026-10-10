# 009: no-python

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noPython`
- **Source:** found by lab, experiments 005, 007 and 008

## Hypothesis

Experiment 008's tree, unchanged, against a gate 1 harness that can handle a
strategy installing an overlay. Remove the two Python scripts in an EC2
NixOS image and the 136.55 MiB CPython interpreter goes with them.

## What changed

Nothing in the candidate. The fix was in `lab/test-local.nix`:

```nix
node.pkgsReadOnly = false;
```

`runNixOSTest` otherwise hands each node a prebuilt `pkgs`, which makes
`nixpkgs.overlays` an error rather than a merge.

## Numbers

| measure           | before        | after         | delta          |
| ----------------- | ------------- | ------------- | -------------- |
| closure           | 1 145 813 008 | 1 002 256 328 | 143 556 680    |
| closure, MiB      | 1092.73       | 955.86        | 136.87, 12.5%  |
| image, raw VHD    | 1 948 912 640 | 1 805 258 752 | 143 653 888    |
| image, MiB        | 1858.49       | 1721.49       | 137.00, 7.4%   |

**Under a gibibyte.** 955.86 MiB against the 1516.25 MiB baseline, 37.0%
down, across six accepted strategies.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Instance `i-07ce2f57f75633b2a`, AMI `ami-06679152227a949d4`.

Ten checks on first boot, ten after reboot. Boot time **38.080s**.

That is the first boot-time change in this lab worth remarking on. The five
runs before it sat between 40.03s and 41.86s; this one is a clear 2s faster
and outside that spread. The plausible cause is `growpart.service` no longer
starting a wrapped Python binary during early boot, though a single sample
cannot establish it. Worth re-checking once more strategies land: if boot
time keeps falling, it becomes a second axis worth reporting.

The device-naming checks that this strategy puts at risk all held. The root
filesystem is found by label, so losing the `/dev/sdX` symlinks on NVMe cost
nothing, and `growpart` itself still ran: check 9 reports a 4 GiB root
filesystem on a 4 GiB volume, which is the partition having been grown.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass, closure down 12.5%.

Profile: `aggressive` only. It asserts `smol.noInstallerTools`, which is
already `aggressive`, and losing EBS attachment-name symlinks is a real
constraint on any configuration that mounts a secondary volume by the name it
was attached under.

## Surprises

The hunt took four rounds of `nix why-depends`, and three of those looked
finished at the time. `nixos-rebuild` in `systemPackages`, `nixos-rebuild` on
amazon-init's service PATH, `ebsnvme-id` in `amazon-ec2-utils`,
`ec2metadata` riding along with `growpart` in `cloud-utils`. Remove any three
and the interpreter stays, with the saving reading as near zero.

The generalisation for the rest of this lab: **a large path with several
holders looks like a small path with one.** Run `why-depends` again on the
result, not just on the baseline, and keep going until it returns nothing.
