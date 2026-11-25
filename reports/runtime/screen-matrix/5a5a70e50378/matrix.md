# Screen matrix (Chromium) at 5a5a70e50378

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-25T11:15:47.861Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `6ec023a7e109c187f55692cb7d7b6b3e614b5be68bea6acdf1c6e36fb34a00b9` · debug build sha256 `99ae50b7b87a3bca8e3228e9ca4c96dc40efd4e9a38f99051259912ff750356c`

**198 cells: 180 PASS, 18 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## base

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · en-US | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Today | FAIL | FAIL | FAIL | FAIL |
| Timeline | PASS | PASS | PASS | PASS |
| Labs | PASS | PASS | PASS | PASS |
| Medications | PASS | PASS | PASS | PASS |
| Nutrition | PASS | PASS | PASS | PASS |
| Activity | PASS | PASS | PASS | PASS |
| Conditions | PASS | PASS | PASS | PASS |
| Preventive | PASS | PASS | PASS | PASS |
| Documents | PASS | PASS | PASS | PASS |
| Learn | PASS | PASS | PASS | PASS |
| Settings | PASS | PASS | PASS | PASS |

## text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today | FAIL | FAIL |
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
| Today: restore from file | FAIL | FAIL | FAIL | FAIL |

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
| Today: restore from file | FAIL | FAIL |

## u041

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| First run: welcome | PASS | PASS | PASS | PASS |
| First run: look | PASS | PASS | PASS | PASS |
| Nutrition: empty | PASS | PASS | PASS | PASS |
| Activity: empty | PASS | PASS | PASS | PASS |
| Conditions: empty | PASS | PASS | PASS | PASS |
| Preventive: empty | PASS | PASS | PASS | PASS |
| Documents: empty | PASS | PASS | PASS | PASS |
| Today: weight empty | FAIL | FAIL | FAIL | FAIL |
| Summary: empty | PASS | PASS | PASS | PASS |
| Derived | PASS | PASS | PASS | PASS |
| Timeline: show deleted | PASS | PASS | PASS | PASS |
| Learn: how-to | PASS | PASS | PASS | PASS |

## u041-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| First run: welcome | PASS | PASS |
| First run: look | PASS | PASS |
| Nutrition: empty | PASS | PASS |
| Activity: empty | PASS | PASS |
| Conditions: empty | PASS | PASS |
| Preventive: empty | PASS | PASS |
| Documents: empty | PASS | PASS |
| Today: weight empty | FAIL | FAIL |
| Summary: empty | PASS | PASS |
| Derived | PASS | PASS |
| Timeline: show deleted | PASS | PASS |
| Learn: how-to | PASS | PASS |

## FAIL list

- **Today** · base · small-phone 320x640 · en-US (base_small-phone_en-US_Today.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today** · base · small-phone 320x640 · tr-TR (base_small-phone_tr-TR_Today.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today** · base · desktop 1440x900 · en-US (base_desktop_en-US_Today.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today** · base · desktop 1440x900 · tr-TR (base_desktop_tr-TR_Today.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today** · text-2x · small-phone 320x640 · en-US (text-2x_small-phone_en-US_Today.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today** · text-2x · small-phone 320x640 · tr-TR (text-2x_small-phone_tr-TR_Today.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: restore from file** · sheets · small-phone 320x640 · en-US (sheets_small-phone_en-US_Today-restore-from-file.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: restore from file** · sheets · desktop 1440x900 · en-US (sheets_desktop_en-US_Today-restore-from-file.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: restore from file** · sheets-text-2x · small-phone 320x640 · en-US (sheets-text-2x_small-phone_en-US_Today-restore-from-file.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: restore from file** · sheets · small-phone 320x640 · tr-TR (sheets_small-phone_tr-TR_Today-restore-from-file.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: restore from file** · sheets · desktop 1440x900 · tr-TR (sheets_desktop_tr-TR_Today-restore-from-file.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: restore from file** · sheets-text-2x · small-phone 320x640 · tr-TR (sheets-text-2x_small-phone_tr-TR_Today-restore-from-file.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: weight empty** · u041 · small-phone 320x640 · en-US (u041_small-phone_en-US_Today-weight-empty.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: weight empty** · u041 · desktop 1440x900 · en-US (u041_desktop_en-US_Today-weight-empty.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: weight empty** · u041-text-2x · small-phone 320x640 · en-US (u041-text-2x_small-phone_en-US_Today-weight-empty.png)
  - no_stacked_headings: "Tools" / "For a visit and your numbers"
- **Today: weight empty** · u041 · small-phone 320x640 · tr-TR (u041_small-phone_tr-TR_Today-weight-empty.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: weight empty** · u041 · desktop 1440x900 · tr-TR (u041_desktop_tr-TR_Today-weight-empty.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"
- **Today: weight empty** · u041-text-2x · small-phone 320x640 · tr-TR (u041-text-2x_small-phone_tr-TR_Today-weight-empty.png)
  - no_stacked_headings: "Araçlar" / "Muayene ve sayıların için"

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
