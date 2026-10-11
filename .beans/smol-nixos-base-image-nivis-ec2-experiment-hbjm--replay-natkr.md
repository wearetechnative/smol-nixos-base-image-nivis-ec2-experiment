---
# smol-nixos-base-image-nivis-ec2-experiment-hbjm
title: Replay natkr
status: in-progress
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-11T13:54:30Z
parent: smol-nixos-base-image-nivis-ec2-experiment-53cb
---

Items n1 to n8 of BACKLOG.md, source https://natkr.com/2026-06-19-nixos-but-smol/. One experiment, one branch, one ledger line each. Expect EC2 specific breakage that the ISO work never hit.

- [x] n1 documentation.enable = false, accepted #10, 93.87 MiB
- [x] n2 environment.defaultPackages = [ ], accepted #11, only 3.39 MiB; perl survives it
- [ ] n3 nix.enable = false, including the register-nix-paths override
- [ ] n4 programs.ssh option stub plus disabledModules
- [x] n5 accepted #31, 57.32 MiB, 57 packages down to 16
- [ ] n6 trim system.extraDependencies
- [x] n7 accepted #17, 152.93 MiB, after three attempts and two failed EC2 deployments
- [x] n8 needs-upstream: implemented and gate 1 green, but perl is held by install-grub.pl, exp #37
- [ ] every accepted removal has a system.forbiddenDependenciesRegexes guard
