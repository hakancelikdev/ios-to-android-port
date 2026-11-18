# shellcheck shell=bash
# _env.sh — sourced by every port script. Moves to the Android repo root and loads tools/port/port.env.

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 2

if [ ! -f tools/port/port.env ]; then
  echo "❌ tools/port/port.env not found — copy tools/port/port.env.example and edit it." >&2
  exit 2
fi
# shellcheck disable=SC1091
. tools/port/port.env

: "${IOS_REPO:?IOS_REPO is not set in tools/port/port.env}"
IOS_BRANCH="${IOS_BRANCH:-main}"
IOS_SRC="${IOS_SRC:-.}"
PUSH_REMOTE="${PUSH_REMOTE:-origin}"
PUSH_BRANCH="${PUSH_BRANCH:-main}"
if [ -n "${JAVA_HOME_OVERRIDE:-}" ] && [ -d "$JAVA_HOME_OVERRIDE" ]; then
  export JAVA_HOME="$JAVA_HOME_OVERRIDE"
fi
