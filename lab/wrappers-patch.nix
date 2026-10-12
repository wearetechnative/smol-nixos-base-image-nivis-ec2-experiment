# The patched copy of nixpkgs' `security/wrappers` module.
#
# Built outside the module system on purpose: `disabledModules` and `imports`
# are evaluated before `config` exists, so the module that replaces upstream's
# cannot reach `pkgs` to build the replacement. Both callers pass it in as the
# `smolWrappersPatched` module argument instead, `flake.nix` through
# `specialArgs` and `lab/test-local.nix` through `node.specialArgs`, so the
# two gates build the same thing.
#
# See modules/smol/wrappers-without-propagation.nix for what the patch is for.
pkgs:
pkgs.runCommand "security-wrappers-without-propagation" { } ''
  mkdir -p $out
  cp ${pkgs.path}/nixos/modules/security/wrappers/default.nix $out/default.nix
  cp ${pkgs.path}/nixos/modules/security/wrappers/wrapper.c $out/wrapper.c
  substitute ${pkgs.path}/nixos/modules/security/wrappers/wrapper.nix $out/wrapper.nix \
    --replace-fail \
      '  dontStrip = debug;' \
      '  dontStrip = debug;
  postFixup = "rm -rf $out/nix-support";'
''
