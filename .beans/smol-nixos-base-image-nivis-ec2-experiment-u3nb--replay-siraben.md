---
# smol-nixos-base-image-nivis-ec2-experiment-u3nb
title: Replay siraben
status: todo
type: epic
priority: normal
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-11T13:54:30Z
parent: smol-nixos-base-image-nivis-ec2-experiment-53cb
---

Items s1 to s9 of BACKLOG.md, source https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6. The overlay based items cause large rebuilds, so their builds go to log files and never into the conversation.

- [x] s1 slim systemd as a nixpkgs overlay, accepted #36, 38.24 MiB
- [ ] s2 minimal util-linux as a nixpkgs overlay
- [ ] s3 dbus without X11, reusing the slim systemd
- [ ] s4 xz for squashfs, initrd and kernel, single threaded with crc32
- [ ] s5 trim the initrd module set, keeping ENA and NVMe
- [ ] s6 system.switch.enable = false, appliance track only
- [ ] s7 C.UTF-8 only, no locale archive
- [x] s8 accepted #19, but only 3344 bytes: sqlite has another holder
- [x] s9 empty hwdb, accepted #39, 13.21 MiB
