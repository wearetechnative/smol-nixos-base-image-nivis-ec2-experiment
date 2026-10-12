# 052 and 053: slim-iproute2

Rejected at #52 by its own guard, which was right. Accepted at #53.

- **Track:** appliance
- **Contract:** 3, 4, 5 (the network comes up through `ip`)
- **Module:** `smol.slimIproute2`
- **Source:** found by lab, exp #52, from the referrer table in `FLOOR.md`

## Hypothesis

`iproute2` is kept because dhcpcd sets the address and the default route
through `ip`. Four packages come with it that nothing on this image calls:
`db-5.3.28` for `arpd`, `iptables-1.8.13-lib` for `tc`'s xtables action,
and `libbpf-1.7.0` with `elfutils-0.195` for loading BPF programs through
`tc`. Expected roughly 12.7 MiB.

## What changed

[`modules/smol/slim-iproute2.nix`](../modules/smol/slim-iproute2.nix).
iproute2 has no configure flags for these; they are plain `buildInputs`
that its configure script probes for. The overlay filters them out of the
list and lets the probe fail, which is what the upstream build already does
when the host platform is static.

The filter asserts that it removed exactly four inputs, so a change to the
derivation's input list fails evaluation instead of silently saving less.

## Numbers

| measure    | before | after  | delta       |
| ---------- | ------ | ------ | ----------- |
| closure    | 333.50 | 326.62 | 6.89, 2.1%  |
| image, raw | 470.12 | 460.11 | 10.01, 2.1% |

Paths that left: `db-5.3.28` (4.24) and `iptables-1.8.13-lib` (2.18).

`elfutils` and `libbpf` stayed. They have a third holder: **systemd**, built
with `withLibBPF`. Experiment 52 named all four in
`system.forbiddenDependenciesRegexes`, the build failed with
`contains the following disallowed paths: elfutils-0.195`, and that is the
guard doing its job rather than a defect. Experiment 53 narrows the guard to
the two paths this strategy actually removes, and experiment 54 goes after
systemd's BPF support.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 15.16s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted at #53.

## Surprises

The guard is now the third mechanism that has caught a removal that did not
happen: #3 (nixos-rebuild), #20 and #47 (systemd-minimal), and now this.
Writing the guard for what you *hope* leaves rather than what you *know*
leaves is how it stays useful.
