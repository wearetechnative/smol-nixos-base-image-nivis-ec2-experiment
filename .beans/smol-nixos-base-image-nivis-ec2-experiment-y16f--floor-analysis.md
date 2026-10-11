---
# smol-nixos-base-image-nivis-ec2-experiment-y16f
title: Floor analysis
status: in-progress
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-11T14:30:43Z
parent: smol-nixos-base-image-nivis-ec2-experiment-ppfg
---

Stop criterion 3 of BRIEFING section 9. Every store path over 1 MiB in systems/accepted has a one line reason it cannot go, or it becomes a backlog item instead.

- [x] list every path over 1 MiB with nix path-info -rS: 63 paths
- [ ] a one line reason per path, backed by nix why-depends
- [ ] ten paths, 63.25 MiB, still have no justification and block criteria 2 and 3
- [x] FLOOR.md filled for the appliance track; the mutable track has not started
- [ ] confirm criterion 1: the last 8 accepted experiments each saved under 1 percent or under 2 MiB
