# 003: no-installer-tools

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noInstallerTools`
- **Source:** found by lab, from `nix why-depends` on the baseline

## Hypothesis

`python3-3.14.7` is 136.55 MiB and the third largest path in the baseline.
`nix why-depends` puts it behind a single consumer:

```
nixos-system
└── sw -> system-path
    └── bin/nixos-rebuild -> nixos-rebuild-ng-26.11
        └── #!/nix/store/...-python3-3.14.7/bin/python3.14
```

`nixos-rebuild` is a Python program. On the appliance track, where updates
replace the AMI and there is no switch-to-configuration, it is dead weight,
and it drags a full CPython interpreter behind it. Setting
`system.disableInstallerTools = true` should remove it.

## What changed

```nix
system.disableInstallerTools = true;
system.forbiddenDependenciesRegexes = [ "nixos-rebuild" ];
```

## Numbers

None. The build failed before measurement.

## Gate 1, local

Not reached.

## Gate 2, EC2

Not reached. No AWS resources were created, so nothing to tear down.

## Decision

**Rejected: build failed.** The hypothesis was wrong, in a useful way.

```
System closure contains the following disallowed paths:
/nix/store/415nny76xbh9ck27cfk48hhzx0q1hvla-nixos-rebuild-ng-26.11
```

`system.disableInstallerTools` only controls `system.tools.<name>.enable`,
which gates `environment.systemPackages`. It has no effect on anything else
that references `config.system.build.nixos-rebuild`, and
`virtualisation/amazon-init.nix` does exactly that:

```nix
export PATH=${pkgs.lib.makeBinPath [
  ...
  config.system.build.nixos-rebuild
]}
...
nixos-rebuild switch
```

amazon-init reads EC2 user-data and, when it looks like a NixOS
configuration, applies it. So the tool stays in the closure through a service
PATH rather than through the system path, and CPython stays with it.

## Surprises

**The regression guard earned its place on its first outing.** Without
`system.forbiddenDependenciesRegexes = [ "nixos-rebuild" ]` this experiment
would have built fine, measured a saving of roughly nothing, and been
rejected as "not smaller" with no explanation. Instead the build failed and
named the exact store path still in the closure.

BRIEFING §5 asks for a guard on every accepted removal of a package family.
This says the guard is worth adding *before* the first build, not after
acceptance: it turns a silent null result into a diagnosis.

Follow-up: the strategy is split in two, per BRIEFING §5's rule that a
strategy needing another must assert rather than silently enable it.

- `smol.noAmazonInit` removes the user-data mechanism. Experiment 004.
- `smol.noInstallerTools` keeps this implementation and now asserts
  `smol.noAmazonInit`. Experiment 005.
