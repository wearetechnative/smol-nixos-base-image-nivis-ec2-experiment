# 014: no-firewall

- **Track:** appliance | mutable
- **Contract:** 1
- **Module:** `smol.<name>`
- **Branch:** `exp/NNN-<slug>`
- **Commit:** `<short sha>`
- **Source:** <URL of the prior art, or "found by lab, exp #NNN">

## Hypothesis

<One paragraph. What should get smaller, by what mechanism, and roughly how
much. State it before running anything.>

## What changed

<The module, in a few lines. Link to the file rather than pasting it.>

## Numbers

| measure | before | after | delta |
| ------------------ | ---- | ---- | ---- |
| closure            |      |      |      |
| image, raw         |      |      |      |
| image, compressed  |      |      |      |

Top store paths that moved:

<From `just measure`, only the ones that actually changed.>

## Gate 1, local

<Pass or fail. On failure: which contract check, and the relevant lines of the
serial log. Never paste the whole log.>

## Gate 2, EC2

<Pass or fail. Boot time. On failure: the serial console output from
`just console <instance>`.>

Teardown: <confirm the instance, AMI and snapshot are gone.>

## Decision

<Accepted or rejected, and the one-line reason. Accepted means both gates
passed and the size went down. A rejected experiment keeps its branch.>

## Surprises

<Anything that belongs in GOTCHAS.md. Copy it there too.>
