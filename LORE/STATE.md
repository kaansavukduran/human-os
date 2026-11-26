# STATE: where are we now? (2026-11-25)
Şu an neredeyiz, sıradaki adım, açık işler. Machine cursor wins: [CURRENT_STATE.json](../project_state/CURRENT_STATE.json).

## Last verified step
- CONFIRMED · 2026-11-26 · U045@v0.32 closed (selected rail label font and size, whole date patterns EN/TR incl. the lab date helper, rail-only rail count, rendered-colour theme check); 14 gates PASS (EV-*-F007-1678…1691). Q008 closed before it.

## Next step
- PLANNED · Q009@v0.32: full screen matrix after U045 in Chromium (all groups with the new theme and rail checks; lab date helper and correction errors in a cell).

## Open questions for the owner
- PROPOSED · GitHub Pages: `pages.yml` needs the one-time setting Settings > Pages > Source: GitHub Actions (owner only).
- CONFIRMED · 2026-11-25 · `docs/lore/` (fictional Aion lore, D-051) stays (owner).
- CONFIRMED · 2026-11-25 · LORE adopted; CLAUDE.md and AGENTS.md are the short routers (owner).
- PROPOSED · Decision source of truth: full text stays in `project_state/DECISIONS.md`, LORE holds 5-line summaries with the same id (see [GENERATE.md](GENERATE.md)). Confirm or pick one.
- CONFIRMED · 2026-11-25 · The private backup-folder id is no longer kept in the repository (owner).
- UNKNOWN · Dates of D-003…D-007 and D-022 are not written in the source.
- UNKNOWN · Live Linux app id: D-012 target `com.humanos.HumanHealthOS` vs `org.humanhealthos.HumanHealthOS(.Encrypted)` named in D-049.
- UNKNOWN · Duplicate ids: D-029 (two entries, here D-029a/D-029b); G-70 and G-71 (two rows each in KNOWN_GAPS).
- UNKNOWN · G-03 ("no Dart engines") and G-11 ("CI never run") read as stale against D-037/D-038 and later CI work; not re-checked.
- UNKNOWN · ADR-IMPL-001, D-001 and D-002 have no entry in `project_state/DECISIONS.md`.

## Open gaps (top 10 of [KNOWN_GAPS.md](../project_state/KNOWN_GAPS.md); risks: [RISKS.md](../project_state/RISKS.md))
- G-71 signed packages, Android key continuity, Apple notarization/store, trusted updater, two-package update drill; an update check needs an owner decision on network use.
- G-32 encrypted browser storage: non-development web builds are memory only.
- G-27 lab interpretation engine exists in Dart but is not wired into the app.
- G-76 (narrowed) development records under another SELF profile are refused, not merged; other-platform file choosers NOT_RUN.
- G-31 no import of external formats (CSV, FHIR, documents).
- G-33 no passphrase change or data-key rotation outside recovery.
- G-35 removal of the newest encrypted entries cannot be detected.
- G-13 OS key stores as a convenience unlock are not built.
- G-43 one canonical unit per kind; no conversion, no UCUM.
- G-10 no SessionStart hook to reinstall Flutter in fresh cloud containers.
