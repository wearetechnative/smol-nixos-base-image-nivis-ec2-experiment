#!/usr/bin/env bash
#
# Fetch an instance's serial console output. The only evidence there is when
# an instance never answers SSH, which is the failure mode a size reduction
# causes most often: a missing ENA or NVMe driver, or a kernel panic at root
# mount.
#
#   just console <instance-id> [experiment-id]
#
# ec2:GetConsoleOutput has no provider resource, so this calls the AWS API
# directly. Read-only, on an instance tagged Project=smol-lab, approved by
# Pim on 2026-10-09 (experiments/000-nivis.md gap 1).
set -euo pipefail

INSTANCE="${1:?usage: just console <instance-id> [experiment-id]}"
EXPERIMENT="${2:-$INSTANCE}"

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
# shellcheck source=aws-env.sh
. "$here/aws-env.sh"
smol_write_profiles

out="$repo/experiments/logs/${EXPERIMENT}-console.log"
mkdir -p "$(dirname "$out")"

# AWS buffers console output; right after a launch it can still be empty.
for attempt in 1 2 3 4 5 6; do
  text=$(aws ec2 get-console-output --instance-id "$INSTANCE" \
    --query Output --output text 2>/dev/null || true)
  case "$text" in
    "" | None)
      echo "console output not available yet, retry $attempt" >&2
      sleep 10
      ;;
    *)
      printf '%s\n' "$text" >"$out"
      echo "serial console written to ${out#"$repo"/} ($(wc -l <"$out") lines)"
      exit 0
      ;;
  esac
done

echo "no serial console output for $INSTANCE after six attempts" >&2
echo "the instance may never have reached the bootloader" >&2
exit 1
