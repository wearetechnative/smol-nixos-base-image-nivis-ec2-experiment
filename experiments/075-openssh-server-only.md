# 075: openssh-server-only

- **Track:** appliance
- **Contract:** every check; the harness connects over this sshd and pushes
  a file with `scp`
- **Module:** `smol.slimOpenssh.serverOnly`
- **Source:** found by lab, exp #75

## Hypothesis

`openssh-10.5p1` is 8.8 MiB and the appliance is connected *to*. It never
opens an outbound session, so `ssh`, `ssh-add`, `ssh-agent`,
`ssh-keyscan`, `ssh-keysign`, `ssh-pkcs11-helper`, `ssh-sk-helper` and
`sftp` are programs with no caller.

`scp` and `sftp-server` stay: `lab/test-local.nix` and
`lab/deploy-ec2.sh` push a static curl to the machine, and `scp` runs
`scp -t` on the receiving side.

## What changed

[`modules/smol/slim-openssh.nix`](../modules/smol/slim-openssh.nix) grows
a `serverOnly` option that appends an `rm` to the package's
`installCheckPhase`.

Two details, both learned the hard way:

- `postInstall` is too early. openssh's install check runs
  `$out/bin/ssh -V`, so deleting `ssh` before it fails the build.
- `postInstallCheck` never fires, because openssh replaces
  `installCheckPhase` wholesale and does not call `runHook
  postInstallCheck`. Appending to `installCheckPhase` itself is what
  works.

The package goes from 8.8 to 6.0 MiB and keeps `sshd`, `sshd-session`,
`sshd-auth`, `ssh-keygen`, `scp`, `ssh-copy-id` and `sftp-server`.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 269.48 | 266.39 | 3.09, 1.1% |
| image, raw | 386.10 | 380.10 | 6.00, 1.6% |

## Gate 1, local

Pass, 10 of 10, and the `scp` push it depends on is the first thing it
does.

## Gate 2, EC2

Pass. Boot 15.93s.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted.
