# iOS parity — the iOS app is the specification

**Owner decision:** Android reproduces the iOS experience as closely as the platform allows — **design, behavior, usability, everything**. The iOS app (`IOS_REPO` in `tools/port/port.env`) is the spec; Android is not a Material 3 reinterpretation of it. Don't ask the owner design/calibration questions ("native or iOS-like?", "neutral or atmospheric?") — the answer is always "like iOS". This covers *every* parity call: pick the iOS behavior, and where it genuinely cannot be matched, deviate and write the reason in the ledger's Note column. A row must not be parked as `blocked` merely because a choice exists; `blocked` is for work that needs something the code cannot supply (source data, an external account, a Play/legal constraint, an owner-created product).

## Which iOS — `IOS_REPO` on `IOS_BRANCH`
The spec is the iOS checkout on its reference branch (default `main`), read directly. `bash tools/port/ios_ref.sh` checks the branch: if the checkout is on anything else (e.g. a release branch), it stops — porting from a release branch ships unreleased iOS behavior. It also fetches and warns when the local branch is behind `origin`. `ios_cite.sh`, `ios_sync_scan.sh`, `ios_stale_strings.py` and `ios_strings_import.py` all read this checkout. It is the owner's working copy: never commit, edit, pull or switch branches in it — if it is on the wrong branch or behind, tell the owner.

## What must match iOS
- **Information architecture:** same tabs and tab model, same screens, same grouping (an iOS sub-screen is an Android sub-screen — never scatter its rows inline), same entry points, same section/row order.
- **Visual:** layout, hierarchy, spacing (iOS pt → dp 1:1), corner radii, typography scale and weights, colors (same hex values, same token roles), icon meaning and weight (SF Symbol → closest Material Symbol or a ported vector; iOS custom glyphs are ported as vectors), backgrounds, empty states, glass surfaces (see below).
- **Behavior:** flows and their steps, defaults, loading/empty/error states, what tap / long-press / swipe does, confirmations, undo, sorting, validation, persistence semantics, notification content and timing, widget content.
- **Domain logic:** a line-by-line port of the Swift. Same input → same output, pinned by unit tests with expectations taken from iOS. Watch Swift integer semantics (`&+`, `&*` wrapping, `UInt64`) → Kotlin `Long`/`ULong` bit for bit; seeded randomness must give the same sequence on both platforms.
- **Copy:** same meaning and tone in every language, translated from the iOS values (not from scratch).
- **Motion & haptics:** iOS timing and feel are the spec. Read the SwiftUI animation (duration / spring response + damping) and reproduce it in Compose, then compare side by side; don't substitute Material defaults.
- **Analytics:** same event names and params as iOS so one dashboard covers both platforms.

## How to build it
- Before writing Compose, read the SwiftUI view, its ViewModel and the tokens it uses; port **values** (sizes, colors, copy, order, thresholds), not just intent.
- Material 3 components are implementation tools, not the look: restyle them (colors, shapes, typography, indicators, pressed states) until they match iOS. Build a custom component when Material can't reach the iOS look or behavior — and keep semantics (role, state description, ≥48 dp target, TalkBack actions).
- **Glass:** where iOS shows Liquid Glass / materials, Android shows the closest approximation — a translucent surface + blur where the API allows (31+; a library like Haze is fine) + hairline separator. Never an opaque Material card where iOS has glass.
- **Font:** SF Pro can't ship (license) → pick the closest (e.g. Inter) and match iOS sizes, weights and tracking.
- Every ported type carries a KDoc marker `iOS \`<SwiftName>\` counterpart` so `grep -rn "iOS \`X\`"` finds it — Android file names don't follow iOS names, searching by file name produces false "missing" rows.
- Android-only additions (Material You toggle, app shortcuts) are allowed only if the **default** experience stays identical to iOS (e.g. Material You off by default).

## Legitimate differences — only these, each with a one-line reason in code or ledger
- **System-mandated:** system back button/gesture (incl. predictive back) works everywhere; runtime permission flows (notifications, exact alarms, background location), notification channels, battery-optimization prompts; edge-to-edge system bars, IME, share sheet, file/photo pickers, Play Billing and in-app review APIs.
- **No iOS twin / different system surface:** Live Activity → ongoing notification / Live Update; WidgetKit → Glance (same content and layout within Glance's limits); Control Center → Quick Settings tile; Siri App Intents → app shortcuts; Game Center → Play Games Services; iCloud sync → Auto Backup / Block Store; Apple Watch / Mac → not targeted.
- **Unavailable technology:** Liquid Glass shader, SF Pro / SF Symbols → closest approximation as above.
- **Play Store policy / legal.**
- **Accessibility floor:** if a faithful copy of iOS fails a *measurable* accessibility threshold — WCAG contrast (AA 4.5:1 body / AA-large 3:1), the 48 dp touch target, or an action TalkBack cannot reach — Android deviates the smallest way that keeps iOS's visual intent and records the measurement as the reason. iOS having the same defect is not a reason to ship it. ⚠️ Check first whether iOS really has the defect — often iOS already uses a different token there and the Android "defect" is a plain parity bug.
- **Owner-decided exceptions:** list them here, each with a date and scope, e.g.
  - *(example)* **Tab bar (YYYY-MM-DD):** native Material 3 `NavigationBar` instead of the floating iOS capsule — **look only**; the iOS tab *model* (slots, order, reselect-pops-to-root) still holds. Do not reopen as a parity bug.

Everything else that differs is a **parity bug**. "Material convention", "Android users expect…", "native IA" are not reasons.

## Verify before calling something a gap
Confirm in the Swift source (`find "$IOS_REPO/$IOS_SRC" -iname '*X*'`, `bash tools/port/ios_cite.sh <Symbol>`). Never write an iOS citation by hand. Apparent gaps are sometimes iOS behavior (a row iOS deliberately hides, a feature gated off on iOS too) — adding them would break parity.

## Tools
- Feature / behavior / IA gaps: `ios-port` skill → `docs/port/parity-ledger.md`.
- Screen-by-screen visual comparison: `ios-visual-parity` skill → `docs/port/visual-parity-ledger.md` + iOS reference screenshots.
