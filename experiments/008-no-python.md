# 008: no-python

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noPython`
- **Source:** found by lab, experiments 005 and 007

## Hypothesis

Same target as experiment 007, correctly implemented and widened. Following
`nix why-depends` past `ebsnvme-id` turned up a fourth holder of CPython:

```
nixos-system
└── etc/systemd/system -> system-units
    └── growpart.service -> unit-growpart.service
        └── ExecStart -> unit-script-growpart-start
            └── bin/growpart-start: .../cloud-utils-0.33-guest/bin/grow…
                └── bin/.ec2metadata-wrapped: #!/nix/store/...-python3-3.14.7
```

`cloud-utils` ships `ec2metadata` in the same output as `growpart`, so
`growpart.service` drags it in. Removing `ebsnvme-id` alone would therefore
have saved nothing, which is why this is one strategy rather than two: the
136.55 MiB only materialises when every holder is gone.

## What changed

One overlay, two packages:

- `amazon-ec2-utils`: `preFixup` removes `bin/ebsnvme-id` and the two rules
  calling it; `doInstallCheck = false`.
- `cloud-utils`: `postFixup` removes `ec2metadata` and its wrapper, after the
  package's own `moveToOutput` and `wrapProgram` have run.

Plus an assertion on `smol.noInstallerTools`, since `nixos-rebuild` is a
third holder.

## Numbers

| measure      | before        | after       | delta          |
| ------------ | ------------- | ----------- | -------------- |
| closure      | 1 145 813 008 | 1 002 59x xxx | 143 2xx xxx  |
| closure, MiB | 1092.73       | 955.86      | 136.87, 12.5%  |

Measured, then discarded with the experiment: gate 1 never ran, so no result
here is confirmed. The number is carried forward to experiment 009, which is
the same tree with a fixed harness.

## Gate 1, local

**Fail**, and not for a reason the contract knows about:

```
error: The option `nodes.target.nixpkgs.overlays' is defined multiple times
while it's expected to be unique.
```

`pkgs.testers.runNixOSTest` hands each node a prebuilt `pkgs`, which makes
`nixpkgs.overlays` an error rather than a merge. This is the same trap as
passing a prebuilt `pkgs` to `nixosSystem`, which the briefing warns about
and the flake carefully avoids, reappearing one layer down inside the test
driver.

Fixed by setting `node.pkgsReadOnly = false` on the test.

## Gate 2, EC2

Not reached. No AWS resources created.

## Decision

**Rejected: gate 1 failed.** A harness defect, not a property of the
candidate. Retried as experiment 009 against the fixed harness.

## Surprises

This one was worth the rejected ledger line.

**Gate 1 was blocking every overlay-based strategy, and nothing had noticed**
because no strategy had used an overlay yet. Had this surfaced later it would
have blocked siraben's `s1`, `s2` and `s3`, the slim systemd, minimal
util-linux and trimmed dbus, which are the three largest items on the replay
list and all of which must be overlays to avoid a second full build.

The briefing's GOTCHAS seed says "`nixpkgs.overlays` is ignored when a
prebuilt `pkgs` is passed to `nixosSystem`". The flake was built to respect
that from the start. The lesson is that the warning applies to **every place
a NixOS configuration is instantiated**, and the test driver is one of them.
