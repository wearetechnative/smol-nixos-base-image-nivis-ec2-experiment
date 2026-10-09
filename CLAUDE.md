# smol NixOS base image, working agreement

`BRIEFING.md` is the source of truth for what this lab does and why. This file
is about how the work is run. Where the two disagree, the briefing wins.

## Start of every session

Pim kicks off with `/smol`. That command does the reading for you. If you are
here through another route, read `BRIEFING.md` and `STATE.md` first.

## Tooling

| what | tool |
| ---------------------- | ----------------------------------------- |
| milestones and epics   | `beans` |
| proposals and tasks    | `openspec` |
| version control        | `jj` (colocated with git, remote `origin`) |
| build, test, deploy    | `nix` flakes + `just` |

Enter the dev shell with `nix develop`, or let `just` recipes handle it.

## Work breakdown

Milestones and epics live in beans. A milestone title starts with an
incrementing two-digit number (`01 `, `02 `, …). Epics hang under a milestone
with `--parent`. Concrete work hangs under an epic.

Everything inside an epic goes through OpenSpec:

1. `/openspec-propose`: one change per coherent piece of work.
2. `/openspec-apply-change`: implement it, keep the tasks checked off as you
   go.
3. `/openspec-archive-change`: fold the deltas into the specs.
4. Commit immediately after archiving (see below).

Keep the epic's bean body in step with the OpenSpec change: check items off as
they happen, and close the bean only when nothing is unchecked. Close it with
a `## Summary of Changes` section.

## Version control

`jj` is colocated with git. Two things follow from that:

- **`jj` only exports to the git index when it snapshots.** Nix reads that
  index to decide which files belong to the flake, so a file you just wrote is
  invisible to `nix build` until a `jj` command has run. Every `just` recipe
  that calls nix runs `jj st` first. Do the same in ad-hoc commands.
- Commit as Pim Snel. No `Co-authored-by`, no `Generated with`, no Claude or
  Anthropic attribution anywhere in a commit message.

Commit after every `openspec archive`, not in batches:

```sh
jj commit -m "<what changed>"
jj git push
```

An experiment additionally commits its own ledger line and experiment note
(BRIEFING §8.6).

## Nix conventions

- Flakes, plain `nixpkgs.lib.genAttrs` over a `systems` list. **No
  `flake-utils`.**
- Never pass a prebuilt `pkgs` to `nixosSystem`. Strategies install
  `nixpkgs.overlays` from inside `config`, and those are ignored when `pkgs`
  comes in prebuilt. Pass `nixpkgs.hostPlatform` as a module instead.
- `systems/baseline` is frozen after phase 0. Every measurement in
  `ledger.jsonl` is relative to it.
- One strategy per file in `modules/smol/`, one `smol.<name>.enable` option,
  written exactly as BRIEFING §5 prescribes.
- `nix fmt` before committing.

## Testing

Two gates, both running the same contract script, `lab/verify.sh`:

- **Gate 1**, `just gate1 <variant>`: boots the variant under the NixOS test
  driver and runs the contract over SSH from a second node, then reboots and
  runs it again.
- **Gate 2**, `just gate2 <experiment>`: deploys through nivis to EC2 and runs
  the same contract there, where the metadata key injection and the real
  drivers can be proven.

A candidate is accepted only when both gates pass *and* the closure shrank.
See `docs/TESTING.md`.

Anything gate 1 cannot cover is forced off in `lab/test-support/qemu.nix`.
Every line in that file is a hole in the local gate, so keep it short and keep
each line justified.

## AWS

Lab operations go through `just` recipes that use `AWS_PROFILE=smol-lab`.
Prefer them over a bare `aws` call, so every AWS access has a name and a
place.

Since the 2026-10-09 amendment to BRIEFING §7 you may run
`infra/iam/bootstrap.sh` yourself, with the admin profile in
`lab/config.env`, to apply a corrected IAM policy. That means you can widen
your own permissions, so widen them deliberately: change the policy file,
commit it with the reason, and say in your reply what you granted and why.
Never reach for a wildcard because a specific action is tedious to find.

Unchanged, and not negotiable: never read, print or commit anything from
`~/.aws/`; never print a secret; never ask Pim to paste a key or token into
the chat.

Order of operations when a deploy is denied:

1. `just aws-probe` to reproduce it in seconds rather than a 2.6 GB upload.
2. Fix `infra/iam/SmolLabRole-permissions.json`.
3. `./infra/iam/bootstrap.sh $SMOL_ADMIN_PROFILE`.
4. Record what changed in `GOTCHAS.md` or `experiments/000-nivis.md`.

## Keeping track

`just status` prints the milestones, epics and active changes. `just next`
prints what is ready to pick up. `beans roadmap` is broken in the installed
version, see `GOTCHAS.md`.

## Writing

- Short prose. Conclusion first, reasoning after and only when asked.
- No em dashes, no en dashes, no curly quotes.
- No comments in code unless a spec, a bean or this file requires them. The
  comments that do exist here explain *why*, never *what*.
