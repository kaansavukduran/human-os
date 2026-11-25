# Screen matrix (Chromium) at 46bccd63f1df

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-25T14:53:03.152Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `7a5addafd10b85bd9705abde8b2b7866f6472abe83fe4c07a3d61c8a2b27fef9` · debug build sha256 `c1dee6eb982ed6223d8a0a4a9a94fd8e83b86b53c98da372e102dd4eb214e3ef`

**198 cells: 198 PASS, 0 FAIL.**

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
| Labs: more from the report | PASS | PASS |
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
