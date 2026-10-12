# 062: slim-openssh

- **Track:** appliance
- **Contract:** every check. The whole contract runs over this sshd
- **Module:** `smol.slimOpenssh`
- **Source:** backlog item `e26`

## Hypothesis

openssh's `withFIDO` pulls `libfido2-1.17.0`, 1.15 MiB, for the
`ecdsa-sk` and `ed25519-sk` key types. Those need a physical authenticator
on the machine doing the authentication. `lab/deploy-ec2.sh` generates an
ephemeral ed25519 key per run and throws it away; there is no
authenticator at either end.

`libfido2` has been here before: it was one of the holders of the
duplicate `systemd-minimal` until `smol.slimSystemd` set `withFido2 =
false` in #36, and it came straight back through openssh.

## What changed

[`modules/smol/slim-openssh.nix`](../modules/smol/slim-openssh.nix):

```nix
openssh = prev.openssh.override { withFIDO = false; };
```

An overlay is right here: openssh is deep in the appliance and almost
nothing takes it as a build input. The dry run was 25 derivations, no
QEMU.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 297.26 | 295.88 | 1.38, 0.5% |
| image, raw | 424.11 | 422.11 | 2.00, 0.5% |

`libfido2-1.17.0` left.

## Gate 1, local

Pass, 10 of 10.

## Gate 2, EC2

Pass. Boot 14.20s. The contract is carried over SSH end to end, so a
broken sshd fails every check rather than one.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted.
