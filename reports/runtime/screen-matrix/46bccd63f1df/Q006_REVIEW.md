# Q006: screen matrix after U042

Run of `tools/flutter_screen_matrix.mjs` at 46bccd6 (app code equals 6134c78; 46bccd6 changes only the tool), against fresh development web builds (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`), Chromium 153, with an empty cache directory, `MATRIX_ONLY='^(base (small-phone|desktop)|text-2x|sheets|u041)'`: 320x640 at 1× and 2× text and 1440x900, EN and TR, the same 198 cells as Q005. Machine results: `matrix.json`, `matrix.md`. Every Today, Settings, Derived and first-run screenshot was looked at by eye, plus the 2× TR screens and extra screenshots of Today's tool sections and Settings' measurement order (`q006_*`, taken with the same release build by a small helper script that is not part of the repo).

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script, first run at 6134c78 (tool before the fix) | 198 | 185 | 13 |
| Script (`matrix.md`, 46bccd6) | 198 | 198 | 0 |
| After review by eye | 198 | 193 | 5 |

## U042 confirmed

1. **Stacked headings on Today: fixed.** `no_stacked_headings` passes in all 198 cells; Q005 had 18 FAILs (Today, Today: restore from file, Today: weight empty; EN and TR; phone 1×/2× and desktop). "Tools" is gone; "For a visit and your numbers" / "Muayene ve sayıların için" and "Read a file" / "Dosya oku" each head their own section (`q006_small-phone_en-US_Today-tool-sections.png`, `q006_small-phone_tr-TR_…`, `q006_text-2x_small-phone_tr-TR_…`, `q006_desktop_tr-TR_…`, and the matrix's `sheets_desktop_*_Today-restore-from-file.png`). Settings' switch reads "Tools: for a visit, read a file" / "Araçlar: muayene için, dosya oku".
2. **TR Derived title: fixed.** At 320 dp with 2× text it reads "Kayıtlarından / hesaplananlar", broken only between words and drawn a little smaller than 2× (`u041-text-2x_small-phone_tr-TR_Derived.png`); EN keeps 2× ("Worked out / from your / records"). Summary and first-run titles also wrap between words. `title_whole` passes in all 30 cells.

## `not_cut_at_list_end`: what it reported, and the tool fix (46bccd6)

The first run (tool at 6134c78) had 13 FAILs, all on the new check, and all false:

- **No navigation bar, but one assumed (12 cells).** On a pushed page (Settings → About, first run) no tab exists, and `reveal` then took the bar's top as `640 - 85 = 555`. The last Settings row "About Human OS" (ends at 608, 32 px of padding below it, window 640) and first run's Next/Start buttons (end at 560) were recorded as cut: `Settings: about` (sheets, sheets-text-2x; EN, TR) and `First run: look` / `Nutrition: empty` (u041 and u041-text-2x, small phone; the second cell leaves first run through its Start button). Not one of the two cases the U042 review named. Fix: on a pushed page or first run, where there is no bar, the limit is the window bottom less 10 px, as on the desktop; on a shell screen whose tabs are not found the 85 px is still assumed.
- **A box clipped at both ends (1 cell)** — a version of the review's case (b): `Timeline: show deleted`, TR, 2× text. The switch with its help line is taller than the list's viewport, which starts at 100 px under the development banner (the tool assumes 64). Flutter clips its semantics box to 100..560, the bar's top. Wheeling moves the list but not the clipped box, so the box looked as if it were at the end of the list, and `heading_visible` failed as well. Fix: when the box stops moving, the tool wheels 40 px back up. If the box still does not move but the pixels between the bars change, the box fills the space and is judged by the existing taller-than-the-space rule (its top in the upper third). A box at a real list end moves down, and a page that does not scroll keeps its pixels, so both are still recorded as cut. The 2 px margin, the bar detection on shell screens and every other check are unchanged.
- Case (a) of the review (desktop limit 10 px above the window bottom) did not happen in any desktop cell. It is not changed.

With the fix (198/198) no real cut at a list end was found.

## FAIL by eye (none is caught by a script check; all at 320 dp with 2× text; all were already there before U042)

1. **Settings, Today's measurement order: labels broken inside words**, EN and TR: "Waist circu / mference", "Oksijen sat / ürasyonu", "Kan şekeri (parmakta / n ölçüm)". The checkbox and the up/down buttons leave about 140 dp for the label. Cells `text-2x Settings` EN and TR. The matrix's own shot shows only the top of Settings. Screenshots: `q006_text-2x_small-phone_en-US_Settings-measurement-order-midword.png`, `q006_text-2x_small-phone_tr-TR_Settings-measurement-order-midword.png`.
2. **Settings palette card: the selected name is broken inside the word**: "Stand / ard" (EN), "Stand / art" (TR). The tick beside the name takes the width. Cells `sheets-text-2x Settings: palettes` EN and TR: `sheets-text-2x_small-phone_en-US_Settings-palettes.png`, `…_tr-TR_…`.
3. **First run, EN: the selected language chip is cut**: "✓ Same as this de…" (faded at the chip's edge). Flutter reports no overflow for a faded chip label. The same chip is visible in Q005's screenshot. TR "Bu cihazla aynı" fits. Cell `u041-text-2x First run: look` EN: `u041-text-2x_small-phone_en-US_First-run-look.png`. The same `ChoiceChip` + `Text(label)` pattern is in Settings (`settings_screen.dart` `choices`), so Settings' language chip at 2× is probably cut too (not captured).

These were not fixed. U042 limited "draw smaller only as much as the longest word needs" (`WholeWordText`) to titles. Using it on list labels, card names or chips, or laying those rows out again at large text, is a design choice for a UI Forge. The chip pattern is also used at about 10 places.

## Seen, not a FAIL

- On Today the section headings ("For a visit and your numbers", "Read a file") look almost the same as the row titles below them ("Summary for a visit", "Plant chemicals"): same size, only a little bolder, most visible at 2× text (`q006_text-2x_small-phone_tr-TR_Today-tool-sections.png`). The hierarchy is weak, but nothing is stacked.
- Settings' "Explore Human OS" switch says "Turn off here or in Settings" / "Buradan ya da Ayarlar'dan kapatabilirsin" while it is shown in Settings.
- No overflow, no Flutter exception, no English word on a TR cell, no target under 48 dp, no horizontal scroll in any cell.

Screenshots of other cells were deleted for disk space (their checks remain in `matrix.json`). 50 screenshots are kept.

## After the independent review

No blocking findings. Corrections and notes:
- FAIL item 2: the kept EN palette screenshot ends at the "Palette" heading and does not show "Stand/ard"; the TR shot shows "Stand / art". The EN case was seen live, not in a kept shot.
- The reveal's `noBar` relies on the tool's own route bookkeeping (pushed page, first run). It is correct while only the app shell has a bottom bar; if a pushed page ever gets a bottom bar or footer, the tool must check the DOM instead.
- The tall-target branch does not verify that the box touches both window edges; it relies on the box not moving after a wheel step while the page does.
- The first-run counts (185 / 13) come from the run log, not from a file kept in the repository.
