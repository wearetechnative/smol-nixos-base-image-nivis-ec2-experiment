{ config, lib, ... }:
let
  cfg = config.smol.noBashCompletion;
in
{
  options.smol.noBashCompletion.enable = lib.mkEnableOption ''
    turning off bash's completion support.

    `programs.bash.completion.enable` defaults to true and sources
    `bash-completion-2.18.0`, 1.21 MiB, from `/etc/bashrc`. The etc entry
    holds it whether or not anyone ever presses tab.

    The appliance is reached over SSH by a harness that runs a script.
    Interactive completion is a convenience for a human at a prompt, and a
    human at this prompt is already outside what the image is for.

    Measured saving (appliance track, EC2): TBD, ledger #TBD.
    Trade-offs: tab completion in an interactive shell falls back to
    bash's built-in filename completion. Nothing scripted changes.
    Requires: nothing.
    Source: found by lab, exp #61, backlog item `e25`
  '';

  config = lib.mkIf cfg.enable {
    programs.bash.completion.enable = false;

    system.forbiddenDependenciesRegexes = [ "-bash-completion-" ];
  };
}
