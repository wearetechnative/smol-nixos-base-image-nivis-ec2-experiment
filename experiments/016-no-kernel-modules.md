# 016: no-kernel-modules

Rejected, gate 2 failed. Second of three attempts at natkr's `n7`.

With `ena` pinned into the initrd the instance still never answered SSH. The
serial console showed the link up and:

```
A start job is running for DHCP Client (12s / 1min 33s)
```

repeating until the timeout, with no error anywhere and no mention of `ena`
in the log at all.

The cause was not visible in the logs. `CONFIG_PACKET=m` in the kernel
config, and dhcpcd needs an `AF_PACKET` socket to send a DHCP request. With
no module tree, `af_packet` cannot load, so dhcpcd waits forever.

Fixed by adding `af_packet`, `fuse` and `configfs` to the same list, all
three of which are modular in this kernel. See experiment 017.

Teardown ran: everything destroyed.

Full account: `experiments/017-no-kernel-modules.md`.
