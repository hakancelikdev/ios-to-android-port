#!/usr/bin/env bash
#
# ios_ref.sh — prints the path of the iOS REFERENCE ($IOS_REPO on $IOS_BRANCH, from port.env).
#
# Why: the iOS spec is the default branch, read directly from your iOS checkout. If that checkout
# is on a release or feature branch, reading from it ports unreleased behavior to Android — so the
# script stops when the branch is wrong. It never switches branches or pulls: it is your working
# copy and may hold uncommitted work.
#
# Usage:
#   bash tools/port/ios_ref.sh           # verify branch + fetch, warn when behind origin, print path
#   bash tools/port/ios_ref.sh --path    # no fetch: verify branch, print path
#   IOS=$(bash tools/port/ios_ref.sh --path)
#
# Exit: 0 ok · 2 iOS repo not found · 3 wrong branch.

set -euo pipefail
# shellcheck source=_env.sh
. "$(dirname "$0")/_env.sh"

if [ ! -e "$IOS_REPO/.git" ] || [ ! -d "$IOS_REPO/$IOS_SRC" ]; then
  echo "❌ iOS repo not found: $IOS_REPO (expected source root: $IOS_REPO/$IOS_SRC) — check IOS_REPO / IOS_SRC in port.env" >&2
  exit 2
fi

current="$(git -C "$IOS_REPO" rev-parse --abbrev-ref HEAD)"
if [ "$current" != "$IOS_BRANCH" ]; then
  echo "❌ $IOS_REPO is on '$current' — the iOS reference is '$IOS_BRANCH'. The owner switches branches; the tool never does." >&2
  exit 3
fi

if [ "${1:-}" != "--path" ]; then
  # fetch only updates remote refs; the working copy is untouched. Pulling stays with the owner.
  if git -C "$IOS_REPO" fetch -q origin "$IOS_BRANCH" 2>/dev/null; then
    behind="$(git -C "$IOS_REPO" rev-list --count "HEAD..origin/$IOS_BRANCH")"
    if [ "$behind" -gt 0 ]; then
      echo "⚠️  $IOS_REPO local '$IOS_BRANCH' is $behind commit(s) behind origin/$IOS_BRANCH (git -C $IOS_REPO pull --ff-only)." >&2
    fi
  else
    echo "⚠️  could not fetch origin/$IOS_BRANCH (offline?) — using local '$IOS_BRANCH'." >&2
  fi
fi

printf '%s\n' "$IOS_REPO"
