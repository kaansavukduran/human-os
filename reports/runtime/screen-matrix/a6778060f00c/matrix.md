# Screen matrix (Chromium) at a6778060f00c

Tool: `tools/flutter_screen_matrix.mjs` · 2026-11-26T06:24:13.953Z · chromium 153.0.8010.12 · working tree dirty: false
Release build main.dart.js sha256 `8c7a063ca13d1929c2d8b0ff0157b1c8aec727864e02f30746bc706f8d32aada` · debug build sha256 `9d4b5874764de758458b933384317af2bfaf09e8357a51b91354b657b4fedad4`

**36 cells: 33 PASS, 3 FAIL.**

Touch sizes run as Android Chrome (touch, mobile user agent); desktop runs as desktop Chromium. 2× text sets the browser font size to 32px (Flutter web reads it as its text scale). Checks are listed in matrix.json → checks.

## u046

| Screen | small-phone 320x640 · en-US | desktop 1440x900 · en-US | small-phone 320x640 · tr-TR | desktop 1440x900 · tr-TR |
|---|---|---|---|---|
| Derived: technical details | PASS | PASS | PASS | PASS |
| Learn: body guide parts | PASS | PASS | PASS | PASS |
| Genetics | PASS | PASS | PASS | PASS |
| Plant chemicals | PASS | PASS | FAIL | FAIL |
| About: version | PASS | PASS | PASS | PASS |
| Settings: theme under palette | PASS | PASS | PASS | PASS |

## u046-text-2x

| Screen | small-phone 320x640 · en-US | small-phone 320x640 · tr-TR |
|---|---|---|
| Derived: technical details | PASS | PASS |
| Learn: body guide parts | PASS | PASS |
| Genetics | PASS | PASS |
| Plant chemicals | PASS | FAIL |
| About: version | PASS | PASS |
| Settings: theme under palette | PASS | PASS |

## FAIL list

- **Plant chemicals** · u046 · small-phone 320x640 · tr-TR (u046_small-phone_tr-TR_Plant-chemicals.png)
  - no_english_on_tr: "GeriBitki kimyasallarıphytochem.nal.usda.gov sitesinde bir madde, etki" (results); "phytochem.nal.usda.gov sitesinde bir madde, etki ya da bitki aç, sonra" (results)
- **Plant chemicals** · u046 · desktop 1440x900 · tr-TR (u046_desktop_tr-TR_Plant-chemicals.png)
  - no_english_on_tr: "GeriBitki kimyasallarıphytochem.nal.usda.gov sitesinde bir madde, etki" (results); "phytochem.nal.usda.gov sitesinde bir madde, etki ya da bitki aç, sonra" (results)
- **Plant chemicals** · u046-text-2x · small-phone 320x640 · tr-TR (u046-text-2x_small-phone_tr-TR_Plant-chemicals.png)
  - no_english_on_tr: "GeriBitki kimyasallarıphytochem.nal.usda.gov sitesinde bir madde, etki" (results); "phytochem.nal.usda.gov sitesinde bir madde, etki ya da bitki aç, sonra" (results)

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
