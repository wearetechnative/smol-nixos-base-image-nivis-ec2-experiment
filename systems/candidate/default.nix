# baseline + the smol.* toggles currently under test.
#
# Exactly one experiment lives here at a time (BRIEFING §8). Reset to the
# accepted set after every experiment.
{ ... }:
{
  imports = [ ../accepted ];

  smol.noSwitchToConfiguration.enable = true;
}
