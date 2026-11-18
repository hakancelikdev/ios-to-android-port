#!/usr/bin/env bash
#
# ios_cite.sh — GENERATES the source citation of an iOS view/component (never write one by hand).
#
# Why this exists: hand-written iOS citations were the most frequent recurring error class of the
# original port. In one session three separate reviews caught wrong citations in four different ways:
#
#   1. **Wrong directory.** A `Features/<X>/Components/` subdirectory was skipped and the port said
#      "no iOS counterpart, inferred" — all three components did have one.
#   2. **Reading stopped early.** Only two lines of a file were read and a modifier one line below
#      (a custom press-feedback style) was missed → a real parity loss.
#   3. **Right file, WRONG role.** A toolbar action-icon component was cited for the back button;
#      its doc-comment said what it was for. The right one was another type in the same file.
#   4. **Line drift.** The cited line was the last doc-comment line, the declaration was one below.
#
# The script closes all four: it scans the whole tree, gives the exact declaration line, prints
# the doc-comment ABOVE it (the component's ROLE) and lists EVERY style/feedback call in the body
# with line numbers.
#
# Usage:
#   tools/port/ios_cite.sh SettingsRow             # by symbol
#   tools/port/ios_cite.sh SettingsView.swift      # by file
#   tools/port/ios_cite.sh SettingsView.swift 402  # file + body from that line
#
# Output is ready to paste into a code comment (paths relative to the iOS repo root).
# Every chained modifier is listed; to also catch your own modifiers used inline, set IOS_CITE_EXTRA="cardStyle|pressFeedback" in port.env.

set -euo pipefail
# shellcheck source=_env.sh
. "$(dirname "$0")/_env.sh"

IOS_BASE="$(bash tools/port/ios_ref.sh --path)"
IOS_ROOT="$IOS_BASE/$IOS_SRC"
readonly IOS_BASE IOS_ROOT
# Worktree copies, build output: citing from there points at a path that does not exist.
readonly PRUNE=( -path '*/.claude/*' -o -path '*/.build/*' -o -path '*/DerivedData/*' -o -path '*/Pods/*' )
# Modifiers that carry visual identity and interaction — the answer to "what does it look/feel like".
# ⚠️ Bracket classes are REQUIRED: BSD awk (macOS) rejects `\.` and `\(` as "illegal primary". In
# the first version awk's error was swallowed and the script printed "NO style in body" — exactly
# the wrong answer it exists to prevent. That is why an awk failure is now fatal (die_on_awk).
MODS='buttonStyle|foregroundStyle|foregroundColor|tint|font|background|clipShape|cornerRadius|padding|frame|shadow|opacity|animation|transition|sensoryFeedback|contentShape|onTapGesture|onLongPressGesture|swipeActions|contextMenu|accessibilityLabel|accessibilityElement|accessibilityAction'
[ -n "${IOS_CITE_EXTRA:-}" ] && MODS="$MODS|$IOS_CITE_EXTRA"
# Two halves: (1) EVERY chained modifier that starts a line — so a project's own modifiers (a custom
# press-feedback style, a card style) are listed without being configured; (2) the known names above
# when they appear inline (`Text("x").font(.body)`).
STYLE_RE="(^[[:space:]]*[.][A-Za-z_][A-Za-z0-9_]*[(])|([.]($MODS)[(])"
readonly STYLE_RE

if [ $# -eq 0 ]; then
    sed -n '3,27p' "tools/port/ios_cite.sh" | sed 's/^# \{0,1\}//'
    exit 1
fi

if [ ! -d "$IOS_ROOT" ]; then
    echo "❌ iOS source root not found: $IOS_ROOT"
    exit 1
fi

rel() { printf '%s\n' "${1#"$IOS_BASE"/}"; }

find_swift() { find "$IOS_ROOT" \( "${PRUNE[@]}" \) -prune -o -name "$1" -print; }

# Prints the doc-comment ABOVE a declaration — that is where the component says what it is for.
# Error 3 (right file, wrong role) came from exactly this not being read.
print_doc() {
    local file=$1 line=$2
    awk -v target="$line" '
        NR < target && /^[[:space:]]*\/\/\// { if (!started) { start = NR; started = 1 } buf[NR] = $0; next }
        NR < target { started = 0; delete buf; start = 0 }
        NR == target {
            if (start > 0) { for (i = start; i < target; i++) if (i in buf) printf "  %4d %s\n", i, buf[i] }
            exit
        }
    ' "$file"
}

# A sub-command failing silently would make this script give the WRONG answer ("no counterpart"),
# the opposite of what it must produce. So a failure is fatal.
die_on_awk() {
    echo "❌ Scan crashed ($1) — do NOT trust the output, do not write a citation." >&2
    exit 2
}

# Style calls in a declaration's body. End of body: the next top-level declaration (unindented
# `struct`/`class`/`extension`/`enum`) or end of file. Error 2 (stopping early) came from doing this
# by hand — here the body is scanned to its END.
print_body_styles() {
    local file=$1 line=$2
    awk -v start="$line" -v re="$STYLE_RE" '
        NR < start { next }
        NR > start && /^((public|private|fileprivate|internal|final) )*(struct|class|extension|enum|actor)[[:space:]]/ { exit }
        $0 ~ re { printf "  %4d %s\n", NR, $0 }
    ' "$file" || die_on_awk "print_body_styles $file"
}

# ⚠️ A single `grep -rn` pass. It used to be nested `find | while read | grep` and returned
# **silently wrong** results: it found the symbol under `bash -x` and said "not found" otherwise
# (nested process substitution). "No counterpart" is the most expensive answer a citation tool can
# give wrongly, so the logic is one pass.
report_symbol() {
    local sym=$1 found=0 file ln
    local decl="(struct|final class|class|actor|enum|extension|protocol|func|var|let)"
    local mods="(public |private |internal |fileprivate |static |@MainActor )*"
    while IFS=: read -r file ln _; do
        [ -n "${ln:-}" ] || continue
        found=1
        echo "╭─ $(rel "$file"):$ln"
        local doc; doc=$(print_doc "$file" "$ln")
        if [ -n "$doc" ]; then
            echo "│  ROLE (doc-comment) — ⚠️ read this BEFORE writing the citation:"
            printf '%s\n' "$doc" | sed 's/^/│/'
        else
            echo "│  (no doc-comment)"
        fi
        echo "│  declaration:"
        sed -n "${ln}p" "$file" | sed "s/^/│   $(printf '%4d' "$ln") /"
        local styles; styles=$(print_body_styles "$file" "$ln")
        if [ -n "$styles" ]; then
            echo "│  style/feedback calls in the body (ALL of them):"
            printf '%s\n' "$styles" | sed 's/^/│/'
        else
            echo "│  ⚠️ NO style/feedback modifiers in the body."
            echo "│     FIRST: it may DELEGATE to another component — check the doc-comment above"
            echo "│     and run this script again for the component it delegates to."
            echo "│     (Typical case: a BackButton with no style in its body that wraps a"
            echo "│      CircleIconButton — the style lives there.)"
            echo "│     ONLY THEN: if there really is no counterpart, write \"inferred\" in the"
            echo "│     code comment and say what it is based on."
        fi
        echo "╰─"
        echo
    done < <(grep -rnE "^[[:space:]]*${mods}${decl}[[:space:]]+${sym}([^A-Za-z0-9_]|\$)" \
        --include='*.swift' "$IOS_ROOT" 2>/dev/null \
        | grep -vE '/(\.claude|\.build|DerivedData|Pods)/' || true)
    return $((1 - found))
}

report_file() {
    local name=$1 start=${2:-1} hits=0
    while IFS= read -r file; do
        hits=1
        echo "╭─ $(rel "$file")  (from line ${start})"
        awk -v start="$start" -v re="$STYLE_RE" '
            NR >= start && $0 ~ re { printf "│  %4d %s\n", NR, $0 }
        ' "$file" || die_on_awk "report_file $file"
        echo "╰─"
        echo
    done < <(find_swift "$name")
    return $((1 - hits))
}

arg=$1
if [[ "$arg" == *.swift ]]; then
    report_file "$arg" "${2:-1}" || { echo "❌ File not found: $arg"; exit 1; }
else
    report_symbol "$arg" || {
        echo "❌ No declaration found for '$arg'."
        echo "   This does NOT mean 'no iOS counterpart' — the name may differ. Search first:"
        echo "   find $IOS_ROOT -name '*<part>*'  ·  grep -rn '<visible text>' $IOS_ROOT"
        exit 1
    }
fi
