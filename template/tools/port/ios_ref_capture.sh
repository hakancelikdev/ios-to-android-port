#!/usr/bin/env bash
# ios_ref_capture.sh — iOS GOLDEN REFERENCE capture primitives for the visual-parity loop.
# One-off (bootstrap) and re-run when iOS changes. The loop does NOT depend on this script —
# it only produces/refreshes the reference gallery in docs/port/ios-reference/.
#
# Usage:
#   ios_ref_capture.sh check                  # idb + booted simulator check
#   ios_ref_capture.sh screenshot <out.png>   # via simctl (no idb needed)
#   ios_ref_capture.sh describe               # idb ui describe-all (JSON accessibility tree)
#   ios_ref_capture.sh tap <x> <y>            # idb ui tap (raw point coordinates)
#   ios_ref_capture.sh tap-label <label>      # resolve label from describe-all, tap its centre
#
# Exit: 0 ok · 4 no idb · 5 no booted simulator · 6 label did not match · 7 no working python3

set -euo pipefail

booted_udid() {
  xcrun simctl list devices booted 2>/dev/null \
    | grep -oE '\(([0-9A-F-]{36})\) \(Booted\)' | grep -oE '[0-9A-F-]{36}' | head -1
}

need_idb() {
  if ! command -v idb >/dev/null 2>&1; then
    cat >&2 <<'MSG'
❌ idb is not installed. To capture iOS references (one-off):

    brew tap facebook/fb
    brew install idb-companion
    python3 -m pip install --user fb-idb      # then put the pip --user bin dir on PATH

Then boot the simulator:  idb list-targets   (the booted sim must be listed)
Note: the loop does NOT depend on idb — only reference capture uses this script.
MSG
    exit 4
  fi
}

resolve_py() {
  local candidates=("${PY_BIN:-}" "python3" "/usr/bin/python3" "/opt/homebrew/bin/python3")
  local candidate
  for candidate in "${candidates[@]}"; do
    [ -z "$candidate" ] && continue
    if "$candidate" -c 'import json' 2>/dev/null; then
      PY="$candidate"
      return 0
    fi
  done
  echo "❌ No working python3 (cannot import json). Set PY_BIN to a valid interpreter." >&2
  exit 7
}

case "${1:-}" in
  check)
    udid="$(booted_udid || true)"
    if [ -z "$udid" ]; then
      echo "❌ No booted iOS simulator. Start one from Xcode → Simulator." >&2
      exit 5
    fi
    echo "booted sim: $udid"
    if command -v idb >/dev/null 2>&1; then
      echo "idb: installed ($(idb --version 2>/dev/null | head -1))"
    else
      need_idb
    fi
    ;;
  screenshot)
    out="${2:?out.png required}"
    udid="$(booted_udid || true)"
    [ -z "$udid" ] && { echo "❌ No booted simulator" >&2; exit 5; }
    mkdir -p "$(dirname "$out")"
    xcrun simctl io "$udid" screenshot "$out"
    echo "$out"
    ;;
  describe)
    need_idb
    idb ui describe-all
    ;;
  tap)
    need_idb
    x="${2:?x required}"; y="${3:?y required}"
    idb ui tap "$x" "$y"
    echo "tapped $x $y"
    ;;
  tap-label)
    need_idb
    label="${2:?label required}"
    resolve_py
    json_file="${TMPDIR:-/tmp}/port-ios-describe-all.json"
    idb ui describe-all > "$json_file"
    coords="$("$PY" - "$json_file" "$label" <<'PY'
import sys, json

path, label = sys.argv[1], sys.argv[2]
with open(path) as f:
    text = f.read()

try:
    parsed = json.loads(text)
except json.JSONDecodeError:
    # Some idb versions print NDJSON (one JSON object per line).
    parsed = [json.loads(line) for line in text.splitlines() if line.strip()]

elements = parsed if isinstance(parsed, list) else [parsed]
keys = ("AXLabel", "title", "AXValue")


def find(predicate):
    for key in keys:
        for el in elements:
            if not isinstance(el, dict):
                continue
            v = el.get(key)
            if isinstance(v, str) and predicate(v):
                return el
    return None


match = find(lambda v: v == label) or find(lambda v: label.lower() in v.lower())
if match is not None:
    frame = match.get("frame") or {}
    try:
        x = float(frame["x"]); y = float(frame["y"])
        w = float(frame["width"]); h = float(frame["height"])
        print(f"{x + w / 2:g} {y + h / 2:g}")
    except (KeyError, TypeError, ValueError):
        pass
PY
)"
    if [ -z "$coords" ]; then
      echo "❌ label did not match: $label" >&2
      exit 6
    fi
    # shellcheck disable=SC2086
    idb ui tap $coords
    echo "tapped label:$label @ $coords"
    ;;
  *)
    echo "usage: ios_ref_capture.sh {check|screenshot <out>|describe|tap <x> <y>|tap-label <label>}" >&2
    exit 1
    ;;
esac
