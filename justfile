# smol lab recipes. Every AWS call goes through here with AWS_PROFILE from
# lab/config.env (BRIEFING §7).

set shell := ["bash", "-euo", "pipefail", "-c"]

system := "x86_64-linux"

_default:
    @just --list --unsorted

# --- housekeeping ----------------------------------------------------------

# Snapshot the jj working copy so nix sees new files, then check the flake.
check:
    jj st > /dev/null
    nix flake check --print-build-logs

fmt:
    jj st > /dev/null
    nix fmt .
    nix develop -c shfmt -w -i 2 lab/*.sh
    nix develop -c shellcheck -x -P lab lab/*.sh

# Regenerate docs/options.md from the smol.* option descriptions.
docs:
    jj st > /dev/null
    nix build --no-link --print-out-paths .#packages.{{ system }}.options-doc \
      | xargs -I{} install -m644 {} docs/options.md
    @echo "docs/options.md regenerated"

# --- building and measuring ------------------------------------------------

build variant="candidate":
    jj st > /dev/null
    nix build --no-link --print-out-paths \
      .#nixosConfigurations.{{ variant }}-{{ system }}.config.system.build.toplevel

measure variant="candidate":
    ./lab/measure.sh {{ variant }} {{ system }}

# --- gates -----------------------------------------------------------------

# Gate 1: boot the variant in QEMU and run the verification contract over SSH.
gate1 variant="candidate":
    jj st > /dev/null
    nix build --print-build-logs --no-link .#checks.{{ system }}.verify-{{ variant }}

# Gate 1 with an interactive test driver, for debugging a failing boot.
gate1-debug variant="candidate":
    jj st > /dev/null
    nix run .#checks.{{ system }}.verify-{{ variant }}.driverInteractive

# Gate 2: deploy through nivis, verify, reboot, verify, tear down.
gate2 experiment:
    ./lab/deploy-ec2.sh {{ experiment }}

# --- EC2 housekeeping ------------------------------------------------------

# Create the access key for smol-lab-ci and wire up both profiles. Pim runs
# this, with his own admin profile. The secret is never printed.
aws-key admin_profile:
    ./lab/aws-key.sh {{ admin_profile }}

# Prove the assumed role works and a tagged launch would be permitted.
aws-check:
    ./lab/aws-check.sh

# Terminate and deregister everything tagged Project=smol-lab.
reap:
    ./lab/reap.sh

console instance:
    ./lab/console.sh {{ instance }}

# --- the experiment pipeline ----------------------------------------------

# Run one full experiment: build, measure, gate 1, gate 2, decide, log.
experiment slug:
    ./lab/experiment.sh {{ slug }}

# --- project bookkeeping ---------------------------------------------------

# Milestones, epics and the active OpenSpec changes.
status:
    @beans list
    @echo
    @openspec list

# What is ready to pick up next.
next:
    @beans list --ready
    @openspec list
