# Visual parity ledger

> Single source of truth = the table below. Counts are never kept by hand:
> `bash tools/port/visual_parity_check.sh` derives them (STATUS/DOING/NEXT_TODO/parity%).
> Round narrative → `visual-parity-history.md` (append-only, the loop doesn't read it).
>
> Columns: status = **7th field**. **At most one** `doing`. Statuses: `todo · doing · done · blocked · n-a`.
> The reason for `blocked` goes in Findings; a wholly missing feature → open a todo in `parity-ledger.md`, `blocked` here.
>
> **iOS refs:** `docs/port/ios-reference/<png>`; the iOS tap-paths live in `docs/port/ios-reference/manifest.json`.
> **Tap-path (Android):** concrete `id:` / `text:` / `desc:` selectors; ` > ` = consecutive taps (see the skill).

<!-- BOOTSTRAP — the first `/ios-visual-parity` invocation captures the iOS references, replaces the example rows
  below with the real routes, deletes this comment, commits and stops. -->

## Top level

| ID | Screen/Route | iOS ref | Android route | Tap-path | Status | Findings | Commit |
|----|--------------|---------|---------------|----------|--------|----------|--------|
| VP-01 | Home (example) | home.png | HomeScreen | text:Home | todo | | |
| VP-02 | Settings (example) | settings.png | SettingsScreen | desc:Settings | todo | | |
