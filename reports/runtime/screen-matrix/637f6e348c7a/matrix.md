# Screen matrix (Chromium) at 637f6e348c7a

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-25T18:10:09.626Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `b26fcd625d41e2f680023424d013da45a3da45f8929125aee66c58a5d7912f29` · debug build sha256 `d097c55c3cf9482d46b68ddf1325496a0ae2381b4644288429b26dd7148272b1`

**278 cells: 275 PASS, 3 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## base

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · en-US | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Today | PASS | PASS | PASS | PASS |
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
| Labs: more from the report | PASS | FAIL |
| Labs: same test over time | PASS | PASS |
| Medications: I took it | PASS | PASS |
| Timeline: record details | PASS | PASS |
| Settings: palettes | PASS | PASS |
| Settings: app lock | PASS | PASS |
| Settings: about | PASS | PASS |
| Today: restore from file | PASS | PASS |

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
| Today: weight empty | PASS | PASS | PASS | PASS |
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
| Today: weight empty | PASS | PASS |
| Summary: empty | PASS | PASS |
| Derived | PASS | PASS |
| Timeline: show deleted | PASS | PASS |
| Learn: how-to | PASS | PASS |

## u043

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Today: sleep sheet | PASS | PASS | PASS | PASS |
| Today: feeling sheet | PASS | PASS | PASS | PASS |
| Nutrition: add sheet | PASS | PASS | PASS | PASS |
| Conditions: add sheet | PASS | PASS | PASS | PASS |
| Preventive: add sheet | PASS | PASS | PASS | PASS |
| Documents: add sheet | PASS | PASS | PASS | PASS |
| Medications: add sheet | PASS | FAIL | PASS | FAIL |
| Trend: weight | PASS | PASS | PASS | PASS |
| Learn: body guide | PASS | PASS | PASS | PASS |
| Today: glucose sheet | PASS | PASS | PASS | PASS |

## u043-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today: sleep sheet | PASS | PASS |
| Today: feeling sheet | PASS | PASS |
| Nutrition: add sheet | PASS | PASS |
| Conditions: add sheet | PASS | PASS |
| Preventive: add sheet | PASS | PASS |
| Documents: add sheet | PASS | PASS |
| Medications: add sheet | PASS | PASS |
| Trend: weight | PASS | PASS |
| Learn: body guide | PASS | PASS |
| Today: glucose sheet | PASS | PASS |

## u043-light-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today: sleep sheet | PASS | PASS |
| Today: feeling sheet | PASS | PASS |
| Nutrition: add sheet | PASS | PASS |
| Conditions: add sheet | PASS | PASS |
| Preventive: add sheet | PASS | PASS |
| Documents: add sheet | PASS | PASS |
| Medications: add sheet | PASS | PASS |
| Trend: weight | PASS | PASS |
| Learn: body guide | PASS | PASS |
| Today: glucose sheet | PASS | PASS |

## FAIL list

- **Labs: more from the report** · sheets-text-2x · small-phone 320x640 · tr-TR (sheets-text-2x_small-phone_tr-TR_Labs-more-from-the-report.png)
  - text_scaled_2x: heading height 20 → 20 (×1.00)
- **Medications: add sheet** · u043 · desktop 1440x900 · en-US (u043_desktop_en-US_Medications-add-sheet.png)
  - no_stacked_headings: "Add a medicine or supplement" / "From the pack"
- **Medications: add sheet** · u043 · desktop 1440x900 · tr-TR (u043_desktop_tr-TR_Medications-add-sheet.png)
  - no_stacked_headings: "İlaç ya da takviye ekle" / "Kutudan"

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
