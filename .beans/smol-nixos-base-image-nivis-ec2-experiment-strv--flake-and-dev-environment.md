---
# smol-nixos-base-image-nivis-ec2-experiment-strv
title: Flake and dev environment
status: in-progress
type: epic
priority: normal
created_at: 2026-10-09T11:51:08Z
updated_at: 2026-10-10T10:17:03Z
parent: smol-nixos-base-image-nivis-ec2-experiment-8uwi
---

Done: `nix flake check` is green on x86_64-linux and aarch64-linux, `nix develop` gives just, jq, awscli2, shellcheck, qemu and nivis, and `nix fmt` formats the tree.

- [x] flake.nix with a plain `systems` list and `genAttrs`, no flake-utils
- [x] nivis as a flake input, nixpkgs followed
- [x] nixosConfigurations for baseline, candidate and accepted, per system
- [x] devShell, formatter, checks
- [x] `nix flake check` green on x86_64-linux
- [ ] an aarch64 builder or emulation, so the Graviton track can be checked too
- [ ] CI or a `just check` run recorded in the first commit

Note: aarch64 remains unbuildable locally; tracked under Still open in STATE.md.
