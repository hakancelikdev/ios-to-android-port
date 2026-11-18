#!/usr/bin/env bash
# install.sh — installs the iOS → Android port loop into an Android repo.
#
# Usage:
#   ./install.sh <android-repo> [--ios <path-to-ios-repo-relative-to-android-repo>] [--force]
#
# Copies template/ into the Android repo (skills, rule, reviewer agent, tools/port/ scripts, ledger
# templates). Existing files are never overwritten unless --force is given. Creates
# tools/port/port.env from the example on first install. Touches nothing outside the target repo.

set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/template"
TARGET=""
IOS=""
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --ios) IOS="${2:?--ios needs a path}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) [ -z "$TARGET" ] || { echo "❌ unexpected argument: $1" >&2; exit 1; }; TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ -d "$TARGET" ] || { echo "❌ not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
[ -e "$TARGET/.git" ] || echo "⚠️  $TARGET is not a git repo — the loop commits and pushes every task; run git init first."
[ -e "$TARGET/settings.gradle.kts" ] || [ -e "$TARGET/settings.gradle" ] || echo "⚠️  no settings.gradle(.kts) in $TARGET — is this the Android repo?"

copied=0; skipped=()
while IFS= read -r -d '' file; do
  rel="${file#"$SRC"/}"
  dest="$TARGET/$rel"
  # Ledgers, history and the reference gallery are the project's own data: never overwritten, even with --force.
  if [ -e "$dest" ] && { [ "$FORCE" -eq 0 ] || [[ "$rel" == docs/port/* ]]; }; then
    skipped+=("$rel")
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$file" "$dest"
  copied=$((copied + 1))
done < <(find "$SRC" -type f ! -name '.DS_Store' -print0)

chmod +x "$TARGET"/tools/port/*.sh "$TARGET"/tools/port/*.py

ENV="$TARGET/tools/port/port.env"
if [ ! -f "$ENV" ]; then
  cp "$TARGET/tools/port/port.env.example" "$ENV"
  echo "✅ created tools/port/port.env from the example"
fi
if [ -n "$IOS" ]; then
  tmp="$(mktemp)"
  sed "s|^IOS_REPO=.*|IOS_REPO=\"$IOS\"|" "$ENV" > "$tmp" && mv "$tmp" "$ENV"
  echo "✅ IOS_REPO=\"$IOS\""
fi

echo "✅ $copied file(s) installed into $TARGET"
if [ "${#skipped[@]}" -gt 0 ]; then
  echo "ℹ️  kept ${#skipped[@]} existing file(s) (use --force to overwrite):"
  printf '     %s\n' "${skipped[@]}"
fi

cat <<EOF

Next steps (in $TARGET):
  1. Edit tools/port/port.env — IOS_REPO, IOS_SRC, IOS_SYNC_PATHS, LANGS, ANDROID_PKG, GATE_CMD, PUSH_BRANCH.
  2. Check the setup:      bash tools/port/ios_ref.sh && bash tools/port/parity_check.sh
  3. Add the CLAUDE.md section and the permission allowlist from the README (so /loop runs unattended).
  4. Open Claude Code in the Android repo and run:   /ios-port
     The first invocation only builds the ledger from your iOS app and commits it. Review it, then:
                                                     /loop /ios-port
EOF
