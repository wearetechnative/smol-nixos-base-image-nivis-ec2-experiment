---
# smol-nixos-base-image-nivis-ec2-experiment-u3nb
title: Replay siraben
status: todo
type: epic
created_at: 2026-10-09T11:51:38Z
updated_at: 2026-10-09T11:51:38Z
parent: smol-nixos-base-image-nivis-ec2-experiment-53cb
---

Items s1 to s9 of BACKLOG.md, source https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6. The overlay based items cause large rebuilds, so their builds go to log files and never into the conversation.

- [ ] s1 slim systemd as a nixpkgs overlay
- [ ] s2 minimal util-linux as a nixpkgs overlay
- [ ] s3 dbus without X11, reusing the slim systemd
- [ ] s4 xz for squashfs, initrd and kernel, single threaded with crc32
- [ ] s5 trim the initrd module set, keeping ENA and NVMe
- [ ] s6 system.switch.enable = false, appliance track only
- [ ] s7 C.UTF-8 only, no locale archive
- [ ] s8 lastlog off, dropping sqlite
- [ ] s9 empty hwdb
