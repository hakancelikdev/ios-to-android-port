#!/usr/bin/env bash
# run.sh — runs the project commands configured in port.env with the right environment.
#
# Usage:
#   bash tools/port/run.sh format   # FORMAT_CMD — run BEFORE the gate
#   bash tools/port/run.sh gate     # GATE_CMD + parity_check.sh; exit 0 only when everything is green
#   bash tools/port/run.sh app      # RUN_CMD — start the app once (the gate never launches it)
#
# Tip: gradle piped into `tail`/`head` loses its exit code. Redirect instead:
#   bash tools/port/run.sh gate > "$TMPDIR/port-gate.log" 2>&1; echo "GATE=$?"

set -euo pipefail
# shellcheck source=_env.sh
. "$(dirname "$0")/_env.sh"

case "${1:-}" in
  format)
    [ -n "${FORMAT_CMD:-}" ] || { echo "ℹ️  FORMAT_CMD empty — nothing to format."; exit 0; }
    bash -c "$FORMAT_CMD"
    ;;
  gate)
    : "${GATE_CMD:?GATE_CMD is not set in port.env}"
    bash -c "$GATE_CMD"
    bash tools/port/parity_check.sh
    if [ -f docs/port/visual-parity-ledger.md ]; then bash tools/port/visual_parity_check.sh; fi
    echo "✅ gate green"
    ;;
  app)
    : "${RUN_CMD:?RUN_CMD is not set in port.env}"
    bash -c "$RUN_CMD"
    bash tools/port/android_nav.sh launch
    ;;
  *)
    echo "usage: run.sh {format|gate|app}" >&2
    exit 1
    ;;
esac
