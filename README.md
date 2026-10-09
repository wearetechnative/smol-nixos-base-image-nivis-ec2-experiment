# smol NixOS base image, nivis to EC2

How small can our NixOS base image for AWS EC2 get while it still boots on
EC2, deploys through [nivis](https://github.com/nivis-project/nivis), and stays
fully functional over SSH?

Every size-reduction strategy becomes a NixOS module option under `smol.*`,
with a measured saving, its trade-offs and its source. The repo documents
itself: the ledger, `REPORT.md` and the generated option docs together say
what was tried, what worked, what failed and why.

## Where to look

| file | what it holds |
| ---------------- | ------------------------------------------------ |
| `BRIEFING.md`    | the brief, and the source of truth |
| `STATE.md`       | where the lab is right now |
| `CLAUDE.md`      | how the work is run |
| `docs/TESTING.md`| the verification contract and the two gates |
| `ledger.jsonl`   | one append-only line per experiment |
| `BACKLOG.md`     | hypotheses not yet tried |
| `GOTCHAS.md`     | every non-obvious failure and its cause |
| `FLOOR.md`       | what is left and why it cannot go |
| `docs/options.md`| generated from the `smol.*` options |

## Getting started

```sh
nix develop          # just, jq, awscli2, shellcheck, qemu, nivis
just                 # the recipe list
just check           # nix flake check
just gate1 accepted  # boot it in QEMU and run the contract over SSH
```

EC2 deployment needs the one-time AWS setup in `docs/SETUP-AWS.md`.

## Prior art

- natkr, [I can haz smoller NixOS ISOs?](https://natkr.com/2026-06-19-nixos-but-smol/)
- siraben, [Smallest bootable NixOS ISO](https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6)

Both targeted an ISO with a local root shell. This lab needs networking, DHCP,
sshd, EC2 metadata and the Nitro drivers, so the floor here is higher. Finding
out how much higher is the point.
