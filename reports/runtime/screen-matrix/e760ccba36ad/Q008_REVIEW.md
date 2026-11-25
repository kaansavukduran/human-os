# Q008: screen matrix after U044

Run of `tools/flutter_screen_matrix.mjs` at e760ccb (app code equals 850a1e8, main after U044; e760ccb only adds the Q008 cells to the tool), against fresh development web builds (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`, `SOURCE_REVISION=850a1e8`), Chromium 153, with a new, empty cache directory, `MATRIX_ONLY='^(base (small-phone|desktop)|text-2x|sheets|u041|u043|q008)'`: 320x640 at 1× and 2× text, 1440x900, and (new) 840x900 and 1000x900, EN and TR. `MATRIX_SWEEP_SHOTS` (new, not part of the verdict) saved one screenshot per sweep step of every sheet cell at 320 dp 2× text, Settings at 2× and the 840 rail at 2×, for the review by eye. Machine results: `matrix.json`, `matrix.md` (build paths shortened to `scratch/…`; the builds and cache were deleted after the run). Build hashes (main.dart.js sha256): release `5ffa88c3…`, debug `a8a98bc7…`.

## New cells (tool, e760ccb)

- `q008`: the **Activity add sheet** (target: its last field, "When" / "Ne zaman") and the **Timeline correction** of a finger-prick glucose that the cell first saves through Today's measurement sheet (target: "When it was measured" / "Ölçüm zamanı"). 320x640 at 1× and 2×, 1440x900; EN and TR. 12 cells.
- `q008-rail`: Today, Timeline, Labs, Nutrition, Learn in **840x900 and 1000x900** windows (compact 80 dp rail) at 1× and 2× text, with a new check `rail_in_window` (at least 11 rail items, each ending within 81 px of the left edge and above the window bottom). 40 cells.
- Every other add or edit sheet already had a cell: Nutrition, sleep, Conditions, Preventive, Documents, Medications (u043), Labs and the dose sheet (sheets).
- **Vault gate: not reached, not faked.** A web build never has a vault (`storage_web.dart` returns browser storage or memory, whatever `APP_ENV` is), so neither create nor unlock can be shown in Chromium. It remains covered only by the U044 widget tests.
- Tool fix found while adding the cells: a sheet whose own Save scrolls with its fields ("Save measurement", "Save correction") but whose Cancel passes near the window bottom could be taken for a sheet with a Save bar. The bar now counts only when its band holds the bar's own Save. fd81ddf adds `MATRIX_VERBOSE` lines that name the limit a sheet reveal used.

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`) | 330 | 330 | 0 |
| After review by eye (app at 850a1e8) | 330 | 327 | 3 |

By eye: every sheet at 320 dp 2× text, EN and TR (contact sheets of the sweep shots: Labs add and "more from the report", dose, Timeline record, Medications, Nutrition, Conditions, Preventive, Documents, sleep, feeling, glucose, Activity, Timeline correction), Settings at 2× (all sweep shots, both languages), the rail at 840 and 1000 (1× and 2×, both languages), the desktop Medications sheet and Timeline correction, and the light 2× Medications sheet. The other cells keep the script's verdict.

## U044's tool changes, run in a browser

- **Reveal stops at a sheet's Save bar.** With `MATRIX_VERBOSE`, sheets with a pinned bar log `limit: sheet Save bar at 567` (320x640). "Labs: more from the report" (TR, 2×) is now scrolled clear of the bar and passes `text_scaled_2x` (heading 20 → 120, ×6; Q007's false FAIL is gone; `sheets-text-2x_small-phone_*_Labs-more-from-the-report.png`). The selected chips of Conditions, Nutrition and Preventive at 2× are whole above the bar (`u043-text-2x_*`).
- **Only the bar's own Save/Cancel count as in view inside it:** the Medications add sheet's Save, revealed while the dose cell is set up, logs `in view: the sheet bar's own button 576 48, bar top 567`. No cell's verdict target is a bar button, so this branch is checked by the log, not by a verdict. Sheets without a bar (measurement sheet, Timeline record and correction) log `no sheet bar, window bottom 630`.
- **`text_scaled_2x` runs for every 2× group:** 130 cells in 7 variants (text-2x, sheets-text-2x, u041-text-2x, u043-text-2x, **u043-light-2x** (20 cells, ×2.00 to ×6.00), q008-text-2x, q008-rail-text-2x). All PASS.
- **`chip_checked`:** 72 cells, all PASS. In every one the cell made the selection itself (`aria-checked false → true`). **Not shown in a browser:** a cell whose chip *starts* checked. No matrix cell has one, and a one-off probe (the glucose unit chip after a saved mmol/L record) did not reach its sheet. The rule is in the code (`selected` requires `tapped && before !== 'true' && after === 'true'`), but no run proves it.

## FAIL (by eye)

1. **Settings, 320 dp, 2× text, EN: a switch title broken inside a word.** "Measurement / s before the / weight card" (`text-2x_small-phone_en-US_Settings_sweep42.png`; the cell `text-2x|small-phone|en-US|Settings` passes the script, which does not measure line breaks). Settings' `SwitchListTile` titles were plain `Text`. TR breaks only between words. **Fixed** in aa5b6a7 (`Q008 fix:`): every switch title and subtitle in Settings is a `WholeWordText` (D-054). `test/widget/q008_settings_switch_titles_test.dart` (EN, TR) fails on the old code ("More space between letters, words and lines" breaks inside a word in the test font).
2. **Timeline correction, 320 dp, 2× text, EN and TR (2 cells): help lines ellipsized.** "Save a better value for the same measurement. The ol…", "YYYY-MM-DD HH:MM, your device's time. Change it only if the r…", "Eski değer geçmişte …", "Yalnızca ölçüm başka…" (`q008-text-2x_small-phone_{en-US,tr-TR}_Timeline-correction_sweep*.png`). The correction fields allowed 3 helper lines. At 1× they fit (`q008_small-phone_en-US_Timeline-correction.png`). **Fixed** in aa5b6a7: 20 lines, as Labs, Medications and Conditions allow. `test/widget/q008_correction_helpers_test.dart` (EN, TR) fails on the old code.

After the fix: dart format, flutter analyze (no issues) and `TZ=UTC flutter test` (1579 passed, 1 skipped). **The matrix was not run again on the fix.**

## By eye, PASS

- **Field names whole** in every sheet at 320 dp 2× text, in both languages. A name too long to fit inside its field is drawn whole above it and wraps only between words ("Raporda yazan referans aralığı (isteğe bağlı)", "Where you keep it (optional, e.g. paper folder at home)", "Blood glucose, as the meter showed").
- **No heading directly under a sheet title.** Medications ("İlaç ya da takviye ekle" → "Adı (kutudaki gibi)") and Labs ("Add a result from a report" → "Test name as printed") start with a field. The Timeline sheet has a sentence between its title and "Versions".
- **Rail (840 and 1000, 2× text):** 11 items inside 80 dp, lowest ends at 883 of 900. Labels are readable and at most 2 lines ("Zaman / çizelgesi", "Diğer / alanlar", "More / areas"). "Medications" is drawn at about its 1× size while the other labels grow to 1.3×, because its single word fills the 64 dp (D-054, as designed).

## Seen, not a FAIL

- Activity's and Nutrition's time chips sit partly under the Save bar in the cell's own shot. Their field (the target) is clear, and they scroll.
- The English lab value hint reads "e.g. 5,4" with a decimal comma (out of scope, not changed).
- Not reached as before: Genetics (needs a DNA file) and the measurement card's saved-note chips.

## Screenshots

49 are kept: 42 cell shots and 7 sweep shots (`*_sweepNN.png`). The others were deleted for disk space. Their checks remain in `matrix.json`, whose `screenshot` field still names the deleted files.

## Commit hashes on the branch

The worktree commits were cherry-picked, so the hashes above map as follows (identical trees): e760ccb → 6ffd318, fd81ddf → aa40177, aa5b6a7 → 08e59c2, 17a0637 → a624fe9. The folder name `e760ccba36ad` keeps the matrix's source hash.

## Independent review (APPROVE) and follow-ups

- The Save-bar match also accepts "Save correction" / "Düzeltmeyi kaydet" (Labs correction sheet), so that bar is not missed.
- Timeline correction `errorMaxLines` 3 → 20, like the help lines.
- Still open: the rail count can be made up by a non-rail control with left < 40 (not possible in today's layouts); the Turkish Activity date pattern wraps at a hyphen; the fixes are widget-tested, not re-run in the matrix.
