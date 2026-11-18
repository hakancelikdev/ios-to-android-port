#!/usr/bin/env bash
# parity_check.sh — measures iOS → Android parity deterministically FROM THE LEDGER TABLE.
#
# The loop's instrument: "you can't optimize what you can't see." Keeping the count in prose
# drifts (a summary says "148" while the table holds 144). This script counts the single
# source of truth (the table) → resume is O(1) and the goal is measurable.
#
# Usage:  bash tools/port/parity_check.sh [ledger.md]
# Output: machine-readable lines (PARITY / PARITY_PCT / NEXT_TODO / DOING / BLOCKED / STATUS).
# Exit:   0 ok · 2 no ledger · 3 more than one `doing` (resume hazard) · 4 unparseable status cell.
#
# Table shapes:
#   Section tables : | ID | Feature / Screen | iOS source | Android target | Status | Commit | Note |  (status = 5th cell)
#   "## n/a" table : | Feature | Reason |                                                        (every row counts as n/a)

set -euo pipefail
cd "$(dirname "$0")/../.."

LEDGER="${1:-docs/port/parity-ledger.md}"

if [[ ! -f "$LEDGER" ]]; then
  echo "❌ Ledger not found: $LEDGER" >&2
  exit 2
fi

# The shipped template carries a BOOTSTRAP comment; until the first invocation replaces it with the real
# inventory the example rows must not be picked up as work.
if grep -q '^<!-- BOOTSTRAP' "$LEDGER"; then
  echo "STATUS: BOOTSTRAP — ledger is still the template; run skill step 1 (inventory → ledger → commit), nothing else"
  exit 0
fi

LC_NUMERIC=C awk '
  # A table header is whatever row sits directly above a |---| separator — so ledgers written in any
  # language parse (no hardcoded "ID"/"Feature" names). Rows are held one line, then counted.
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function count_row(line, nr, sec,   f, id, st) {
    split(line, f, "|")
    id = trim(f[2]); st = trim(f[6])
    total++
    if (sec ~ /^n\/a/) { count["n/a"]++; return }       # n/a section: 2 columns, all iOS-only
    # An unrecognised status would otherwise be counted SILENTLY wrong. Most common cause: a raw
    # pipe in a cell BEFORE the status column shifts the fields (pipes after it are harmless). Fail loudly.
    if (st != "todo" && st != "doing" && st != "done" && st != "blocked" && st != "n/a") {
        bad_status = bad_status "  line " nr ": id=" id " status=\"" st "\"\n"
    }
    count[st]++
    if (st=="todo"  && next_todo=="") { next_todo=id; next_sec=sec }
    if (st=="doing")   doing_list  = doing_list   (doing_list==""?""  :",") id
    if (st=="blocked") blocked_list= blocked_list (blocked_list==""?"":",") id
  }
  function flush() { if (pending != "") count_row(pending, pending_nr, pending_sec); pending = "" }
  BEGIN { section=""; pending="" }
  /^\|[ \t:|-]+$/ { pending = ""; next }                    # separator: the held row was the header
  /^\|/ { flush(); pending=$0; pending_nr=NR; pending_sec=section; next }
  { flush() }
  /^## / { section=$0; sub(/^## +/,"",section) }
  END {
    flush()
    d=count["done"]+0; t=count["todo"]+0; g=count["doing"]+0
    b=count["blocked"]+0; n=count["n/a"]+0
    denom=d+t+g+b                                 # n/a does not count towards parity
    pct=(denom>0)?(d*100.0/denom):0
    if (bad_status != "") {
        printf "❌ Unrecognised status cell — table is broken (raw `|` before the Status column?):\n%s", bad_status
        printf "   Valid values: todo · doing · done · blocked · n/a\n"
        exit 4
    }
    printf "PARITY: done=%d todo=%d doing=%d blocked=%d na=%d total=%d\n", d,t,g,b,n,total
    printf "PARITY_PCT: %.1f\n", pct
    printf "NEXT_TODO: %s\n", (next_todo=="" ? "-" : next_todo (next_sec==""?"":"  ["next_sec"]"))
    printf "DOING: %s\n",   (doing_list==""  ? "-" : doing_list)
    printf "BLOCKED: %s\n", (blocked_list=="" ? "-" : blocked_list)
    if (g>1)                 { print "STATUS: MULTI_DOING — exactly one `doing` allowed, resume gets confused"; exit 3 }
    else if (g==1)           print "STATUS: RESUME — finish or clean up the half-done `doing` task (skill step 0)"
    else if (next_todo!="")  print "STATUS: WORK — next todo can be taken"
    else                     print "STATUS: QUEUE_EXHAUSTED — no cleanly-actionable todo; iOS sync or owner-gated"
  }
' "$LEDGER"
