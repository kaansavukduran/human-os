# U046: screen matrix on the U046 pages

Run of `tools/flutter_screen_matrix.mjs` at a677806 (the last U046 tool commit; app code equals 22b3941). Fresh development web builds of a677806 (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`, `SOURCE_REVISION=a677806`, no `APP_VERSION`), Chromium 153, a new empty cache directory, working tree clean (`working_tree_dirty: false`). Build hashes (main.dart.js sha256): release `8c7a063c…`, debug `9d4b5874…`. Builds and cache were deleted after the run.

Selection: `MATRIX_ONLY='^u046'`, the new U046 groups only (no other group of the matrix was run):

| Asked for | Cell | Groups | Script checks |
|---|---|---|---|
| Derived | `Derived: technical details` (its first "Technical details" opened) | `u046` 320x640 and 1440x900, `u046-text-2x` 320x640; EN/TR | `derived_plain_titles`, `machine_id_whole` |
| Body guide | `Learn: body guide parts` (Heart and blood vessels) | same | `parts_not_buttons` |
| Genetics | `Genetics` (reached from Today, "Read a file") | same | `reading_column`, `title_whole` |
| Plant compounds | `Plant chemicals` | same | `reading_column`, `title_whole` |
| About TR | `About: version` (EN too) | same | `version_localised` |
| Palette chip (point 5) | `Settings: theme under palette` (Matrix chosen in Settings) | same | `theme_note_shown` |

6 cells × 6 groups = 36 cells, every cell also with the standard checks (heading, names, errors, scroll, overflow and exceptions in the debug build, touch targets on 320 dp, theme, stacked headings, list end, TR English words, 2× text against the 1× group).

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script, final run (`matrix.md`, a677806) | 36 | 33 | 3 |
| By eye, final run (only the cells looked at) | 5 | 5 | 0 |
| Script, earlier run (`../58d391998d58/`, before two fixes) | 36 | 30 | 6 |
| By eye, earlier run | 16 | 14 | 2 (both fixed, then re-run above) |

Per check (final run, 36 cells): heading_visible, controls_named, no_page_errors, no_console_errors, no_failed_requests, no_horizontal_scroll, no_flutter_overflow, no_flutter_exceptions, no_stacked_headings, not_cut_at_list_end: 36 PASS each. theme_applied 30 PASS (6 not applicable: the palette cell chose Matrix). touch_targets 24 PASS (12 not applicable: desktop). text_scaled_2x 12 PASS. title_whole 12 PASS. reading_column 12 PASS. derived_plain_titles, machine_id_whole, parts_not_buttons, version_localised, theme_note_shown: 6 PASS each. **no_english_on_tr 15 PASS, 3 FAIL.**

The 3 FAIL are the same cause in all three TR Plant-chemicals cells (320, 320 2×, desktop): the intro quotes the USDA site's English button, `"Download these results as: CSV"`, and "results" is in the tool's English word list. The quote is deliberate (it names the button the person has to find on an English-only site), so it is not changed here; it stays an open point for the owner (for example, keep the quote and add a Turkish gloss; the check would still see the English word).

What the cells measured (final run): Derived's formula ID "DERIVED-BMI-1" is one line, 88x17 at 1× and 171x33 at 2× (EN and TR); the titles are the plain names, and no heading holds a machine ID. The intro of Genetics and Plant chemicals starts at x 316 on the 1440 desktop (column 316..1124) and at x 16 on 320 dp. All four heart parts are read as text and none is a control. About shows "unknown" (EN) and "bilinmiyor" (TR), and no "unknown" on a TR page. With Matrix chosen, the note under "Light or dark" is shown (EN and TR).

## By eye

Final run, 5 cells (screenshots kept here): 2× TR and EN Plant chemicals, 2× TR About, 320 EN body guide, 2× EN Settings with Matrix. Earlier run on 58d3919, 16 cells: Derived (2× TR and EN, 320 TR, desktop EN), body guide (320 TR, 2× EN, desktop TR), Genetics (desktop TR, 2× TR), Plant chemicals (desktop EN, 2× TR), About (320 TR, 2× TR), Settings with Matrix (2× TR, desktop EN, 320 EN). The other cells keep the script's verdict only.

PASS, measured against the standard (anti-slop, accessible, responsive, understandable without prior knowledge, complete Turkish, no colour that judges a value):

- **Derived:** each card is titled by its plain name ("Vücut kitle indeksi (VKİ)", "Bel-boy oranı"); the page line reads "Uygulamanın kendi formülleri, sürüm 1.0.0". "Teknik ayrıntılar" is closed until opened. Opened, it shows "Formül kimliği, sürüm 1" with "DERIVED-BMI-1" on the line below, in the muted small style, and the set ID below that. At 2× the IDs are whole on one line each. "eksik: vücut ağırlığı, boy" and the limitations are unchanged; nothing is judged. After the tap the opened header keeps a light highlight under the pointer (Material's hover or focus overlay).
- **Body guide:** "Ana parçalar" is followed by a bulleted list (Kalp, Atardamarlar, Toplardamarlar, Kılcal damarlar): no outline, no chip shape, nothing that looks tappable. 2× wraps between words.
- **Genetics, Plant chemicals:** on the desktop, a centred column aligned with the top of the page, as on the other pages. At 320 dp they use the full width.
- **About:** "Sürüm: bilinmiyor"; Turkish throughout.
- **Settings with Matrix:** "Açık ya da koyu görünümü şu an aşağıdaki Matrix paleti belirliyor. Burada işaretli seçim saklanır, Standart'ı seçince yeniden kullanılır." sits between the section title and the chips. The Dark chip is still ticked, and the line says why. At 2× it wraps between words.

Findings (earlier run, fixed, re-run above):

1. **Plant chemicals intro broke the address inside the word** (`../58d391998d58/u046-text-2x_small-phone_tr-TR_Plant-chemicals.png`: "phytochem.nal.usda.g / ov"). The intro is now `WholeWordText` (c53b4f0). In the final run, "phytochem.nal.usda.gov" is whole on one line in EN and TR at 2×. Widget test group 3b fails on the old code at 1× and 2×, in both languages.
2. **About broke the build profile inside the word** (`../58d391998d58/u046-text-2x_small-phone_tr-TR_About-version.png`: "GELİŞTİR / ME"). Names and values are now `WholeWordText` (22b3941). In the final run, "GELİŞTİRME" is whole, drawn smaller than the other values: one word is wider than its half of the row (the U042 rule). Test group 4b fails on the old code in both languages.

Before the earlier run, a first run (on 56b9e93; its folder was deleted and replaced by the runs above) showed at 2× TR "Formül kimliği, sürüm / 1" (the version number alone on a line) and a tool error: the ID was measured inside one merged node with its name. Fixed in af80962 (the ID is its own node; a no-break space keeps "sürüm 1" together) and 58d3919 (the tool measures the ID node, and reads the palette note to know Matrix was chosen: the swatch has no checked state on the web). The earlier run's 2× Genetics and Plant chemicals FAILs (`text_scaled_2x` ×1.32) came from measuring the top-bar title, which Material caps near 1.34×. a677806 measures the intro instead; nothing in the app changed for this.

## Not reached

- **Genetics with a loaded file**, and Plant chemicals with a loaded CSV: the cells open the empty pages only (no file chooser is driven). The reading column of the result lists is covered by the widget tests (the same `ListView`), not in a browser.
- **Derived with numbers:** the web build starts empty, so both cards show "needs: …". A worked-out value, its records and "worked out, not measured" were not seen in a browser (widget tests cover them).
- **Palettes other than Matrix** for the note; the existing palette groups were not run.
- **The rest of the matrix** (420 cells of Q009) was not re-run on U046. The changed pages and the Settings theme section are covered here; other screens share `WholeChip` (its `plain` variant removed, unused elsewhere) and `strings.dart`.
- Real devices, Firefox, Safari, screen readers (TalkBack, VoiceOver, NVDA), native desktop apps: not available in this container.
- The 31 cells of the final run not looked at by eye keep only the script's verdict.

## Screenshots

5 are kept here and 2 in `../58d391998d58/` (the two findings). The rest were deleted for disk space; their checks remain in each `matrix.json`, whose `screenshot` field still names the deleted files.

## Checks on the code

At 22b3941 (app) / a677806 (tool): `dart format` (0 changed), `flutter analyze` (no issues), `TZ=UTC flutter test`: 1631 passed, 1 skipped, 0 failed.
