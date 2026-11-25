# Q007: screen matrix after U043

Run of `tools/flutter_screen_matrix.mjs` at 637f6e3 (app code equals 4907512, current main; 637f6e3 only adds the U043 cells to the tool), against fresh development web builds (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`), Chromium 153, with a new, empty cache directory, `MATRIX_ONLY='^(base (small-phone|desktop)|text-2x|sheets|u041|u043)'`: 320x640 at 1× and 2× text and 1440x900, EN and TR. Machine results: `matrix.json`, `matrix.md`. Screenshots named `q007_*` were taken with the same release build by a small Playwright helper script that is not part of the repository (keyboard focus, Settings rows and chips the matrix's shot does not reach).

## New cells (tool, 637f6e3)

U043 put `WholeChip` in 16 files. Settings, first run and the Labs add sheet already had cells. The new `u043` groups open the rest: the sleep, feeling and glucose sheets on Today, the add sheets of Nutrition, Conditions, Preventive, Documents and Medications, the weight trend (range chips) and the body guide (plain chips). Each chip cell selects one chip and checks `chip_checked` (the chip is a semantics checkbox with `aria-checked=true`). Groups: 320x640 at 1×, at 2× text, at 2× text in the **light** theme (chosen in Settings, `theme_applied`), and 1440x900 at 1× (dark, the default); EN and TR. 80 cells; 198 cells as Q006. Total 278.

Not reached: Genetics (needs a DNA file), the Timeline correction sheet (needs a saved glucose record) and the measurement card's saved-note chips (need saved notes).

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`) | 278 | 275 | 3 |
| After review by eye (app at 637f6e3) | 278 | 258 | 20 |

By eye: the 60 phone screenshots of the `u043` groups (all three phone groups, both languages), the desktop Medications sheet, the 2× first run, Settings and Labs shots, and 16 `q007_*` helper shots. Other cells keep the script's verdict.

## Q006's five by-eye FAILs: gone

1. Settings, measurement order at 2× text: "Waist circumference", "Oxygen saturation (SpO2)", "Blood glucose (finger-prick meter)", "Kan şekeri (parmaktan ölçüm)", "Bel çevresi" are whole; Up and Down sit on a line under each name (`q007_text-2x_small-phone_en-US_Settings-measurement-order.png`, `…_tr-TR_…`).
2. Palette card: "Standard" and "Standart" are whole beside the tick (`q007_text-2x_small-phone_{en-US,tr-TR}_Settings-palettes.png`).
3. First run, EN, 2×: the chosen chip reads "✓ Same as this / device", wrapped between words (`u041-text-2x_small-phone_en-US_First-run-look.png`). Settings' language and text-size chips likewise (`q007_text-2x_small-phone_{en-US,tr-TR}_Settings-language-chips.png`).

## Chips (by eye)

- Labels whole on every chip screen at 2× text, EN and TR: they wrap between words ("what a clinician / told me", "bir hekimin bana / söylediği", "etikette / belirtilmemiş", "letter from a / doctor", "Bir sınırın altı ya da / üstü"), never inside a word, never faded or ellipsized (`u043-text-2x_*`, `u043-light-2x_*`, `q007_text-2x_small-phone_tr-TR_Labs-kind-chips.png`).
- Targets: `touch_targets` passes in every phone cell (every chip at least 48x48; a one-line chip is 48 tall at 1× and 68 at 2×, a two-line chip 108 at 2×).
- Selected chip readable: dark (teal-grey fill, light text, tick) and light (pale teal fill, dark text, tick) in every 2× cell.
- `chip_checked` passes in all 72 chip cells.

## Keyboard and web semantics (Chromium, Playwright)

- Desktop Settings, EN: Tab reaches the "Light" chip, then "Dark"; a 2 dp ring in the primary colour is drawn around the focused chip, selected or not, in the dark and the light theme (`q007_desktop_en-US_focus-*.png`). Space selects the focused chip.
- Desktop sleep sheet, TR: Tab reaches "Dinlenmiş"; Space selects it; ring and tick visible (`q007_desktop_tr-TR_sleep-sheet-focus-selected.png`).
- The focused DOM node is `flt-semantics role="checkbox"`; a selected chip has `aria-checked="true"`, an unselected one `"false"`.

## FAIL

1. **Documents and Preventive add sheets: field names ellipsized** (12 cells by eye: both sheets, EN and TR, 320 dp at 1×, 2× and 2× light). "Title, in your words (e.g. blood t…", "Date on the document (optional,…", "Başlık, kendi sö…", "What it is, in yo…", "Ne olduğu, kendi sözlerinle (ör. t…". U043's rule (a label is never cut) was applied to the other sheets through `WholeLabelField`; these two used a plain `labelText`. Shots: `u043_small-phone_tr-TR_Documents-add-sheet.png`, `u043_small-phone_en-US_Preventive-add-sheet.png`, `u043-text-2x_*_{Documents,Preventive}-add-sheet.png`. **Fixed** in a `Q007 fix:` commit (both `_field`s use `WholeLabelField`; `test/widget/q007_field_labels_test.dart`, 6 tests, all fail on the old code). The matrix was not run again on the fix.
2. **Medications add sheet: stacked headings** (script: desktop EN and TR; by eye also the 6 phone cells, where the script passes). The sheet's title "Add a medicine or supplement" / "İlaç ya da takviye ekle" has the section heading "From the pack" / "Kutudan" directly under it. Not a chip finding and older than U043 (the sheet had no cell before); not fixed. Shots: `u043_desktop_{en-US,tr-TR}_Medications-add-sheet.png`.

## False FAIL (script)

- `Labs: more from the report`, TR, 2× text, `text_scaled_2x` (heading 20 → 20). The text is at 2× (`sheets-text-2x_small-phone_tr-TR_Labs-more-from-the-report.png`), but the target heading ended under the sheet's Save and Cancel bar, so its semantics box was clipped to one line. In a sheet `reveal` limits the target to the window bottom less 10 px and does not know the sheet's own bar; it passed in Q006 because U043's taller chips moved the heading. Not fixed in the tool. The same limit leaves the selected chip half under the bar in some `u043` shots (Conditions, Nutrition, Preventive at 2×); scrolled further it is whole (`q007_text-2x_small-phone_tr-TR_{Conditions-source,Nutrition-label}-chip.png`).

## Seen, not a FAIL

- Plain chips of the body guide are not focusable (as intended, they do nothing).
- Other plain `labelText` fields (Activity, the Timeline correction sheet, the vault gate) were not checked at 2× text.

Screenshots of other cells were deleted for disk space (their checks remain in `matrix.json`). 58 screenshots are kept.

## After the independent review

No blocking findings; the 6 field-label tests fail on the old screens. Notes for the next matrix Forge:
- `text_scaled_2x` runs only for variants ending in `text-2x`, so the `u043-light-2x` group relies on the review by eye for 2× text.
- `theme_applied` reads only the Light chip's state, not the colours.
- `pickChip` skips the tap when a chip already starts checked, so `chip_checked` can pass without the cell selecting it.
- The reveal does not know a sheet's Save bar (the false Labs FAIL, half-hidden chips in some shots).
