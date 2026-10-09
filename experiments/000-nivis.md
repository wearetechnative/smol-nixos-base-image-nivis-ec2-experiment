# 000: nivis

Not an experiment. This note records what nivis can and cannot do for the lab,
and it is the input for the IAM permissions (BRIEFING §6.3 and §7).

nivis: <https://github.com/nivis-project/nivis>. OpenTofu provider resources
as first-class Nix values, applied by a Go executor that speaks the provider
plugin protocol directly. Its `nix/example/ec2.nix` already builds a NixOS
amazon image and launches it, which is the shape `lab/deploy-ec2.sh` wraps.

## What the lab needs from it

| need | status | note |
| ---- | ------ | ---- |
| build a NixOS image for EC2 | | |
| register an AMI from that image | | |
| launch an instance of a given type | | |
| tag every created resource `Project=smol-lab` and `Experiment=<id>` | | |
| return the instance's public IP | | |
| terminate the instance, deregister the AMI, delete the snapshot | | |
| fetch serial console output | | |

Fill each row with `yes`, `no` or `partly`, and a pointer to where in the
nivis source it happens.

## AWS API actions nivis calls

One row per call site. This table is what
`infra/iam/SmolLabRole-permissions.json` is derived from; no action goes in
that policy without a row here.

| action | called from | needed for |
| ------ | ----------- | ---------- |
| | | |

## Gaps

Anything the lab needs that nivis cannot do yet. Each gap gets a proposed
change for Pim. Per BRIEFING §6.4, do not work around nivis with direct AWS
calls without his approval.
