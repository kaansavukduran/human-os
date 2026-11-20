# Screen matrix (Chromium) at d0078775b3c6

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-20T04:03:56.029Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `b7a6d17b03c2d6f6003a93098d9246d3b1bf48348be81739c81a9b8613281430` · debug build sha256 `a60e80b35a9709531330f41d01eb0c61128245d41d321677835bc0dc151deb64`

**162 cells: 162 PASS, 0 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## base

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR | phone 390x844 · en-US | phone 390x844 · tr-TR | tablet-portrait 820x1180 · en-US | tablet-portrait 820x1180 · tr-TR | tablet-landscape 1180x820 · en-US | tablet-landscape 1180x820 · tr-TR | desktop 1440x900 · en-US | desktop 1440x900 · tr-TR |
|---|---|---|---|---|---|---|---|---|---|---|
| Today | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Timeline | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Labs | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Medications | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Nutrition | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Activity | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Conditions | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Preventive | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Documents | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Settings | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |

## palette-matrix

| Screen | phone 390x844 · en-US | desktop 1440x900 · en-US |
|---|---|---|
| Settings | PASS | PASS |
| Today | PASS | PASS |

## palette-axolotl

| Screen | phone 390x844 · en-US | desktop 1440x900 · en-US |
|---|---|---|
| Settings | PASS | PASS |
| Today | PASS | PASS |

## palette-trans

| Screen | phone 390x844 · en-US | desktop 1440x900 · en-US |
|---|---|---|
| Settings | PASS | PASS |
| Today | PASS | PASS |

## text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today | PASS | PASS |
| Timeline | PASS | PASS |
| Labs | PASS | PASS |
| Medications | PASS | PASS |
| Nutrition | PASS | PASS |
| Activity | PASS | PASS |
| Conditions | PASS | PASS |
| Preventive | PASS | PASS |
| Documents | PASS | PASS |
| Settings | PASS | PASS |

## sheets

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Labs: add sheet | PASS | PASS | PASS | PASS |
| Labs: more from the report | PASS | PASS | PASS | PASS |
| Settings: palettes | PASS | PASS | PASS | PASS |
| Settings: app lock | PASS | PASS | PASS | PASS |
| Today: restore from file | PASS | PASS | PASS | PASS |

## sheets-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Labs: add sheet | PASS | PASS |
| Labs: more from the report | PASS | PASS |
| Settings: palettes | PASS | PASS |
| Settings: app lock | PASS | PASS |
| Today: restore from file | PASS | PASS |

## FAIL list

None.

## NOT TESTED

| What | Status | Reason |
|---|---|---|
| Real Android phones and tablets | NOT TESTED | not available in this container |
| Real iPhones and iPads (iOS/iPadOS) | NOT TESTED | not available in this container |
| Windows desktop app | NOT TESTED | not available in this container |
| macOS desktop app | NOT TESTED | not available in this container |
| Firefox | NOT TESTED | not available in this container |
| Safari | NOT TESTED | not available in this container |
| Screen readers: TalkBack | NOT TESTED | not available in this container |
| Screen readers: VoiceOver | NOT TESTED | not available in this container |
| Screen readers: NVDA | NOT TESTED | not available in this container |
## Q002 notes (added by hand after the run)

First run of the Q001 matrix at f67e5d1 (before Q002): 132 cells, 132 PASS, 0 FAIL. The 30 new `sheets` / `sheets-text-2x` cells are new in Q002.

App defects found while building the new cells, fixed in this commit with widget regression tests:

- **Settings section titles were no headings.** `Semantics(header: true)` without `container` merged each title into its whole section, so the web exposed a `<header>` landmark labelled "Lock after inactivity" plus the lock reason, and no heading for Palette, Language, Theme, the lock and others. Fix: `container: true` in the section helper (settings_screen.dart). Test: f006s2_app_lock_test.dart (the title is its own header node; the reason is its own text).
- **Restore entry feedback out of view.** "No file chosen" (and any refusal) appears in the card's status line above the explanation and the restore-from-file entry. At 320x640 (1× and 2× text, EN and TR) and on the desktop in TR it was scrolled out of sight after a tap on the entry. Fix: a new status message scrolls into view when it is not visible (your_data_card.dart). Test: f005s2_web_restore_test.dart (320 dp, 2× text). The `restore_cancel_reported` check now requires the message on screen within 1 s.
- **App shell overflow with the on-screen keyboard open** (reported by another agent): 320x640, 2× text, Turkish, an entry sheet open and a 320 px keyboard inset overflowed the shell column by 5 px (more with taller keyboards, EN too). Fix: with a keyboard inset the build banner takes at most 40% of the body and scrolls (app_shell.dart). Test: q002_keyboard_shell_test.dart (insets 320 and 420, EN and TR). Not covered by this browser matrix: Chromium here has no on-screen keyboard.

Tool fixes: `boundingBox` calls got timeouts (an element dropped from Flutter's lazy semantics made one wait forever); the Labs add button is scrolled into view first (below the fold at 2× text); the lock reason is read while its section is on screen; the status line is looked for upward from the entry.
