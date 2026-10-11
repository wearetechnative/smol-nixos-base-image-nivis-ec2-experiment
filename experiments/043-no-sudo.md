# 043: no-sudo

- **Track:** appliance
- **Contract:** 1
- **Module:** `smol.noSudo`
- **Source:** found by lab, from `FLOOR.md`'s unexplained paths

## Hypothesis

`sudo-1.9.17p2` was one of the ten paths `FLOOR.md` listed with no
justification. `nix why-depends` puts it behind
`suid-sgid-wrappers.service`, which is `security.wrappers`, and
`security.sudo.enable` defaults on.

The appliance has one account, root, reached over SSH with a key injected
from instance metadata. There is nobody to escalate from.

## What changed

```nix
security.sudo.enable = false;
```

`security.wrappers` itself stays, and must: the briefing's GOTCHAS seed says
pam_unix needs `unix_chkpwd` or login fails and getty loops. Only sudo's own
wrapper goes.

## Numbers

| measure      | before      | after       | delta       |
| ------------ | ----------- | ----------- | ----------- |
| closure, MiB | 489.07      | 483.26      | 5.81, 1.2%  |
| image, MiB   | 600.16      | 592.16      | 8.00, 1.3%  |

## Gate 1, local

Pass. Ten checks on first boot, ten after reboot.

## Gate 2, EC2

Pass. Boot time **12.296s**, the fastest recorded. Teardown: all six
resources destroyed.

## Decision

**Accepted.** Profile: `aggressive` only. An image that creates an
unprivileged admin user needs sudo; this one has root and a key.

## Surprises

None in the result. The method is the point: this came from writing
`FLOOR.md` rather than from either prior-art list or from looking at the
largest paths. Forcing every path over 1 MiB to carry a justification turns
"what is big" into "what has no reason to be here", and the second question
found a 5.81 MiB answer in the first ten minutes.
