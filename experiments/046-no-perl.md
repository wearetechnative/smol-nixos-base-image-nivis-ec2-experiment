# 046: no-perl, second attempt

Accepted. 58.00 MiB closure, 68.00 MiB raw image.

**The module did not change by one character since experiment 37**, where it
saved nothing. `install-grub.pl` was the other holder of perl, and
experiment 45 removed `switch-to-configuration` along with it.

That is worth stating as a rule rather than an anecdote: a strategy that
measures zero is not necessarily wrong, it may be waiting for a different
holder to leave. Experiment 37 recorded it as `needs-upstream` with the
module kept and not enabled, specifically so that this would be one toggle
rather than a rediscovery. It was.

Gate 1 and gate 2 both pass. Boot time 14.657s. Teardown complete.
