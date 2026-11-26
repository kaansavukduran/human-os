# Screen matrix (Chromium) at 5aef4ec13fa4

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-26T00:19:38.053Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `855e04f74c94a54f9b8b1466552da9f0bd23c5e61a3a81802627a86b913ef444` · debug build sha256 `dedd90f9b806ef38b8ea9bf545e8a67b6d567108dba6112ab237cd6858da2910`

**156 cells: 156 PASS, 0 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## base

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today | PASS | PASS |
| Timeline | PASS | PASS |
| Labs | PASS | PASS |
| Nutrition | PASS | PASS |
| Learn | PASS | PASS |
| Settings | PASS | PASS |

## text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Today | PASS | PASS |
| Timeline | PASS | PASS |
| Labs | PASS | PASS |
| Nutrition | PASS | PASS |
| Learn | PASS | PASS |
| Settings | PASS | PASS |

## u043

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Today: sleep sheet | PASS | PASS | PASS | PASS |
| Today: feeling sheet | PASS | PASS | PASS | PASS |
| Nutrition: add sheet | PASS | PASS | PASS | PASS |
| Conditions: add sheet | PASS | PASS | PASS | PASS |
| Preventive: add sheet | PASS | PASS | PASS | PASS |
| Documents: add sheet | PASS | PASS | PASS | PASS |
| Medications: add sheet | PASS | PASS | PASS | PASS |
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

## q008

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Activity: add sheet | PASS | PASS | PASS | PASS |
| Timeline: correction | PASS | PASS | PASS | PASS |

## q008-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Activity: add sheet | PASS | PASS |
| Timeline: correction | PASS | PASS |

## q008-rail

| Screen | compact-840 840x900 · en-US | compact-1000 1000x900 · en-US | compact-840 840x900 · tr-TR | compact-1000 1000x900 · tr-TR |
|---|---|---|---|---|
| Today | PASS | PASS | PASS | PASS |
| Timeline | PASS | PASS | PASS | PASS |
| Labs | PASS | PASS | PASS | PASS |
| Nutrition | PASS | PASS | PASS | PASS |
| Learn | PASS | PASS | PASS | PASS |

## q008-rail-text-2x

| Screen | compact-840 840x900 · en-US | compact-1000 1000x900 · en-US | compact-840 840x900 · tr-TR | compact-1000 1000x900 · tr-TR |
|---|---|---|---|---|
| Today | PASS | PASS | PASS | PASS |
| Timeline | PASS | PASS | PASS | PASS |
| Labs | PASS | PASS | PASS | PASS |
| Nutrition | PASS | PASS | PASS | PASS |
| Learn | PASS | PASS | PASS | PASS |

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
