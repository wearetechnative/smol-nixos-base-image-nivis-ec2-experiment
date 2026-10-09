---
# smol-nixos-base-image-nivis-ec2-experiment-y16f
title: Floor analysis
status: todo
type: epic
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-09T11:51:38Z
parent: smol-nixos-base-image-nivis-ec2-experiment-ppfg
---

Stop criterion 3 of BRIEFING section 9. Every store path over 1 MiB in systems/accepted has a one line reason it cannot go, or it becomes a backlog item instead.

- [ ] list every path over 1 MiB with nix path-info -rS
- [ ] a one line reason per path, backed by nix why-depends
- [ ] any path without a convincing reason becomes a new BACKLOG.md item
- [ ] FLOOR.md filled per track
- [ ] confirm criterion 1: the last 8 accepted experiments each saved under 1 percent or under 2 MiB
