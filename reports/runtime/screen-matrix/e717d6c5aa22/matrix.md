# Screen matrix (Chromium) at e717d6c5aa22

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-24T01:35:30.673Z · chromium 141.0.7390.37 · working tree dirty: false
Release build main.dart.js sha256 `8680f5e73841fc7b05a513b4ce54c353f2a6481275cc50e0d8edbd0693b7bb79` · debug build sha256 `842cd9866f10d6f9dc9b159d6dfe2aba896cca17434b6fcb35f657e0395fa933`

**186 cells: 186 PASS, 0 FAIL.**

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
| Labs: more from the report | PASS | PASS | PASS | PASS |
| Labs: same test over time | PASS | PASS | PASS | PASS |
| Settings: palettes | PASS | PASS | PASS | PASS |
| Settings: app lock | PASS | PASS | PASS | PASS |
| Settings: about | PASS | PASS | PASS | PASS |
| Today: restore from file | PASS | PASS | PASS | PASS |

## sheets-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Labs: add sheet | PASS | PASS |
| Labs: more from the report | PASS | PASS |
| Labs: same test over time | PASS | PASS |
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
## Q003 notes (added by hand after the run)

Matrix grew from 162 (Q002) to 186 cells: `Learn` (U034) is now covered at all 5 sizes, EN/TR and 2× text (12 cells), and `sheets` / `sheets-text-2x` add `Labs: same test over time` (F004-S4) and `Settings: about` (U032) at 320x640 (1× and 2× text) and desktop in EN/TR (12 cells), plus two checks (`about_sections_clear`, `lab_group_chart_spoken`).

App defects found during Q003 probing and widget regression sweeps, fixed in `e717d6c` with unit and widget regression tests:

- **Same-day chart date label collision (`TrendPainter`).** When all plotted points fell on the same calendar day (e.g. two lab results sharing a sample date or multiple same-day vital readings), the x-axis painted two touching copies of the date (`2025-01-102025-01-10`). Fix: extracted pure `axisDateLabels(xs, days)` in `domain/trends/trend.dart` (one centred label for one day, left/right for distinct days) and added narrow-width overlap protection in `trend_screen.dart`. Test: `test/domain/t002_chart_rules_test.dart`.
- **Clipped AppBar titles at 320 dp, 2× text (EN and TR).** `AboutScreen` ("Human OS hakk..."), `GlossaryScreen`, `GlossaryEntryScreen`, `BodyGuideScreen`, `BodySystemScreen`, `HowToScreen`, `LabGroupScreen` and `TrendScreen` ellipsized their AppBar titles at 320 dp with 2× text. Fix: `FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart)` matching `SettingsScreen` (U035). Test: `test/widget/q003_screen_regression_test.dart`.
- **Clipped field labels and helper texts at 320 dp, 2× text.** The Labs add sheet ellipsized long labels ("Raporda yazan ...") and chopped multi-line helper texts at `helperMaxLines: 3`; `GlossaryScreen` ellipsized its search field label and truncated definitions at `maxLines: 2`. Fix: `WholeLabelField` and `helperMaxLines: 20` in `labs_screen.dart`; `WholeLabelField` and unwrapped definitions in `glossary_screen.dart`. Test: `test/widget/q003_screen_regression_test.dart`.
- **Unreachable confirmation checkbox in `AlertDialog` at 320x640, 2× text (F005-S3 import preview).** With a tall wrapped title and actions at 2× text, `AlertDialog` without `scrollable: true` pushed `import-understand` to `y = 776` (EN) / `792` (TR), outside the 640 dp viewport. Fix: `AlertDialog(scrollable: true)` across all five data dialogs in `your_data_card.dart`. Test: `test/widget/q003_screen_regression_test.dart` (asserts checkbox and confirm button remain inside `Size(320, 640)` and complete the import).
- **Standalone header semantics containers.** Added `container: true` to `Semantics(header: true)` in `about_screen.dart`, `labs_screen.dart`, `lab_group_screen.dart`, `body_guide_screen.dart`, `how_to_screen.dart` and `glossary_screen.dart` so Flutter Web exposes standalone heading nodes. Test: `test/widget/q003_screen_regression_test.dart` and matrix checks `about_sections_clear` / `lab_group_chart_spoken`.

Tool fixes in `tools/flutter_screen_matrix.mjs`: read-only screens (`AboutScreen`, `LabGroupScreen`) hash all visible semantics nodes for scroll termination; `popAll()` loops until no Back button remains and clears hover tooltips; Labs scrolls to top before waiting for its heading; heading and spoken-label sweeps read Flutter Web's native `h1`-`h6` and `flt-semantics` text nodes; optional `--cache` checkpoints completed groups keyed by git HEAD, build SHA-256 and browser version.
