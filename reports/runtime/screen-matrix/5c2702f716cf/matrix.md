# Screen matrix (Chromium) at 5c2702f716cf

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-26T03:57:31.162Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `fd9bb6438bcdbc5a6c21d5faf1d91803dad98b5c54eacb1d3fdacef81e1cf3f4` · debug build sha256 `84289638dd4fd65a8e55ff78e2059edef71a3df6dde252d0ca91e9a0a80098af`

**8 cells: 8 PASS, 0 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## base

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · en-US | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Medications | PASS | PASS | PASS | PASS |

## u043

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Trend: weight | PASS | PASS | PASS | PASS |

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
