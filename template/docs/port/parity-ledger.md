# iOS → Android parity ledger

> Single source of truth. The `ios-port` skill finds its place in this file.
> Status: `todo` · `doing` · `done` · `blocked` · `n/a`. **At most one** `doing` at a time. Every `done` row maps to a commit.

**Status (live):** `bash tools/port/parity_check.sh` — never keep counts by hand.
**Picking work:** the first `todo` in table order (sections are in dependency order). Android paths are bootstrap estimates; verify with `find` when taking a task.
**iOS source paths** are relative to `IOS_REPO`. Bootstrap iOS HEAD: `<sha>` (`docs/port/.ios-sync-marker`).
**Owner tasks:** `docs/port/owner-action-items.md` (Note column: `owner #N`). Round narrative → `docs/port/port-history.md`.
**Never put a raw `|` in a cell before Status** — it shifts the columns (`parity_check.sh` exits 4).

---

<!-- BOOTSTRAP — the first `/ios-port` invocation replaces everything below with the real inventory
  (iOS features in dependency order, what Android already has marked `done`), commits it and stops.
  The rows below only show the shape — delete them.
-->

## 00 — Skeleton

| ID | Feature / Screen | iOS source | Android target | Status | Commit | Note |
|----|------------------|------------|----------------|--------|--------|------|
| 00-01 | Gradle skeleton (modules, DI, Compose, static analysis) | — | settings.gradle.kts, app/ | done | — | bootstrap |
| 00-02 | Port loop: skill, ledger, tools/port scripts | — | .claude/, tools/port/ | done | — | bootstrap |

## 01 — Domain core

| ID | Feature / Screen | iOS source | Android target | Status | Commit | Note |
|----|------------------|------------|----------------|--------|--------|------|
| 01-01 | Example: core models | MyApp/Domain/Models.swift | domain/Models.kt | todo | | tests pinned to iOS outputs |

## n/a — iOS-only, not ported

| Feature | Reason |
|---------|--------|
| Apple Watch app | not targeted on Android |
