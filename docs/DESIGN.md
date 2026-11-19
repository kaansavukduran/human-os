# Design method: calm clinical, no slop

Human OS shows a person's own health data. The interface has one job: let a person put a number in and find it again, without noise. This file is the method every screen is built and reviewed with. It was written from scratch for this project; it borrows the idea of an "anti-slop" checklist (name the generic patterns, then avoid them on purpose), not any code or text.

## What "slop" means here
Interfaces that look generated: the same card repeated with an icon, a title and a line of text; a screen that explains itself more than it helps; decoration that carries no meaning (gradients, emoji, chips on everything); technical facts about the app in front of facts about the person; every control visible at once.

## Principles
1. **One job per screen or sheet.** Today shows the person's numbers. Adding a number is its own sheet. Backups and build facts are further down and quiet.
2. **Data first, machinery last.** Values, then actions, then settings, then "about this build". Words such as schema, provenance, or record kind never lead a screen.
3. **One accent, calm neutrals.** A muted teal for actions and focus; near-white surfaces; hairline borders instead of shadows. Colour never judges a value: a number is never green, amber or red. Red is for errors in the entry only.
4. **Four type sizes.** Page title, section title, value (large, tabular figures), body/caption. Numbers are the largest thing on a tile.
5. **An 8 dp rhythm, one container level.** No card inside a card. Sections are separated by space and a title, tiles by hairlines.
6. **Progressive disclosure.** The common path is the value and Save. "When" and the note sit under "More details", closed by default.
7. **Plain words, short sentences.** The same words in every place for the same thing. No fluff ("Welcome", "Let's get started"), no repeated disclaimers: the no-judgement promise is said once per area, not once per control.
8. **Forgiving defaults.** Empty means "now"; every entry can be corrected or withdrawn; an error says what to change in the entry, never what is wrong with the person.
9. **Accessible by construction.** 48 dp targets, text up to 2x without clipping, 320 dp wide, a spoken summary for every value, errors announced, meaning never by colour alone.
10. **Honest states.** Missing is shown as missing ("Not recorded yet"), never 0 and never a blank that looks like a value.

## Slop audit (run on every screen change)
Score each item pass or fail; any fail is fixed or recorded with a reason.
- [ ] Is the first thing on screen about the person, not the app?
- [ ] At most one container level; no repeated icon-title-text card grid?
- [ ] At most one accent colour; no colour that judges a value?
- [ ] No emoji or decoration without meaning; no gradient?
- [ ] Is every visible sentence needed, and said once?
- [ ] Is the common path one tap, one field, one button?
- [ ] Are advanced fields closed by default?
- [ ] Do numbers use tabular figures and the largest size on the tile?
- [ ] 320 dp at 2x text, TR and EN, no clipping or overflow?
- [ ] Empty, error and saved states all written?
- [ ] Spoken label for each value and each error?
- [ ] Before/after screenshots at phone and desktop width kept as evidence?

## Turkish text (L001)
Every visible string has a Turkish version (`lib/src/l10n/strings.dart`, the guide data and `destinations.dart`); `test/unit/l001_turkish_test.dart` fails on an empty Turkish value, Turkish equal to English outside a short allow-list, common English words, raw codes and placeholders that differ between the two languages.

- **Address: "sen"**, friendly and direct, everywhere ("yaz", "seç", "kayıtların"). No "siz" forms, no "lütfen".
- **One word per concept:** record or entry → **kayıt** (what the person typed during a session that is not saved: **yazdıkların**); measurement or reading → **ölçüm**; lab result → **tahlil sonucu**, the Labs area → **Tahliller** (the laboratory as an institution stays **laboratuvar**); clinician → **hekim**; build → **sürüm**; staging/production → **test/yayın**; invented sample data → **kurgusal**; pulse oximeter → **nabız oksimetresi**; word → **sözcük**.
- **Suffixes after inserted values:** choose wording that needs no suffix on a placeholder ("Yukarı taşı: $what", "$name dosyasından", "${n}. kayıt"). Write suffixes after numbers and abbreviations with an apostrophe by pronunciation ("100'ü", "50 MB'tan", "112'yi", "HbA1c'nin"). The product name takes no suffix ("uygulamayı yeniden başlat", not "Human OS'u"), because its reading (English or letter by letter) decides the vowel.
- **No plural after a number:** "$n kayıt", never "$n kayıtlar".
- **Casing:** shown text is upper- or lower-cased only through `upperIn`/`lowerIn` (`lib/src/l10n/casing.dart`), which keep i/İ and ı/I; Dart's own `toUpperCase` is language-neutral.
- **Numbers and dates:** values the app formats show a decimal comma in Turkish (`decimalIn`: "72,4 kg", "≈ 154,3 lb"); text kept as printed (lab results, the typed "girilen değer") is shown unchanged. The Today date line is day-month ("19 Kasım Perşembe"); timestamps follow the date setting (ISO by default, day.month.year available) and the 24-hour clock or ÖÖ/ÖS.
- Names of external sites' buttons ("Download these results as: CSV", "Send to > File") stay in English inside quotes because the person sees them in English there.

## Tokens (see `lib/src/presentation/theme/human_os_theme.dart`)
Accent teal `#1F6F78` (dark mode `#7FC4CB`); surface `#F6F8F8` / card `#FFFFFF` / hairline `#DDE4E4`; text `#1B2B2E`. Radius 12 dp. Spacing 4 / 8 / 12 / 16 / 24 / 32. The development-build strip is a quiet neutral band with a small label, not a coloured alert.

## Brainstorm and backlog
Ideas that fit the invariants (planned is not completed; missing is not zero; no diagnosis) are collected in `docs/BRAINSTORM.md`.
