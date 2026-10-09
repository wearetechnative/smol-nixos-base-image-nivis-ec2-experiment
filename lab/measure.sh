#!/usr/bin/env bash
# Measure a system variant (BRIEFING §8.2) and print one JSON object on stdout.
#
#   lab/measure.sh <variant> [system]
#
# Fields: closure_bytes, image_bytes, image_compressed_bytes, top_paths.
# image_* stay 0 until lab/deploy-ec2.sh can produce an image; measure.sh
# never guesses a number it did not observe.
set -euo pipefail

variant="${1:?usage: measure.sh <baseline|candidate|accepted> [system]}"
system="${2:-x86_64-linux}"
attr=".#nixosConfigurations.${variant}-${system}.config.system.build.toplevel"

logdir="${SMOL_LOG_DIR:-experiments/logs}"
mkdir -p "$logdir"
buildlog="$logdir/measure-${variant}-${system}.log"

toplevel=$(nix build --no-link --print-out-paths "$attr" 2>"$buildlog")

closure=$(nix path-info --closure-size --json --json-format 1 "$toplevel" |
  jq '[.[].closureSize] | add')

top=$(nix path-info --recursive --size --json --json-format 1 "$toplevel" |
  jq '[to_entries[] | {path: .key, bytes: .value.narSize}]
      | sort_by(-.bytes) | .[0:20]')

image_bytes=0
image_compressed_bytes=0
if [ -n "${SMOL_IMAGE:-}" ] && [ -f "${SMOL_IMAGE}" ]; then
  image_bytes=$(stat -c %s "$SMOL_IMAGE")
fi
if [ -n "${SMOL_IMAGE_COMPRESSED:-}" ] && [ -f "${SMOL_IMAGE_COMPRESSED}" ]; then
  image_compressed_bytes=$(stat -c %s "$SMOL_IMAGE_COMPRESSED")
fi

jq -n \
  --arg variant "$variant" \
  --arg system "$system" \
  --arg toplevel "$toplevel" \
  --argjson closure "$closure" \
  --argjson image_bytes "$image_bytes" \
  --argjson image_compressed_bytes "$image_compressed_bytes" \
  --argjson top "$top" \
  '{variant: $variant, system: $system, toplevel: $toplevel,
    closure_bytes: $closure, image_bytes: $image_bytes,
    image_compressed_bytes: $image_compressed_bytes, top_paths: $top}'
