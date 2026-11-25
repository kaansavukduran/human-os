# Screen matrix (Chromium) at 8601ce9ca554

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-25T04:31:05.419Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `3abe5469b01065837240a9d3b14e7fd3339b8a053818ecaac64c57bd059f567e` · debug build sha256 `afafe81e672c877aff3a25c3677e8740c43a212f460e79be7c82ec92d261596a`

**204 cells: 204 PASS, 0 FAIL.**

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
| Learn | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
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
| Learn | PASS | PASS |
| Settings | PASS | PASS |

## sheets

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Labs: add sheet | PASS | PASS | PASS | PASS |
| Labs: field details | PASS | PASS | PASS | PASS |
| Labs: more from the report | PASS | PASS | PASS | PASS |
| Labs: same test over time | PASS | PASS | PASS | PASS |
| Medications: I took it | PASS | PASS | PASS | PASS |
| Timeline: record details | PASS | PASS | PASS | PASS |
| Settings: palettes | PASS | PASS | PASS | PASS |
| Settings: app lock | PASS | PASS | PASS | PASS |
| Settings: about | PASS | PASS | PASS | PASS |
| Today: restore from file | PASS | PASS | PASS | PASS |

## sheets-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Labs: add sheet | PASS | PASS |
| Labs: field details | PASS | PASS |
| Labs: more from the report | PASS | PASS |
| Labs: same test over time | PASS | PASS |
| Medications: I took it | PASS | PASS |
| Timeline: record details | PASS | PASS |
| Settings: palettes | PASS | PASS |
| Settings: app lock | PASS | PASS |
| Settings: about | PASS | PASS |
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
## Q004 notes (added by hand after the run)

- Report revision: 8601ce9ca554 (tool changes committed, clean tree); the report folder was added to that commit afterwards by amend. Builds: `flutter build web --release` and `--debug`, both `--no-web-resources-cdn --dart-define=APP_ENV=development`, SOURCE_REVISION 8601ce9.
- New cells (Q004, U036–U038): "Labs: field details" (the add sheet with "What to type here" of the test name open), "Medications: I took it" (a medicine added, then the dose sheet that "I took it" opens), "Timeline: record details" (a lab result's sheet with Details open), at 320x640 1× and 2× text and desktop, EN/TR: 18 cells, 186 → 204.
- First full run of the updated tool (revision 490c1d8, same app code): 204 cells, 198 PASS, 6 FAIL, all `palette_applied` on desktop (Matrix, Axolotl, Trans; Settings and Today). Cause: tool. An empty full-window semantics node intercepts Playwright's click on the palette swatch; the retry scrolled the semantics tree through the DOM, which moved the page and shifted the palette row, so the forced click landed on Standard. Fix: a control already on screen is clicked at its centre (Flutter hit-tests by position).
- Tool fixes found on partial runs before that: Settings (and About, a lab group) scroll only inside the centred 840 dp reading column since U036, so the tool now wheels inside the column, not in the left gutter (app lock on desktop was not reached); the Timeline row is one button named with its test and value; the modal barrier above a short sheet ("Scrim", 320x43 to 320x212) is not a control and is not counted as a touch target (Cancel, the drag handle and back close the sheet).
- Observation, not a FAIL: on a wide window the mouse wheel does nothing over the side gutters outside the reading column (seen on desktop Settings; the shell and other pushed pages use the same ReadingWidth wrapper, not checked one by one).
- Screenshots kept: 179 of 204 (repository size); not kept: base tablet-landscape (22) and the phone Today cells of the three palette groups (3). matrix.json still names them.
