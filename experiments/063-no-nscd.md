# 063 and 064: no-nscd

Rejected at #63 by a NixOS assertion that names its own way out, accepted
at #64.

- **Track:** appliance
- **Contract:** 4 (`getent hosts`) and 5, which depend on name resolution
- **Module:** `smol.noNscd`
- **Source:** backlog item `e27`

## Hypothesis

NixOS runs `nsncd-1.5.3`, 1.46 MiB, as `nscd.service`. It is a cache in
front of NSS, not a part of it: the modules are glibc plugins each process
loads for itself.

## What #63 found

```
Failed assertions:
- Loading NSS modules from system.nssModules (...systemd-261.3/lib),
requires services.nscd.enable being set to true.

If disabling nscd is really necessary, it is possible to disable loading
NSS modules by setting `system.nssModules = lib.mkForce [];`
```

systemd ships NSS plugins for `passwd`, `group`, `shadow` and `hosts`, and
NixOS will not run them without the daemon. The assertion is right to
exist and it is right about the fix.

## What changed

[`modules/smol/no-nscd.nix`](../modules/smol/no-nscd.nix) drops the
plugins with the daemon and sets `nsswitch.conf` to the sources that are
left:

```
passwd:    files
group:     files
hosts:     files dns
```

`systemd` resolves `DynamicUser` units and `mymachines` resolves nspawn
containers. `nix eval` over `config.systemd.services` says no unit on this
image sets `DynamicUser`, and there are no containers, so both were
answering for a population of zero.

One trap on the way: `system.nssDatabases.passwd = lib.mkForce [ ]` wipes
`files` too, and the generated `nsswitch.conf` had an empty `passwd:` line,
which is a machine nobody can log into. The databases are set to their
explicit contents rather than forced empty, and the generated file was
read before the experiment ran.

## Numbers

| measure    | before | after  | delta      |
| ---------- | ------ | ------ | ---------- |
| closure    | 295.88 | 294.42 | 1.46, 0.5% |
| image, raw | 422.11 | 418.11 | 4.00, 0.9% |

## Gate 1, local

Pass, 10 of 10, including check 4.

## Gate 2, EC2

Pass. Boot 14.03s. Checks 4 and 5 both resolve names with no cache and no
systemd NSS.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted at #64.

## Surprises

The assertion is the second time NixOS has refused a removal and then
named the condition under which it is allowed (`smol.noDuplicateSystemd`
and the lastlog tmpfiles fragment was the first). Reading what the module
system says rather than working around it has been the faster route both
times.
