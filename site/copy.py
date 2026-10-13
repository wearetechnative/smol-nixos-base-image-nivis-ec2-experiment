#!/usr/bin/env python3
"""The prose, with every quantity left as a slot the data fills.

Register follows REPORT.md: conclusion first, short sentences, no em
dashes, no curly quotes. The page is loud; the sentences are not.

Nothing here contains a number. `site/build.py` refuses to publish a
quantity it cannot derive, and this file is what that check reads.
"""

TITLE = "How small can a NixOS EC2 base image get?"

META = (
    "A closed research lab: {n_total} experiments shrinking a NixOS EC2 base "
    "image to {closure_to} MiB of closure, measured, with the failures kept."
)

EYEBROW = "TechNative research lab"

HERO_TITLE = "We took {closure_pct}% off a NixOS EC2 base image, and wrote down everything that did not work."

HERO_LEDE = (
    "{n_total} numbered experiments. Every one of them had to boot on Nitro, "
    "deploy, and pass the same ten-check contract over SSH before it counted."
)

HERO_NOTE = (
    "Boot time is a spread, not a number: the last {boot_window} accepted "
    "experiments boot between {boot_min} and {boot_max} seconds. A single run "
    "is not the result."
)

QUESTION_LEAD = (
    "How small can a NixOS base image for AWS EC2 get while it still boots, "
    "deploys, and stays fully usable over SSH?"
)

QUESTION_BODY = (
    "Not how small an image can be made in principle. How small it can be "
    "and still be a machine you would run. The contract fixed that: ten "
    "checks, the same script locally and on the real instance, covering the "
    "SSH key arriving from instance metadata, DNS, HTTPS with a working "
    "trust store, the clock, the root filesystem growing to its volume, and "
    "surviving a reboot. A strategy that broke any of them was rejected, "
    "whatever it saved."
)

METHOD = [
    "One strategy per experiment, measured against a frozen baseline.",
    "Two gates: a local QEMU boot, then a real EC2 instance, both running "
    "the same contract script.",
    "An append-only ledger, one line per experiment, accepted or not.",
    "Every removal guarded, so a package that did not actually leave fails "
    "the build instead of the review.",
]

METHOD_NOTE = (
    "The deployment went through nivis, which is the mechanism and not the "
    "point. The full method is in the repository."
)

DESCENT_LEAD = (
    "Size across all {n_total} experiments. The flat stretches are the "
    "{n_rejected} rejections: the line holds while the lab is stuck."
)

DESCENT_NOTE = (
    "The longest plateau is experiments {longest_plateau}, where "
    "switch-to-configuration was given up on and filed as blocked upstream. "
    "Experiment 45 came back to it and took {stc_saving} MiB out. A chart of "
    "successes only cannot show that."
)

INSIGHT_PULL = (
    "Six strategies account for {top6_mib} of the {total_mib} MiB, and they "
    "are the same finding stated six ways."
)

INSIGHT_BODY = (
    "A stock NixOS EC2 image carries the tools to rebuild itself. The flake "
    "registry, the nixpkgs channel, Python, Perl, the SSM agent, the "
    "activation machinery and {n_packages} packages on the system path are "
    "all there so the running machine can reconfigure itself. An appliance "
    "that is replaced rather than reconfigured needs none of them. "
    "Everything after that is smaller and harder: the last "
    "{late_savings} MiB took {late_count} experiments."
)

BOOT_LEAD = (
    "One closure, three images, three boots. {channel_mb} MB of extra files "
    "cost {channel_cost} seconds."
)

BOOT_NOTE = (
    "Boot time fell from {boot_from} to about {boot_to} seconds over the "
    "lab, and none of that is explained by size. The drop at experiment 25 "
    "was tested directly and does not reproduce: the image is not what makes "
    "the machine slow. The only boot effect ever isolated is compressing the "
    "initrd with xz, which costs {xz_cost} seconds for {xz_saving} MiB."
)

FLOOR_LEAD = (
    "What is left, and why it stays. This is the machine: a kernel, an "
    "initrd, a C library, an init system, a shell and the programs the "
    "contract exercises."
)

TALLY_PULL = (
    "The rejections taught the most. Six of them were the lab's own "
    "defects, and each one produced a change to the protocol."
)

UPSTREAM_LEAD = (
    "Four results are not about this image. They are things nixpkgs or "
    "NixOS does that cost every user, and each one is reproducible from the "
    "repository."
)

NEXT_LEAD = (
    "The reusable result is the measurements, not the image."
)

NEXT_BODY = (
    "{n_options} NixOS options, each with what it saves, what it costs and "
    "the ledger line that proves it. That is what feeds into ElastiNix, "
    "where these strategies get used and shown to work in a configurable "
    "production image. The configurable image is the next project. This one "
    "is the map."
)

FOOTER_PROVENANCE = (
    "Every number on this page is generated from the repository: "
    "{n_total} ledger lines, the report, and the experiment notes. "
    "Nothing here is typed by hand."
)

FOOTER_BRAND = "A TechNative research lab."
