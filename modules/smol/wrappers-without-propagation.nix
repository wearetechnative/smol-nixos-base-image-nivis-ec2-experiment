# Drops `nix-support/propagated-build-inputs` from the setuid wrappers.
#
# This is a strategy like the ones beside it, but it cannot be a
# `smol.<name>.enable` option the way BRIEFING §5 asks. It works by
# replacing an upstream module, and `disabledModules` and `imports` are
# evaluated before `config` exists, so neither can depend on an option, nor
# reach `pkgs` to build the replacement. The patched copy is built in
# `flake.nix` and arrives as the `smolWrappersPatched` specialArg; this file
# is imported by `systems/accepted`, and was imported by `systems/candidate`
# alone while it was measured.
#
# What it is for:
#
# `linux-headers-static-7.2`, 7.20 MiB, is in the closure because every
# `security-wrapper-*` references it. The binary does not: it is statically
# linked musl and `strings` finds no trace of the path in it. The reference
# is one 60-byte text file that stdenv's fixup phase writes into the output:
#
#   $ cat .../security-wrapper-mount-.../nix-support/propagated-build-inputs
#   /nix/store/...-linux-headers-static-7.2
#
# `nixos/modules/security/wrappers/wrapper.nix` takes `linuxHeaders` in
# `buildInputs` and the static stdenv propagates it. Propagation is for
# things that link against the output, and nothing links against a setuid
# wrapper. The activation script copies the binary out of that package, so
# the package, the file and the headers all stay in the closure.
#
# That is 7.20 MiB on every NixOS system with a setuid wrapper, not only on
# this one, and the fix belongs upstream. `REPORT.md` says so.
#
# Patched rather than vendored, as `smol.leanImage` patches
# `make-disk-image`: one attribute is added, `--replace-fail` makes a
# nixpkgs change break the build rather than silently revert this, and the
# other 200 lines stay upstream's.
#
# Measured saving (appliance track, EC2): 7.20 MiB closure, 12.00 MiB raw
# image, ledger #67.
# Trade-offs: none found. The wrappers keep working and lose a metadata file
# nothing reads at runtime.
# Requires: nothing.
# Source: found by lab, exp #66, accepted at #67
{ smolWrappersPatched, ... }:
{
  disabledModules = [ "security/wrappers/default.nix" ];

  # `"${...}"` and not the bare derivation: the module system reads a
  # derivation attrset as a module, and its `system` attribute then lands
  # on NixOS's `system` option as a string. Interpolating forces the store
  # path, which is what a module import wants.
  imports = [ "${smolWrappersPatched}" ];

  system.forbiddenDependenciesRegexes = [ "-linux-headers-static-" ];
}
