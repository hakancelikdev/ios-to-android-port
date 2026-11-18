#!/usr/bin/env bash
# ios_sync_scan.sh — deterministically lists new user-facing iOS commits that are not ported yet.
#
# The PROACTIVE loop's instrument (same task, changing input = "did iOS ship something new?").
# When the queue is exhausted (parity_check.sh → QUEUE_EXHAUSTED) this is the real next move.
# The loop does the semantic judgement (which commit becomes a ledger todo); this script only
# gives the CHEAP first filter: "you have not looked at these commits".
#
# Usage:
#   bash tools/port/ios_sync_scan.sh             # user-facing iOS commits since the marker
#   bash tools/port/ios_sync_scan.sh --set HEAD  # after a sync round: advance the marker to iOS HEAD
#   bash tools/port/ios_sync_scan.sh --set <sha>
#
# Marker: docs/port/.ios-sync-marker (last synced iOS commit SHA; a plain file, committed).
# Scanned paths: IOS_SYNC_PATHS in port.env. Exit: 0 ok · 2 iOS repo not available.
#
# NOTE: without a marker it does NOT silently pin to HEAD (that would hide every accumulated
# commit — the "silent cap" anti-pattern). It lists from IOS_SYNC_SINCE and says loudly that the
# marker is unset; the loop advances it with --set after processing.

set -euo pipefail
# shellcheck source=_env.sh
. "$(dirname "$0")/_env.sh"

MARKER_FILE="docs/port/.ios-sync-marker"
FALLBACK_SINCE="${IOS_SYNC_SINCE:-1970-01-01}"
read -r -a PATHS <<< "${IOS_SYNC_PATHS:-$IOS_SRC}"

IOS="$(bash tools/port/ios_ref.sh)" || { echo "❌ iOS reference not available (ios_ref.sh)" >&2; exit 2; }
IOS_HEAD="$(git -C "$IOS" rev-parse --short HEAD)"

if [ "${1:-}" = "--set" ]; then
  target="${2:-HEAD}"
  sha="$(git -C "$IOS" rev-parse --short "$target")"
  printf '%s\n' "$sha" > "$MARKER_FILE"
  echo "✅ marker updated: $MARKER_FILE → $sha  (iOS repo: $IOS)"
  exit 0
fi

echo "IOS_REPO: $IOS"
echo "IOS_HEAD: $IOS_HEAD"

if [ -f "$MARKER_FILE" ]; then
  MARKER="$(tr -d '[:space:]' < "$MARKER_FILE")"
  if git -C "$IOS" cat-file -e "${MARKER}^{commit}" 2>/dev/null; then
    RANGE="${MARKER}..HEAD"; SCOPE_DESC="marker $MARKER → HEAD"
  else
    echo "⚠️  marker ($MARKER) is not in the iOS repo (rebase / different clone?) — falling back to the date"
    RANGE=""; SCOPE_DESC="fallback --since=$FALLBACK_SINCE (invalid marker)"
  fi
else
  echo "⚠️  NO MARKER — first run. Listing from the fallback date so accumulated commits are not hidden."
  RANGE=""; SCOPE_DESC="fallback --since=$FALLBACK_SINCE (marker unset)"
fi
echo "SCOPE: $SCOPE_DESC"

if [ -n "$RANGE" ]; then
  COMMITS="$(git -C "$IOS" log --oneline "$RANGE" -- "${PATHS[@]}" 2>/dev/null || true)"
else
  COMMITS="$(git -C "$IOS" log --oneline --since="$FALLBACK_SINCE" -- "${PATHS[@]}" 2>/dev/null || true)"
fi

COUNT="$(printf '%s' "$COMMITS" | grep -c . || true)"
echo "NEW_COMMITS: $COUNT   (user-facing: ${PATHS[*]})"
echo "---"
if [ "$COUNT" -eq 0 ]; then
  echo "iOS is in sync — no new user-facing commits to evaluate."
else
  printf '%s\n' "$COMMITS"
  echo "---"
  echo "NEXT: evaluate each commit for parity → open ledger \`todo\` row(s) → port."
  echo "When the sync round is done:  bash tools/port/ios_sync_scan.sh --set HEAD"
fi
