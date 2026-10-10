# 004: no-amazon-init

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noAmazonInit`
- **Source:** found by lab, after experiment 003's dependency guard failed

## Hypothesis

Experiment 003 established that `virtualisation.amazon-init` holds a
reference to `nixos-rebuild` through its service PATH, which is why
`system.disableInstallerTools` alone could not remove it. Removing
amazon-init should drop that reference, along with the other tools it puts on
that PATH: git, gnutar, gzip, xz and gnused.

amazon-init reads EC2 user-data and, when it looks like a NixOS
configuration, applies it with `nixos-rebuild switch`. The appliance track
replaces the AMI instead, so the mechanism has no user here.

## What changed

```nix
virtualisation.amazon-init.enable = lib.mkForce false;
```

`mkForce` because `virtualisation/amazon-image.nix` enables it at normal
priority.

## Numbers

| measure           | before        | after         | delta         |
| ----------------- | ------------- | ------------- | ------------- |
| closure           | 1 380 449 624 | 1 274 437 472 | 106 012 152   |
| closure, MiB      | 1316.50       | 1215.40       | 101.10, 7.7%  |
| image, raw VHD    | 2 196 328 448 | 2 081 009 664 | 115 318 784   |
| image, MiB        | 2094.52       | 1984.49       | 110.03, 5.3%  |

The upload time fell with it, from 2m52s on the baseline to 2m09s, which is
the first direct evidence that shrinking the image shortens the experiment
loop as well as the artefact.

CPython is still present after this experiment: `nixos-rebuild` remains in
`environment.systemPackages` through `system.tools.nixos-rebuild.enable`.
That is what experiment 005 removes. The 101.10 MiB here is amazon-init's
*other* PATH entries.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Instance `i-0865252bca92995f4`, AMI `ami-012e17993b2cab5a2`.

Ten checks on first boot, ten after reboot. Boot time **41.858s**, against
40.753s for the baseline. Slower by a second, which is noise at this sample
size; worth watching if it keeps drifting upward.

The important negative result: **check 1 still passes**. SSH key injection
survives the removal of amazon-init, because the key comes from
`ec2-metadata-fetcher`, a different service. The two are easy to conflate,
and conflating them would have cost the contract.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass, closure down 7.7%.

Profile: `aggressive` only, not `safe`. Dropping user-data execution removes
a mechanism a production fleet may well depend on for launch-time
configuration, and that is a decision for whoever adopts the profile rather
than one the lab should make for them.

## Surprises

None beyond what experiment 003 already established. Worth recording the
negative result explicitly, because it is the kind of thing that gets assumed
rather than checked: **amazon-init is not what injects the SSH key.** That is
`ec2-metadata-fetcher`. Removing amazon-init leaves contract check 1 passing.
