# 066 and 067: wrappers-without-propagation

Rejected at #66 because gate 1 could not evaluate it, accepted unchanged in
substance at #67.

- **Track:** appliance
- **Contract:** every check. `security.wrappers` is how `unix_chkpwd` runs,
  and without it PAM cannot verify a password and login loops
- **Module:** `modules/smol/wrappers-without-propagation.nix`
- **Source:** found by lab, exp #66, from `FLOOR.md`'s referrer table

## Hypothesis

`linux-headers-static-7.2`, 7.20 MiB, is in the closure because every
`security-wrapper-*` references it. The binary does not:

```
$ strings .../security-wrapper-mount-.../bin/security-wrapper | grep -c linux-headers
0
```

It is statically linked musl and it never saw a header path at runtime.
The reference is one 60-byte text file that stdenv's fixup phase writes:

```
$ cat .../security-wrapper-mount-.../nix-support/propagated-build-inputs
/nix/store/...-linux-headers-static-7.2
```

`nixos/modules/security/wrappers/wrapper.nix` takes `linuxHeaders` in
`buildInputs`, the static stdenv propagates it, and the activation script
copies the wrapper binary out of that package, so the package and its
metadata file stay reachable.

This is 7.20 MiB on **every NixOS system with a setuid wrapper**, not only
on this one.

## What changed

[`modules/smol/wrappers-without-propagation.nix`](../modules/smol/wrappers-without-propagation.nix)
disables the upstream module and imports a patched copy with one attribute
added:

```nix
postFixup = "rm -rf $out/nix-support";
```

It is not a `smol.<name>.enable` option, which BRIEFING §5 asks for and
this cannot have: `disabledModules` and `imports` are evaluated before
`config` exists, so they can depend on neither an option nor `pkgs`. The
patched copy is built by [`lab/wrappers-patch.nix`](../lab/wrappers-patch.nix)
and handed in as a module argument.

Two mistakes on the way, both worth keeping:

- `imports = [ smolWrappersPatched ]` with a bare derivation makes the
  module system read the *attrset* as a module, and its `system` attribute
  lands on NixOS's `system` option: `you're trying to define a value of
  type 'string' rather than an attribute set for the option 'system'`.
  `"${smolWrappersPatched}"` forces the store path.
- Gate 1 builds its nodes itself and does not get the flake's
  `specialArgs`, so the argument was missing there and the evaluation
  recursed through `_module.args`. That is ledger line 66.
  `lab/test-local.nix` now passes the same thing through
  `node.specialArgs`, from the same file, so the gates cannot drift.

## Numbers

| measure    | before | after  | delta       |
| ---------- | ------ | ------ | ----------- |
| closure    | 285.70 | 278.50 | 7.20, 2.5%  |
| image, raw | 412.10 | 400.10 | 12.00, 2.9% |

Exactly `linux-headers-static-7.2`.

## Gate 1, local

Pass at #67, 10 of 10. Failed to evaluate at #66.

## Gate 2, EC2

Pass. Boot 13.32s. The wrappers are load-bearing for login, so a broken
one fails every check.

Teardown: instance, AMI and snapshot destroyed; `STATE.md` live table empty.

## Decision

Accepted at #67.

## Surprises

The two largest savings of the last ten experiments, #65 and this one,
both came from a *string* rather than from code: a PATH entry in
`/etc/systemd/system.conf` and a metadata file nothing reads. Neither
needed a package to change. `nix why-depends` points at packages, which is
why the referrer dump found these and the earlier method did not.

The fix belongs upstream. `REPORT.md` carries it as a recommendation.
