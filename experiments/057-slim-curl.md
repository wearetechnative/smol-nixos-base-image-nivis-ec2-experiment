# 057: slim-curl, twice wrong

One attempt killed and unlogged, one rejected by the guard in ledger line
57. Both are here because the reasons are worth keeping.

- **Track:** appliance
- **Module:** `smol.slimCurl`, first version
- **Source:** backlog item `e23`

## What happened

The first version of the module did what every other package strategy in
this lab does:

```nix
nixpkgs.overlays = [ (final: prev: { curl = prev.curl.override { ... }; }) ];
```

An overlay rebuilds everything that takes the package as a build input.
For `curl` that set includes **LLVM**, which links libcurl for debuginfod,
and therefore clang, mesa and QEMU behind it. The build ran for over three
hours, got as far as `clang-21.1.8`, and took the machine from 56 GiB free
to 16 GiB. It was killed rather than finished: a one-off cost of that size
for an expected 4.8 MiB is not a trade this lab should make silently, and
`make-disk-image` runs inside QEMU, so the rebuild was on the critical path
of every later experiment too.

No ledger line was written, nothing was deployed, `just reap` was clean.

## The second attempt, ledger line 57

Rejected by `system.forbiddenDependenciesRegexes`:

```
System closure contains the following disallowed paths:
/nix/store/...-krb5-1.22.2-lib
```

The module had moved curl on `fetch-ec2-metadata.service`'s path, and curl
has two more referrers in the closure:

| referrer | how |
| -------- | --- |
| `systemd-261.3` | `systemd-imdsd` and `systemd-report` link libcurl through `libsystemd-shared`. systemd 261 does that whatever `withRemote` and `withImportd` say, and `smol.slimSystemd` sets both false |
| `amazon-ec2-utils-2.2.0` | its NVMe helper scripts call curl |

A second thing the dump settled: `libunistring-1.4.2` cannot go with curl.
`glibc` references `libidn2` for IDN in `getaddrinfo`, and libidn2
references libunistring. The module's guard and its documented saving were
both wrong about that, and both are corrected: the strategy is worth krb5,
2.80 MiB, and nothing else.

## What replaced it

The appliance closure references curl in exactly one place:
`fetch-ec2-metadata.service`'s path, which `smol.noUserDataDecompression`
sets. Overriding it there changes one package and rebuilds one package.
That is experiment 58.

`smol.noUserDataDecompression.curl` is a package option for that reason.
Two modules both doing `path = lib.mkForce [ ... ]` would merge their lists
instead of conflicting, and the unit would end up carrying both curls, with
the old one keeping krb5 in the closure. The first attempt at 58 did
exactly that, and `builtins.length` on the unit's path said 12.

## Decision

Rejected at #57, and the overlay version before it was abandoned without a
ledger line: nothing was measured there, and BRIEFING §12 says a number
that is not in the ledger cannot be claimed. Experiment 58 carries the
strategy.

## Surprises

An overlay is the right tool when the package is deep in the appliance
(systemd, util-linux, iproute2, dbus) and the wrong one when the package is
deep in the *build world*. Those are different graphs, and nothing in the
protocol was checking the second one. In `GOTCHAS.md`.
