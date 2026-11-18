#!/usr/bin/env bash
# android_nav.sh — Android driver of the visual-parity loop.
# screencap + uiautomator dump parsing + selector-based tap. FIXED-PIXEL TAPS ARE FORBIDDEN:
# the tap target is resolved at runtime by resource-id/text/content-desc → device independent.
#
# Usage:
#   android_nav.sh launch                     # force-stop + start (deterministic reset)
#   android_nav.sh screenshot <out.png>
#   android_nav.sh clickables                 # TSV: text \t resource-id \t content-desc \t cx \t cy
#   android_nav.sh tap <id:RID | text:T | desc:D>
#   android_nav.sh idle                       # wait until the UI is stable
#
# Package/activity: ANDROID_PKG / ANDROID_ACTIVITY in port.env. adb: $ADB, else $ANDROID_HOME, else PATH.
# Exit: 0 ok · 5 no device · 6 selector did not match · 7 no working python3

set -euo pipefail
# shellcheck source=_env.sh
. "$(dirname "$0")/_env.sh"

if [ -z "${ADB:-}" ]; then
  for cand in "${ANDROID_HOME:-}/platform-tools/adb" "$HOME/Library/Android/sdk/platform-tools/adb" "$HOME/Android/Sdk/platform-tools/adb"; do
    [ -x "$cand" ] && { ADB="$cand"; break; }
  done
  ADB="${ADB:-adb}"
fi
PKG="${ANDROID_PKG:?ANDROID_PKG is not set in port.env}"
ACT="${ANDROID_ACTIVITY:?ANDROID_ACTIVITY is not set in port.env}"
TMP_XML="${TMPDIR:-/tmp}/port-window_dump.xml"

resolve_py() {
  local candidates=("${PY_BIN:-}" "python3" "/usr/bin/python3" "/opt/homebrew/bin/python3")
  local candidate
  for candidate in "${candidates[@]}"; do
    [ -z "$candidate" ] && continue
    if "$candidate" -c 'import xml.etree.ElementTree' 2>/dev/null; then
      PY="$candidate"
      return 0
    fi
  done
  echo "❌ No working python3 (cannot import xml.etree.ElementTree). Set PY_BIN to a valid interpreter." >&2
  exit 7
}

require_device() {
  if ! "$ADB" get-state >/dev/null 2>&1; then
    echo "❌ No Android device connected (adb get-state failed). Start the emulator." >&2
    exit 5
  fi
}

dump_xml() {
  require_device
  "$ADB" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1 || true
  "$ADB" pull /sdcard/window_dump.xml "$TMP_XML" >/dev/null 2>&1
  echo "$TMP_XML"
}

case "${1:-}" in
  launch)
    require_device
    # Deterministic reset: without force-stop the app stays on a pushed sub-screen and
    # `am start` does NOT reset it → the next navigation tap fails.
    "$ADB" shell am force-stop "$PKG" >/dev/null 2>&1 || true
    "$ADB" shell am start -n "$PKG/$ACT" >/dev/null
    echo "launched $PKG"
    ;;
  screenshot)
    require_device
    out="${2:?out.png required}"
    mkdir -p "$(dirname "$out")"
    "$ADB" exec-out screencap -p > "$out"
    echo "$out"
    ;;
  idle)
    # Stable when two consecutive dumps hash the same (max ~3 s)
    require_device
    prev=""
    for _ in 1 2 3 4 5 6; do
      cur="$("$ADB" shell uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1; "$ADB" shell cat /sdcard/window_dump.xml 2>/dev/null | cksum | cut -d' ' -f1)"
      [ -n "$cur" ] && [ "$cur" = "$prev" ] && { echo "idle"; exit 0; }
      prev="$cur"
      "$ADB" shell sleep 0.4 >/dev/null 2>&1 || true
    done
    echo "idle(timeout)"
    ;;
  clickables)
    resolve_py
    xml="$(dump_xml)"
    "$PY" - "$xml" <<'PY'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
for n in tree.iter('node'):
    if n.get('clickable') != 'true':
        continue
    nums = n.get('bounds', '').replace('][', ',').strip('[]').split(',')
    if len(nums) != 4:
        continue
    x1, y1, x2, y2 = map(int, nums)
    cx, cy = (x1 + x2)//2, (y1 + y2)//2
    text = (n.get('text') or '').replace('\t', ' ')
    rid = n.get('resource-id') or ''
    desc = (n.get('content-desc') or '').replace('\t', ' ')
    print(f"{text}\t{rid}\t{desc}\t{cx}\t{cy}")
PY
    ;;
  tap)
    resolve_py
    sel="${2:?selector required: id:RID | text:T | desc:D}"
    kind="${sel%%:*}"; val="${sel#*:}"
    xml="$(dump_xml)"
    coords="$("$PY" - "$xml" "$kind" "$val" <<'PY'
import sys, xml.etree.ElementTree as ET
xml, kind, val = sys.argv[1], sys.argv[2], sys.argv[3]
attr = {'id': 'resource-id', 'text': 'text', 'desc': 'content-desc'}.get(kind)
if attr is None:
    sys.exit(0)
for n in ET.parse(xml).iter('node'):
    v = n.get(attr) or ''
    # id: full or short (last segment) match; text/desc: exact match
    hit = (v == val) or (kind == 'id' and v.split('/')[-1] == val)
    if not hit:
        continue
    nums = (n.get('bounds', '').replace('][', ',').strip('[]').split(','))
    if len(nums) == 4:
        x1, y1, x2, y2 = map(int, nums)
        print((x1+x2)//2, (y1+y2)//2)
        break
PY
)"
    if [ -z "$coords" ]; then
      echo "❌ selector did not match: $sel" >&2
      exit 6
    fi
    # shellcheck disable=SC2086
    "$ADB" shell input tap $coords >/dev/null
    echo "tapped $sel @ $coords"
    ;;
  *)
    echo "usage: android_nav.sh {launch|screenshot <out>|clickables|tap <sel>|idle}" >&2
    exit 1
    ;;
esac
