# 015: no-kernel-modules

Rejected, gate 2 failed. First of three attempts at natkr's `n7`.

The module tree came out of the closure (153.10 MiB) and gate 1 passed, but
the instance never answered SSH. The serial console showed it booting,
mounting root and then failing to reach IMDS:

```
fetch-ec2-metadata-start[585]: curl: (7) Failed to connect to 169.254.169.254:80
```

With no module tree, udev can load nothing after switch-root, and in the
initrd it only loads what the root device needs. `nvme` is in
`boot.initrd.availableKernelModules` and gets loaded that way; `ena` is in
neither list, because nothing in the initrd wants a network.

Fixed by pinning `ena` into `boot.initrd.kernelModules`, which was not
sufficient either. See experiments 016 and 017.

Teardown ran: the instance, AMI, snapshot, key pair, security group and
uploaded image were all destroyed.

Full account: `experiments/017-no-kernel-modules.md`.
