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

## U036 audit

What a first-time person sees above the fold, counted from the real web build (empty profile, dark, development build; before = `reports/runtime/screen-matrix/e717d6c5aa22/` at e717d6c, after = `reports/runtime/u036/`). Headings count the screen title and section titles; the app bar, the build strip and the navigation are not counted. "Helper lines" are rendered lines of explanatory text.

| Screen, size | Before | After |
|---|---|---|
| Today 390x844 | 3 headings, weight card + 2 of 9 tiles, 6 actions (Save, See over time and Show number pad on two lines, 2 tiles, settings), 1 chip, 6 helper lines; 9 tiles in the section | 3 headings, weight card + 2 of 4 tiles, 6 actions (the two links share one row), 1 chip, 5 helper lines; 4 tiles in the section, 5 under "More measurements (5)" |
| Today 1440x900 | 3 headings, 10 containers (weight + 9 tiles), 12 actions, 1 chip, 3 helper lines; content 928 dp wide | 4 headings (Sleep now reaches the fold), 6 containers (weight + 4 tiles + Sleep), 8 actions (Save, 2 links, 4 tiles, More), 1 chip, 4 helper lines; one centred 840 dp column |
| Labs 390x844 | 1 title + 3 intro labels, 3 intro paragraphs (11 lines), 5 actions (Close, 3 terms, Add), 2-line note in small text | same content (nothing removed), intro and note in the secondary colour, 12/24 dp steps between them |
| Labs 1440x900 | as phone, lines up to 928 dp long | as phone, lines at most 808 dp long, centred |
| Timeline 390x844 / 1440x900 | 1 title + 3 intro labels, 3 paragraphs, 3 actions (Close, term, Go to Today), 1 switch | same, quieter intro; 12 dp before the switch |
| Medications 390x844 / 1440x900 | 1 title + 3 intro labels, 3 paragraphs (7 lines phone), 2 actions | same, quieter intro |
| Settings 390x844 | 1 title, 3 sections, 2 notes in small text, 1 slider, 6 scale chips, 1 field, 2 buttons, 6 choice chips | same controls, notes and scale help in the secondary colour at base size; sections 32 dp apart |
| Settings 1440x900 | text and the field run edge to edge (1408 dp) | one centred 840 dp column |

What competed most: on Today, nine equal tiles (each with "Not recorded yet" and a "+") above sleep, feeling and tools; on the areas, the open introduction in full body colour; on a wide window, lines of 120+ characters.

What U036 changed: one spacing scale (`lib/src/presentation/theme/spacing.dart`: 4/8/12/16/24/32, sections 32, cards 20, items 12); one centred reading column of at most 840 dp for every main screen, Settings and About; Today lists the kinds with a record plus the first kinds up to four, the rest behind "More measurements" / "Diğer ölçümler" (remembered as `moreMeasurementsOpen`, an additive appearance setting; a kind with a record is never behind it); the section note is one short line; secondary text (intro paragraphs, section notes, the Sleep intro, the Settings notes) uses onSurfaceVariant at the base size; list and history values use tabular figures; the expander has no animation (nothing moves under reduced motion), a 48 dp target and an expanded state for screen readers; Settings is built whole so Tab reaches every control. Area introductions stay open at first (U031) and say the same words.

## U037 audit

The screens people use to enter things, counted from the real web build (empty profile, dark, development build) at 390x844 (phone, touch) and 1440x900, in English and Turkish. Before = 1cab8d7, after = `reports/runtime/u037/`. "Fields" are the text fields in the sheet's first view (Save and Cancel stay pinned below them). "Helper lines" are the rendered lines of explanation under those fields. "Other buttons" are actions besides Save and Cancel. Counts are the same in EN and TR unless a row says otherwise.

| Screen | Before | After |
|---|---|---|
| Labs add sheet, phone | 7 fields, 7 helper lines (three helpers ran to 2 lines), 0 other buttons, one long column | 4 fields under "The result" / "Sonuç", 3 one-line helpers, 3 small "What to type here" / "Ne yazılır?" toggles. Specimen, Laboratory, Flag and Range sit under "Also on the report (optional)", and Unit says "(optional)" |
| Labs add sheet, 1440x900 | 8 fields, 5 helpers (two of them had two sentences) | 4 fields and the start of the optional group, 4 one-sentence helpers, 3 toggles |
| "More from the report", phone | a 3-line interval paragraph, a 2-line report-time helper, 1 link | one short line ("not a target, not a decision limit"), the glossary link, and the whole paragraph behind "What to type here". Every helper is one line |
| Blood pressure sheet | 2 fields and 4 other buttons. Two of them ("See over time", "About this measurement") sat between the title and the first field, and "I did not measure this" came above the numbers | the 2 fields come first under the title. "See over time" and "About" are two icons with tooltips beside the title, and "I did not measure this" comes after the numbers. The field labels move above the field when they do not fit (they were cut at 320 dp, 2× text) |
| Weight entry (Today) | 1 field, Save, and 2 quiet links on one row (U036) | unchanged: already one field and one primary action |
| Medications card | name, plan line, counts, up to 5 dose lines, then 2–4 buttons of similar weight in one row (Write the plan, Record a dose, Pause, Stop) | name and pack facts first. Then "Today: … taken, … skipped" with "I took it" / "I skipped it" (each only opens the dose sheet). Counts and the last 3 doses follow in the secondary colour. Under a divider comes the plan as written, quiet, with its own small text actions |
| Medications add sheet | 4 fields whose labels carried examples in prose ("Strength as printed (optional, e.g. 500 mg)"); the error showed at the bottom of the sheet | two groups, "From the pack" (Name, Kind) and "Details (optional)". Labels are short ("Strength (optional)") and the example is a one-line helper. The error shows under its field, which takes focus |
| Plan and dose sheets | the dose time format sat inside the label ("When (optional, YYYY-MM-DD HH:MM; empty = now)"), and Taken/Skipped had no label | "When (optional)" with a one-line helper and the date keyboard. "This dose was" sits over Taken/Skipped, preset from the card |
| Conditions sheet | 2 fields and 3 choice groups titled "It is a", "It is" and "It comes from" | the same fields, with the groups asked as plain questions: "Condition or symptom?", "Is it still there?", "Where it comes from". "Since when (optional)" has a one-line example |
| First run | 3 steps before Today, with 2–3 buttons each | 2 steps with 2 buttons each: what Human OS does and that it stays on this device, then language and look. The last step says where to type the first value. The vault creation that follows in encrypted builds is unchanged |

Where a first-time person hesitated:
- "Unit as printed" looked required.
- Two-line helpers read like rules to learn.
- The interval paragraph sat between the person and the fields.
- "It is a" and "It is" were half-sentences.
- "Write the plan" (outlined) and "Record a dose" (tonal) looked equally primary, with Pause and Stop right beside them.
- Two links sat between a measurement's title and its first field.
- The introduction had three steps before anyone could save a first value.

What U037 changed:
- Three shared pieces in `sheet_parts.dart`:
  - `SheetSection`: a small label that groups fields.
  - `FieldDetails`: "What to type here" / "Ne yazılır?" opens the long explanation in place. It is a 48 dp target with an expanded state for screen readers.
  - `FieldError`: the error in plain words under its field, read out when it appears.
- Every changed sheet keeps one filled Save and a text Cancel.
- Helpers are one line: at most 56 characters, with no second sentence.
- Optional fields say "(optional)" / "(isteğe bağlı)" in their label.
- Dates use the date keyboard.
- FieldFocus still moves focus to the field an error is about. Labs now shows the error under that field, and Medications now has this too.
- Medications never counts the plan as a dose, and a dose button records nothing until Save (planned ≠ taken, reminder ≠ completion).
- Keys used by tests and tools are kept. The new ones are `meds-skip-<id>`, `meds-today-<id>`, `<field>-details` and `lab-interval-short`.

## U038 audit

The reading screens, counted from the real web build (development build, dark) at 390x844 and 1440x900, in English and Turkish, with records typed through the UI: a weight corrected once (two versions), a blood pressure, and two HbA1c results from one report format (one with the lab's flag H). Before = c325ec5, after = `reports/runtime/u038/`. Counts are the same in EN and TR unless a row says otherwise. Area introductions stay open at first (U031) and are not counted.

| Screen | Before | After |
|---|---|---|
| Timeline list | one card per record; under the value a line of machinery on every row: "2026-11-24 23:09 · Observed · Manual entry" (state and source), plus "saved …" for back-dated measurements and the lab's report lines; no day grouping | records grouped under day headers in plain words ("Today" / "Bugün", "Yesterday" / "Dün", then the date); each row is the name and the value as typed on one line, then the time alone (a lab says "Sample date: …"); chips only for versions and status; hairlines instead of cards |
| Timeline record sheet | each version a two-line subtitle mixing role, "entered …", the source, the text as typed and the report's lines | each version is its value, then one quiet line (role, when, the text as typed, the note); "entered …", state · source and the report's lines open under one "Details" / "Ayrıntılar" for the whole sheet |
| Labs list, phone | "Same test over time" with a four-line rule paragraph and a link line; each result: name, value, "Sample date · specimen · laboratory · Manual entry", flag chip, printed range, the report's lines, then Correct alone on its own line | the group is one plain row with a chevron and the rule under Details; each result: name and value, the sample date (and specimen), the lab's flag and printed range in view; the laboratory, the source and the report's lines under Details, which shares its line with Correct |
| Same test over time | three header lines and the four-line rule before the chart; each result a card with the date above the value | the name as typed, then unit and specimen in the secondary colour, the rule under Details; each result uses the Labs row: date and value on one line, flag and range, the laboratory under Details. Centred 840 dp column on a wide window (it ran 1408 dp wide) |
| Learn | intro and three plain rows (already one line each); the glossary, body guide and how-to ran edge to edge on a wide window; the body guide was a grid of 12 bordered cards | the same three rows; the three pages sit in the 840 dp column with the page padding of the main screens; the body guide is 12 plain rows (name, parts) like Learn's |
| Settings, phone | Interface scale first (a five-line explanation, slider, six chips, a field and two buttons), so "Light or dark" started at the fold; four font samples always open | Light or dark, Palette, Colour, Text size and Language first (Light or dark at the top, Text size inside the fold), then Interface scale and Font; units, dates, spacing, contrast, start screen, Today and discovery after; app lock, updates and About last. The font samples open under "See each font" / "Her yazı tipini gör" |

What competed most: on every Timeline and Labs row, the record's state and source ("Observed · Manual entry") were as loud as its time; the grouping rule was a paragraph in front of the results; on Settings, the rarely changed interface scale stood before light or dark.

What U038 changed:
- `lib/src/presentation/widgets/record_row.dart`: one row pattern (`RecordRow`: what and the value as typed, one quieter line, chips, lines, a footer), `DetailsToggle` / `DetailsDisclosure` ("Details" / "Ayrıntılar"; a 48 dp target reached by Tab, a button with an expanded state named with what it belongs to, closed by default; keys `details-<id>` and `details-<id>-text`), `DetailLine` and `DayHeader` (a heading for screen readers).
- The Timeline groups by day: a timed record on its local day, a lab sample date on its own calendar day (never shifted by the time zone); tests run in UTC and America/New_York.
- No information is removed: every line that left a row is in that record's Details or sheet; the sheet's Details adds the record state, which only the row used to show.
- Values are shown as typed and never reformatted (the same `fmtValue`). No colour judges a value; no new chips.
- Keys kept: `timeline-entry-<id>`, `version-<id>`, `lab-row-<id>`, `lab-flag-<id>`, `lab-range-<id>`, `lab-correct-<id>`, `lab-report-<i>-<id>` (now inside Details), `lab-group-<id>`, `lab-group-row-<id>`, `labs-group-rule` and `lab-group-rule` (inside Details), `tool-*`, `glossary-<id>`, `guide-system-<id>`, `font-preview-*` (under "See each font"). `timeline-lab-report-<id>` is gone: the report's lines are in the record sheet's Details. New: `timeline-day-<yyyy-mm-dd>`, `details-timeline-<rootId>`, `version-details-<id>`, `details-lab-<id>`, `details-labs-groups`, `details-lab-group`, `details-lab-group-<id>`, `details-font-previews`.
- `tools/flutter_screen_matrix.mjs` expects "Light or dark" as Settings' first heading.

## U041 audit

A first-time reading of every main screen, for someone who has never seen the app and has no medical or technical knowledge. Sources: the newest screen matrix (`reports/runtime/screen-matrix/e717d6c5aa22/`), `reports/runtime/u036/`, `u037/` and `u038/`, and the screen code at cbad01f. No new screenshots were taken (no web or Linux build in this Forge); every fix has a widget test in EN and TR, at 320 dp with 2× text where a screen changed (`test/widget/u041_first_time_test.dart`).

| # | Friction (evidence) | Fix |
|---|---|---|
| 1 | Nutrition, Activity, Conditions, Preventive and Documents said only "Nothing recorded yet." / "Henüz kayıt yok." when empty, and so did the visit summary; Labs and Medications already named the first step (`strings.dart` `docNone`, `prevNone`, `condNone`, `actNone`, `foodNone`, `summaryEmpty`; the web smoke expected the bare sentence) | each keeps "Nothing recorded yet." and adds one sentence naming what its Add action adds ("To start, add a walk or a workout." / "Başlamak için bir yürüyüş ya da antrenman ekle."); the summary says what appears there. Missing is still said as missing |
| 2 | The weight card's empty state named no step, and in Turkish used "kilo" under the title "Vücut ağırlığı" and the field "Ağırlık (kg)" (`u036/phone_tr-TR_Today.png`) | "No weight recorded yet. Type it in the field and press Save." / "Henüz ağırlık kaydı yok. Alana yaz ve Kaydet'e bas." |
| 3 | Instructions named the wrong device: Learn's how-to read "Six short steps, all with the mouse" / "Fareyle yapılan altı kısa adım" on a phone (`u038/phone_en_learn.png`), its steps said "click"; Today said "Tap one to add" / "Eklemek için birine dokun" on a desktop (`u036/desktop_tr-TR_Today.png`); the trend legend and the body guide said "Click" | device-neutral verbs: choose / press / select, seç / bas. The how-to hint now says what it covers ("Add, find and fix a value, add a lab result, keep a copy") and its steps still name the real buttons |
| 4 | The how-to's six tasks carried large accent numbers 1–6, but they are independent tasks, not a sequence (`how_to_screen.dart`, decorative numbering) | the numbers are gone; each task is its title and one paragraph. Keys `howto-step-<n>` are kept |
| 5 | Turkish broke the L001 words: Learn's introduction said "kelime" (the rule is "sözcük", and the same screen says "Burada geçen sözcükler") and "Human OS'ta" (the product name takes no suffix); the passphrase hint said "kelime" (`destinations.dart` Learn, `passphraseHint`) | "sözcük" throughout and "uygulamada" |
| 6 | The Timeline showed "Show deleted and withdrawn" / "Silinenleri ve geri çekilenleri göster" above the first record with no explanation of either word (`u038/phone_tr_timeline-list.png`) | one quiet line under the switch: "Records you deleted or marked as entered in error stay in history." / "Sildiğin ya da yanlışlıkla girildi diye işaretlediğin kayıtlar geçmişte kalır." (key `timeline-show-hidden-help`), read out with the switch |
| 7 | First run, the visit summary and "Worked out from your records" had no reading column: on a wide window the text and first run's filled button ran the whole window width (`first_run_screen.dart`, `summary_screen.dart`, `derived_screen.dart`: padding only); at 320 dp with 2× text the summary's title was cut ("Summary for a visit", found by the new test) | the same centred column of at most 840 dp as the main screens (`ReadingWidth`, the scroll view keeps the whole width); the summary and derived titles scale down instead of being cut, as the how-to's already did |

Checked and left as they are: tap targets (buttons, term links, Details toggles and tool rows are at least 48 dp; the build strip's own toggle is shorter, but it only repeats the strip's sentence, which a screen reader already reads whole); contrast (secondary text uses the tested `onSurfaceVariant`); no colour judges a value and no score, streak or praise was found. The area introductions keep their three short labels (U031). Invariants are unchanged: no text says a value is good or bad, missing stays "not recorded", and nothing new is counted or inferred.
