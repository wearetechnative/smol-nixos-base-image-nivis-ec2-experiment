# 013: no-kernel-modules

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noKernelModules`
- **Source:** natkr, backlog item `n7`

## Hypothesis

Experiment 012 established that the 145.17 MiB lives in the module *tree*,
not the kernel image, and that the tree is reachable from the system closure
through one symlink:

```
toplevel/kernel-modules -> /nix/store/...-linux-6.18.55-modules
```

An EC2 instance loads what it needs from the initrd, which carries its own
copy of ENA and NVMe, and then never loads another module. Remove the
symlink and the tree leaves the closure without recompiling anything.

## What changed

```nix
system.systemBuilderCommands = lib.mkAfter ''
  rm -f $out/kernel-modules
'';
```

`mkAfter` is load-bearing. Without it the removal merges *before*
`kernel.nix`'s own `ln -s`, which puts the symlink straight back, and the
build succeeds while changing nothing. The first attempt did exactly that and
the closure was unchanged.

## Numbers

| measure      | before      | after       | delta          |
| ------------ | ----------- | ----------- | -------------- |
| closure      | 900 314 800 | 739 768 336 | 160 546 464    |
| closure, MiB | 858.60      | 705.50      | 153.10, 17.8%  |

**The largest single saving in the lab so far**, and larger than the module
tree itself: removing it also takes `linux-firmware` and the module
dependency metadata with it.

## Gate 1, local

**Fail**, on two checks:

```
not ok 2 - systemctl is-system-running = running
  # got: degraded
not ok 3 - no failed units
  # firewall.service
```

Netfilter is modular. With no module tree, `firewall.service` cannot load
`nf_tables` and friends, so it fails, and the system reports `degraded`
rather than `running`.

Everything else passed, including the root filesystem, DNS, HTTPS and NTP.
The machine boots and works; it just cannot bring up a packet filter.

## Gate 2, EC2

Not reached. No AWS resources created, so this cost a local test and nothing
else.

## Decision

**Rejected: gate 1 failed.** The strategy is sound and the saving is real;
the implementation was incomplete.

Split, per BRIEFING §5's rule that a strategy needing another asserts rather
than silently enabling it:

- `smol.noFirewall`, experiment 014, which is a security trade-off and
  deserves to be decided on its own merits rather than smuggled in as a
  side effect of a size optimisation.
- `smol.noKernelModules`, retried afterwards, now asserting
  `!networking.firewall.enable` with a message naming this experiment.

## Surprises

This is the clearest case so far for gate 1 existing. A 153 MiB saving that
boots, serves SSH, resolves DNS and passes nine of ten checks is exactly the
kind of change that gets waved through. The contract's "no failed units" is
what caught it, locally, for free, before an AMI was ever registered.

It is also the first time a size strategy has turned out to have a
**security** consequence rather than a functional one. The honest framing is
not "dropping modules costs 153 MiB of nothing" but "dropping modules means
giving up the in-guest firewall", and that belongs in front of whoever
chooses the profile, not in a footnote.
