# A patched copy of nixpkgs' `security/wrappers` module.
#
# Pure string work, deliberately: no derivation. The first version used
# `pkgs.runCommand`, which gives the result a system, and `nix flake check`
# then failed on the aarch64 variant with `platform mismatch` on an x86_64
# host. Copying three text files does not need a builder.
#
# `wrapper.nix` refers to `${./wrapper.c}` and `default.nix` refers to
# `./wrapper.nix`, both relative to their own directory. A file written with
# `builtins.toFile` sits alone in the store, so those references are rewritten
# to absolute ones. They stay *path interpolations* in the generated text and
# do not become strings: a string is not a dependency, and the build then
# fails with `wrapper.c: No such file or directory` inside the sandbox.
#
# See modules/smol/wrappers-without-propagation.nix for what the patch is for.
nixpkgsPath:
let
  dir = "${nixpkgsPath}/nixos/modules/security/wrappers";

  # `${<path>}` in the generated text, so the file is a dependency of the
  # build rather than a string that happens to look like one.
  wrapperC = "${"$"}{" + dir + "/wrapper.c}";

  wrapperNix = builtins.toFile "wrapper.nix" (
    builtins.replaceStrings
      [
        "${"$"}{./wrapper.c}"
        "  dontStrip = debug;"
      ]
      [
        wrapperC
        "  dontStrip = debug;\n  postFixup = \"rm -rf $out/nix-support\";"
      ]
      (builtins.readFile "${dir}/wrapper.nix")
  );

  patchedWrapper = builtins.readFile wrapperNix;

  check =
    if builtins.match ".*postFixup.*" patchedWrapper == null then
      throw ''
        lab/wrappers-patch.nix did not find its own substitution in
        wrapper.nix. nixpkgs' security/wrappers has changed; re-read it
        before adjusting this, and see
        experiments/066-wrappers-without-propagation.md.
      ''
    else
      true;
in
assert check;
builtins.toFile "security-wrappers-without-propagation.nix" (
  builtins.replaceStrings [ "./wrapper.nix" ] [ "${wrapperNix}" ] (
    builtins.readFile "${dir}/default.nix"
  )
)
