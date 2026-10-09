Continue the smol lab.

Read `BRIEFING.md` and `STATE.md` first. `BRIEFING.md` is the source of truth;
where anything else contradicts it, the briefing wins.

1. Read `ledger.jsonl` (last 20 lines), `BACKLOG.md`, `GOTCHAS.md`,
   `FLOOR.md`. Run `beans list --ready` and `openspec list`.
2. If `STATE.md` lists live AWS resources: run `just reap` before anything
   else, then clear the table.
3. If an experiment is half-done: finish it or roll it back, and log that
   either way. Never start a second experiment on top of an unfinished one.
4. Check the stop criteria (BRIEFING §9). If they are met for a track, write
   `REPORT.md` for that track and stop.
5. Otherwise run the next experiment via the `smol-experimenter` subagent,
   then log it, update `STATE.md`, and commit. Repeat. Write a checkpoint in
   `STATE.md` every 5 experiments.
6. Stop and ask Pim only for: contract changes, nivis gaps, budget limits, or
   decisions the briefing says are his.

Bookkeeping, every time:

- Work is tracked in beans. Keep the epic's bean current as you go, and close
  it only when every one of its todo items is checked.
- Work inside an epic is proposed, applied and archived through OpenSpec.
  Commit with `jj` right after each `openspec archive`, never in a batch.
- Keep messages to Pim short: what happened since last time, current best size
  per track, what is next, and any decision needed from him.
