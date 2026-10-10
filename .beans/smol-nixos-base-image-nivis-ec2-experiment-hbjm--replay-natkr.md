---
# smol-nixos-base-image-nivis-ec2-experiment-hbjm
title: Replay natkr
status: in-progress
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-10T18:43:31Z
parent: smol-nixos-base-image-nivis-ec2-experiment-53cb
---

Items n1 to n8 of BACKLOG.md, source https://natkr.com/2026-06-19-nixos-but-smol/. One experiment, one branch, one ledger line each. Expect EC2 specific breakage that the ISO work never hit.

- [x] n1 documentation.enable = false, accepted #10, 93.87 MiB
- [x] n2 environment.defaultPackages = [ ], accepted #11, only 3.39 MiB; perl survives it
- [ ] n3 nix.enable = false, including the register-nix-paths override
- [ ] n4 programs.ssh option stub plus disabledModules
- [ ] n5 trim environment.systemPackages to what the contract needs
- [ ] n6 trim system.extraDependencies
- [x] n7 accepted #17, 152.93 MiB, after three attempts and two failed EC2 deployments
- [ ] n8 system.etc.overlay plus services.userborn to drop Perl
- [ ] every accepted removal has a system.forbiddenDependenciesRegexes guard
