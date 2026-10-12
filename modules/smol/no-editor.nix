{ config, lib, ... }:
let
  cfg = config.smol.noEditor;
in
{
  options.smol.noEditor.enable = lib.mkEnableOption ''
    removing the system editor through `programs.nano.enable = false`.

    `smol.minimalSystemPackages` already took nano off the system path in
    experiment 31, and it stayed in the closure anyway: `programs.nano`
    writes `/etc/nanorc`, which references the package, which links
    `file-5.48`. 10.54 MiB of libmagic for an editor nobody can run on a
    machine reached only over SSH.

    Measured saving (appliance track, EC2): 2.59 MiB closure, 4.00 MiB raw
    image, ledger #49. Less than hoped: `file` has a second holder in
    `fetch-ec2-metadata.service`, which `smol.noUserDataDecompression`
    handles.
    Trade-offs: no editor on the target at all, so a file cannot be changed
    in place. On the appliance track that is the point, since the image is
    replaced rather than edited.
    Requires: nothing.
    Source: found by lab, exp #49, by retracing `FLOOR.md`'s undecided
    entries after experiment 48 changed the closure
  '';

  config = lib.mkIf cfg.enable {
    programs.nano.enable = false;

    system.forbiddenDependenciesRegexes = [ "-nano-" ];
  };
}
