# 026: no-nix

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noNix`
- **Source:** natkr, backlog item `n3`

## Hypothesis

Experiment 25 left `icu4c` at 39.69 MiB in the closure with no explanation,
which under BRIEFING §9.3 made it a backlog item rather than a floor entry.
Chasing it found something larger:

```
nixos-system
└── etc/tmpfiles.d/00-nixos.conf
    └── tmpfiles.d/nix-daemon.conf
        └── nix-2.34.8
```

**The appliance track still had Nix on it.** 162.9 MiB of closure, including
the `icu4c` that started the search. The track is *defined* by having no Nix
on the target, and nobody had checked.

## What changed

```nix
nix.enable = false;
system.forbiddenDependenciesRegexes = [ "-nix-2\\." ];
```

Plus an assertion against the mutable track, which needs Nix for contract
check 6.

The briefing's GOTCHAS seed warns that `nix.enable = false` still leaves
`register-nix-paths` pulling Nix in. It did not here, and the guard proves
it: the build would have failed if anything still referenced `nix-2.*`. The
likely reason is that `smol.noFlakeRegistry` (experiment 2) already removed
the registry that fragment serves.

## Numbers

| measure           | before      | after       | delta         |
| ----------------- | ----------- | ----------- | ------------- |
| closure           | 732 039 064 | 640 251 936 | 91 787 128    |
| closure, MiB      | 698.13      | 610.59      | 87.54, 12.5%  |
| image, raw VHD    | 897 804 800 | 799 214 592 | 98 590 208    |
| image, MiB        | 856.21      | 762.19      | 94.02, 11.0%  |

87.54 MiB rather than the 162.9 MiB that `nix path-info --closure-size`
reports for Nix. The difference is everything Nix shares with the rest of the
system: glibc, openssl, curl and the rest stay because other things need
them. A closure size is not a saving, and the two get conflated easily.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **13.472s**, against 14.338s for the previous accepted
system. Ten checks on both boots.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only, and it is the clearest line between
the two tracks in the whole lab. With this on, the store is a read-only
artefact of the image: nothing can be built, substituted or garbage
collected, and there is no `nix` command at all.

## Surprises

The appliance track had carried Nix through twenty-five experiments without
anyone noticing, because every measurement asked "how big is this path" and
none asked "why is this path here". `icu4c` was only ever a symptom.

The method that found it is worth stating as a rule: **the largest
unexplained path is more interesting than the largest path.** `systemd` and
`perl` are large and expected; `icu4c` was merely odd, and being odd is what
made it worth a `why-depends`.
