# 002: no-flake-registry

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noFlakeRegistry`
- **Branch:** `main`
- **Source:** found by lab, from `nix why-depends` on the baseline

## Hypothesis

The baseline's single largest store path is the nixpkgs source checkout, at
199.75 MiB. It is not on either prior-art list, because an ISO built from a
channel never had one. `nix why-depends` puts it behind
`/etc/nix/registry.json`:

```
nixos-system
└── etc
    └── etc/nix/registry.json -> etc-nix-registry.json
        └── {"to":{"path":"/nix/store/...-source","type":"path"}}
```

A flake-built NixOS pins its own nixpkgs into the system registry so that
`nix run nixpkgs#hello` resolves offline. An appliance has no Nix and never
resolves a flake reference, so the whole source tree is there to serve a
lookup nothing will ever perform.

## What changed

`modules/smol/no-flake-registry.nix`, one line of implementation:

```nix
nix.registry = lib.mkForce { };
```

`mkForce` rather than an option: the registry entry is added by the flake
wrapper around `nixosSystem`, at normal priority, and there is no option that
says "do not pin me".

No `system.forbiddenDependenciesRegexes` guard. This removes a data file's
reference to a source tree rather than a package family, and the store path
is called `source`, which is far too generic to match on safely.

## Numbers

| measure           | before        | after         | delta         |
| ----------------- | ------------- | ------------- | ------------- |
| closure           | 1 589 904 712 | 1 380 449 624 | 209 455 088   |
| closure, MiB      | 1516.25       | 1316.50       | 199.75, 13.2% |
| image, raw VHD    | 2 724 876 288 | 2 196 328 448 | 528 547 840   |
| image, MiB        | 2598.64       | 2094.52       | 504.12, 19.4% |

The image shrank by more than twice the closure saving. The VHD carries
filesystem overhead proportional to its contents, so a closure saving is
amplified in the artefact that actually gets uploaded and booted. Worth
remembering when weighing later experiments: closure is the honest measure,
image size is what the upload and the snapshot import cost.

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Instance `i-0284f0bd6d04fcc6c`, AMI `ami-05ee44e7d5fea9929`,
`t3.micro` in `eu-central-1`.

Ten checks on first boot, ten after reboot. Boot time **40.420s**, against
40.753s for the baseline, which is within noise.

Teardown: all six resources destroyed.

## Decision

**Accepted.** Both gates pass and the closure dropped 13.2%. Promoted to
`systems/accepted` through `smol.profile = "aggressive"`, and listed in
`modules/smol/profiles.nix` under both `safe` and `aggressive`: there is no
sense in which a registry entry nothing reads is worth 199.75 MiB, on any
track.

## Surprises

`systems/baseline` set `smol.profile = "none"` at normal priority, which
conflicts with `systems/accepted` setting it to `"aggressive"`. The module
system refuses rather than letting the more specific system win. Changing
the baseline to `lib.mkDefault "none"` fixes it and leaves the evaluated
value identical, so the baseline derivation hash is unchanged and ledger line
1 stays valid. Verified by comparing the toplevel store path before and
after, which came out byte-identical.

The baseline is frozen in the sense that what it *produces* may not change.
A priority annotation that provably changes nothing is not a violation of
that, but it is worth recording that it was checked rather than assumed.
