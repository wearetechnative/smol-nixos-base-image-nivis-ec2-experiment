#!/usr/bin/env bash
#
# One experiment, end to end (BRIEFING §8).
#
#   just experiment <slug>
#
# Build, measure, gate 1, gate 2, decide, log. A ledger line is appended on
# every path, including a failure: a rejected experiment is a result, and the
# ledger is the only place a number is allowed to come from.
#
# Build output goes to experiments/logs/. Only a summary reaches stdout.
set -uo pipefail

SLUG="${1:?usage: just experiment <slug>}"
TRACK="${SMOL_TRACK:-appliance}"
CONTRACT=1

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
cd "$repo" || exit 1

SYSTEM="${SMOL_SYSTEM:-x86_64-linux}"
LOG_DIR="$repo/experiments/logs"
mkdir -p "$LOG_DIR"

say() { printf '==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }

# jj only exports to the git index when it snapshots, and nix reads that index
# to decide what belongs to the flake (GOTCHAS.md).
jj st >/dev/null 2>&1 || true

ID=$(( $(jq -s 'map(.id) | max // 0' ledger.jsonl) + 1 ))
NNN=$(printf '%03d' "$ID")
NOTE="experiments/${NNN}-${SLUG}.md"
GIT=$(jj log -r @ --no-graph -T 'commit_id.short()' 2>/dev/null || echo unknown)

gate1=skip
gate2=skip
decision=rejected
reason=""
closure_before=0
closure_after=0
image_bytes=0
boot_seconds=null

finish() {
  jq -c -n \
    --argjson id "$ID" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg slug "$SLUG" \
    --arg track "$TRACK" \
    --argjson contract "$CONTRACT" \
    --arg hypothesis "${SMOL_HYPOTHESIS:-}" \
    --arg module "${SMOL_MODULE:-}" \
    --arg source "${SMOL_SOURCE:-}" \
    --arg git "$GIT" \
    --argjson cb "$closure_before" \
    --argjson ca "$closure_after" \
    --argjson ib "$image_bytes" \
    --arg g1 "$gate1" \
    --arg g2 "$gate2" \
    --argjson bs "$boot_seconds" \
    --arg decision "$decision" \
    --arg reason "$reason" \
    --arg notes "$NOTE" \
    '{id:$id, ts:$ts, slug:$slug, track:$track, contract:$contract,
      hypothesis:$hypothesis, module:$module, source:$source, git:$git,
      closure_before:$cb, closure_after:$ca,
      image_bytes:$ib, image_compressed_bytes:0,
      gate1:$g1, gate2:$g2, boot_seconds:$bs,
      decision:$decision, reason:$reason, notes:$notes}' >>"$repo/ledger.jsonl"

  say "ledger line $ID: $decision${reason:+ ($reason)}"
  [ -e "$NOTE" ] || {
    sed -e "s/^# NNN: <slug>/# ${NNN}: ${SLUG}/" experiments/TEMPLATE.md >"$NOTE"
    note "wrote $NOTE from the template, fill it in"
  }
}

say "experiment $NNN $SLUG, track $TRACK, contract $CONTRACT"

# --- 1. build --------------------------------------------------------------
say "building"
if ! nix build --no-link \
  ".#nixosConfigurations.candidate-${SYSTEM}.config.system.build.toplevel" \
  >"$LOG_DIR/${NNN}-build.log" 2>&1; then
  reason="build failed"
  note "$reason, see experiments/logs/${NNN}-build.log"
  tail -15 "$LOG_DIR/${NNN}-build.log"
  finish
  exit 1
fi

# --- 2. measure ------------------------------------------------------------
say "measuring"
img=$(nix build --no-link --print-out-paths \
  ".#packages.${SYSTEM}.image-candidate" 2>>"$LOG_DIR/${NNN}-build.log" | tail -1)
vhd=$(find "$img" -name '*.vhd' 2>/dev/null | head -1)

acc=$(./lab/measure.sh accepted "$SYSTEM" 2>/dev/null)
cand=$(SMOL_IMAGE="$vhd" ./lab/measure.sh candidate "$SYSTEM" 2>/dev/null)
closure_before=$(printf '%s' "$acc" | jq '.closure_bytes')
closure_after=$(printf '%s' "$cand" | jq '.closure_bytes')
image_bytes=$(printf '%s' "$cand" | jq '.image_bytes')
printf '%s' "$cand" >"$LOG_DIR/${NNN}-measure.json"

delta=$((closure_before - closure_after))
pct=$(awk -v d="$delta" -v b="$closure_before" 'BEGIN{printf "%.2f", (b?d*100/b:0)}')
note "closure $((closure_before / 1048576)) MiB -> $((closure_after / 1048576)) MiB ($((delta / 1048576)) MiB, ${pct}%)"

if [ "$delta" -le 0 ] && [ "${SMOL_ENABLING_REFACTOR:-0}" != 1 ]; then
  reason="not smaller than accepted"
  note "$reason; set SMOL_ENABLING_REFACTOR=1 if that is the point"
  finish
  exit 1
fi

# --- 3. gate 1, local ------------------------------------------------------
say "gate 1, local"
if nix build --no-link ".#checks.${SYSTEM}.verify-candidate" \
  >"$LOG_DIR/${NNN}-gate1.log" 2>&1; then
  gate1=pass
  note "pass"
else
  gate1=fail
  reason="gate 1 failed"
  note "$reason, see experiments/logs/${NNN}-gate1.log"
  grep -E "not ok|VERIFY FAIL" "$LOG_DIR/${NNN}-gate1.log" | head -10
  finish
  exit 1
fi

# --- 4. gate 2, EC2 --------------------------------------------------------
if [ "${SMOL_SKIP_GATE2:-0}" = 1 ]; then
  note "gate 2 skipped by request"
  decision=undecided
  reason="gate 2 skipped"
  finish
  exit 0
fi

say "gate 2, EC2"
summary=$(./lab/deploy-ec2.sh "${NNN}-${SLUG}" candidate 2>&1 | tee /dev/stderr | tail -1)
gate2=$(printf '%s' "$summary" | jq -r '.gate2 // "fail"' 2>/dev/null || echo fail)
boot_seconds=$(printf '%s' "$summary" | jq -r '.boot_seconds // "null"' 2>/dev/null || echo null)
[ "$boot_seconds" = "" ] && boot_seconds=null

if [ "$gate2" != pass ]; then
  reason="gate 2 failed"
  note "$reason"
  finish
  exit 1
fi

# --- 5. decide -------------------------------------------------------------
decision=accepted
say "ACCEPTED: $((delta / 1048576)) MiB (${pct}%), both gates pass"
note "now enable it in systems/accepted, put the numbers in the option description, and reset systems/candidate"
finish
