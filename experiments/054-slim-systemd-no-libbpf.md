# 054: slim-systemd, without the BPF framework

- **Track:** appliance
- **Contract:** 1 (nothing specific; the whole contract reruns)
- **Module:** `smol.slimSystemd.withLibBPF`
- **Source:** found by lab, exp #52, which proved systemd was the last holder

## Hypothesis

Experiment 53 removed iproute2's claim on `libbpf` and `elfutils` and both
stayed, with `systemd` as the only remaining referrer. systemd uses BPF for
`RestrictNetworkInterfaces=`, `IPAddressDeny=`, `RestrictFileSystems=` and
unit device access control. No unit on this image sets any of them.

## What changed

A new option on the existing module rather than an edit to it:
`smol.slimSystemd.withLibBPF`, added defaulting to `true` so that
`accepted` and `candidate` differed by exactly this. Experiment 40 is why.
Its default is `false` now that it has been measured.

```nix
systemd = prev.systemd.override {
  inherit (cfg) withLibBPF;
  ...
};
```

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 326.62 | 319.99 | 6.64, 2.0% |
| image, raw | 460.11 | 452.11 | 8.00, 1.7% |

Paths that left: `libbpf-1.7.0` (2.18) and `elfutils-0.195` (4.12).

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.23s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted. Together with #53 this is 13.53 MiB of closure for what was one
line in `FLOOR.md` reading `elfutils-0.195 | not traced |`.

## Surprises

None. The three-holder chain was mapped before either experiment ran, which
is the first time this lab has removed a path without a surprise in the
middle, and it is because #49 forced the switch from `why-depends` to a full
referrer dump.
