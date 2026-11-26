# Q009: full screen matrix after U045

Run of `tools/flutter_screen_matrix.mjs` at 33af491 (the Q009 tool commit: two new cells; app code equals 98dca35, U045 closed). Fresh development web builds of 33af491 (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`, `SOURCE_REVISION=33af491`), Chromium 153, a new empty cache directory, working tree clean (`working_tree_dirty: false`). Build hashes (main.dart.js sha256): release `8418bde6…`, debug `fa8ef575…`. Builds and cache were deleted after the run; `matrix.json` and `matrix.md` name them `scratch/…`.

**The whole matrix**: no `MATRIX_ONLY`, no `MATRIX_CELLS`, no sweep shots. Every group: base (320, 390, 820x1180, 1180x820, 1440 · EN/TR · all 11 screens), the three palettes (phone and desktop), `text-2x`, `sheets` (+ desktop, + 2×), `u041` (first run and empty states; + desktop, + 2×), `u043` (dark 320 dp and desktop, dark 2×, Light chosen in Settings at 2×), `q008` (Activity add sheet, Timeline correction), `q008-rail` (840 and 1000 wide, 1× and 2×), and the new `q009`.

**How it ran**: the release pass and the first 37 debug groups ran in one invocation, which the session's 2-hour limit for a background command stopped during the debug pass. The same command was started again on the same commit (HEAD checked out at 33af491, tree clean) with the same builds and cache directory: the 58 release and 37 debug groups already done were taken from that cache (same commit, build hashes and browser), the remaining 21 debug groups ran. `ran_at` is the second invocation.

## New cells (Q009)

| Asked for | Group(s) | Cells | Script check |
|---|---|---|---|
| Labs add sheet, sample-date field helper (TR `YYYY-AA-GG`, whole on one line at 320 dp 2×) | `q009` (320x640, 1440x900), `q009-text-2x` (320x640), EN/TR | 6 | `date_helper_one_line`: the helper's text is the language's whole pattern (word joiners ignored) and its box is at most 24 px tall per 1× of text, inside the window |
| Timeline correction with an invalid typed time, its error message (EN/TR, 2×, not cut) | same groups | 6 | `error_shown_whole`: after typing `25:99` in "When it was measured" / "Ölçüm zamanı" and pressing Save correction, the error under the field reads the whole `TIME_FORMAT` message and its box lies in the window. Whether its lines are drawn uncut is judged by eye |

What the cells measured: helper `YYYY-AA-GG` 72x17 (1×) and 139x33 at 2× (one line; a second line would be about 66), EN `YYYY-MM-DD` 77x17 and 149x33. TR error 256x51 at 1× (three lines), 256x164 at 2× (five lines), one line of 558 px on the desktop; EN 256x197 at 2× (six lines).

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`, 33af491) | 420 | 420 | 0 |
| By eye (only the cells looked at, below) | 35 | 35 (2 with a finding, fixed after the run) | 0 |
| Script, affected cells re-run on the fixes (`../5c2702f716cf/`) | 8 | 8 | 0 |
| By eye, re-run | 2 | 2 | 0 |

Per check (script, 420 cells): heading_visible, controls_named, no_page_errors, no_console_errors, no_failed_requests, no_horizontal_scroll, no_flutter_overflow, no_flutter_exceptions (debug build), no_stacked_headings, not_cut_at_list_end: 420 PASS each. theme_applied 408 PASS (12 palette cells: not applicable, they use `palette_applied`, 12 PASS). touch_targets 280 PASS (140 not applicable: desktop and rail windows). no_english_on_tr 204 PASS. text_scaled_2x 134 PASS. chip_checked 72 PASS. rail_in_window 40 PASS. title_whole 30 PASS. date_helper_one_line 6 PASS, error_shown_whole 6 PASS. lab_group_chart_spoken, lock_state_clear, about_sections_clear, restore_chooser_opens, restore_cancel_reported, switch_help_read_with_switch, howto_no_numbers: 6 PASS each.

**U045's checks across the whole matrix.** `theme_applied` (rendered colours) ran in all 408 cells without a palette, image and chart screens included (the mascot screens, the lab group chart, the weight trend, first run's palette cards, the desktop sheets under the modal barrier): most common colour dark surface in 263 cells, dark card in 91, dark surface under the scrim in 34, light card 16 and light surface 4 (the 20 Light cells). Dark cells: dark surfaces 73–100 %, light surfaces at most 2 %; Light cells: light surfaces at least 74 %, dark at most 4 %. No false FAIL, so the check was not changed. `rail_in_window` (rail-only): all 40 rail cells `11 items inside the rail node (0,85 80x815)` at 1× and `(0,101 80x799)` at 2×, widest item ending at x 80.

## By eye

Looked at (35 cells, one screenshot each): base 320 TR Today, 390 TR Labs, 820 TR Medications, 1180 EN Learn (compact rail), 1440 TR Settings; text-2x TR Medications; palettes Matrix phone Today, Axolotl desktop Today, Trans desktop Settings; sheets 2× EN "I took it", desktop TR and EN lab group "over time" (EN screenshot not kept), 2× TR field details, 320 TR About; u041 2× EN first run step 2, 320 and 2× TR Derived, desktop TR how-to and Summary; u043 light 2× EN glucose sheet, 320 TR feeling sheet, 320 TR body guide (screenshot not kept), desktop EN weight trend, desktop TR Documents sheet, 2× TR Conditions sheet; rail 1000 2× EN Nutrition, 840 TR Timeline; q008 320 TR Activity sheet; q009 all four 2× cells, desktop TR date helper, desktop EN and 320 TR correction error. The other 385 cells keep the script's verdict only.

PASS, against the standard (anti-slop, accessible, responsive, understandable without prior knowledge, complete Turkish, no judging colours):

- **Lab date helper (a):** "YYYY-AA-GG" under "Numune tarihi" on one line at 320 dp 2× (and 1×, and the desktop); EN "YYYY-MM-DD". No visible mark where the word joiners are.
- **Correction error (b):** at 2× the TR error "Zamanı 24 saatlik düzende YYYY-AA-GG / SS:DD ya da SS:DD yaz, / ör. 2026-11-07 07:30 / ya da 07:30." is whole on five lines, nothing ellipsized, in the error colour with the field outlined; the date pattern stays whole and only date and time go on separate lines (as U045 allows). EN whole on six lines ("24-/hour" breaks at its own hyphen, an ordinary English break). The message says what to write, not what is wrong with the person.
- **Themes and palettes:** dark pages and sheets dark throughout, Light cells light with the Light chip ticked; Matrix (green), Axolotl (pink) and Trans (light) applied. No value is coloured as good or bad anywhere seen; the error red is the only status colour, used for an input error.
- **Turkish:** complete on every TR shot looked at, except the one sentence fixed below and the version line under "Seen".
- **Rail and 2×:** rail labels whole, "Zaman / çizelgesi" between words; "Medications" stays near 1× at 2× by design (D-054). 2× pages wrap between words, nothing cut.

Findings (fixed after the run, 5c2702f; the 8 affected cells re-run, below):

1. **Weight "over time" not in the reading column** (`u043_desktop_en-US_Trend-weight.png`): on the 1440 desktop its range chips and "Nothing saved in this period." started at x 16 at the window's left edge, while every other page, the lab group's "over time" included, sits in the centred column (U036). `TrendScreen` now uses `ReadingWidth` and `readingPadding`. Test `test/widget/q009_trend_reading_column_test.dart` (EN/TR, 1440 and 320 dp): fails on the old code at 1440 in both languages (chip at 16, expected 316), passes at 320 on both.
2. **TR Medications promise unclear** (`base_tablet-portrait_tr-TR_Medications.png`, `text-2x_…`): "Reçete ya da hatırlatma alım değildir." ("alım" alone reads as a purchase as much as an intake, and the sentence does not say a plan is not a dose taken). Now "Reçete ya da hatırlatma, ilacı aldığın anlamına gelmez." (EN unchanged: "A prescription or reminder is not an intake."). Test `test/widget/q009_medications_promise_test.dart` (EN/TR): TR fails on the old code, EN passes on both.

**Re-run on the fixes** (`reports/runtime/screen-matrix/5c2702f716cf/`, fresh builds of 5c2702f, release `fd9bb643…`, debug `84289638…`; `MATRIX_ONLY='^(base (small-phone|desktop)|u043 (small-phone|desktop)) '`, `MATRIX_CELLS='^(Medications|Trend: weight)$'`): 8 cells, 8 PASS. By eye: the TR desktop weight trend now starts at x 316 in the reading column; the TR 320 Medications promise reads the new sentence, whole. The rest of the matrix was not re-run on 5c2702f (the two fixes touch only that page and that sentence).

## Seen, not a FAIL (open)

- **Derived page shows machine identifiers** (`u041_small-phone_tr-TR_Derived.png`, `u041-text-2x_…`): "Model paketi: MP-CORE-DERIVED-1 1.0.0", "Model: DERIVED-WAIST_HEIGHT_RATIO-1, sürüm 1"; at 2× the package id breaks at a hyphen ("MP-CORE- / DERIVED-1"). They show that a number is model output (an invariant), but a reader without prior knowledge cannot read them. Whether to show them in plain words (and keep the id under Details) is a design decision, so not fixed here.
- **TR About: "Sürüm: unknown"** (`sheets_small-phone_tr-TR_Settings-about.png`): the fallback when `APP_VERSION` is not passed, an English word on a TR screen (as in U045). This test build did not pass it; a release build does. Not changed.
- **Trans palette with "Koyu"/"Dark" ticked on a light page** (`palette-trans_desktop_en-US_Settings.png`): the note under the palettes says Trans has its own look and the theme and colour choices are kept for Standard; the ticked chip can still read as wrong. Not changed.
- **Body guide's part chips** ("Kalp", "Atardamarlar", 320 TR body guide) look like the tappable chips but are plain labels. Not changed.
- **Desktop correction cell:** the "Saved: 6 mmol/L · Show on Timeline" bar of the glucose saved before stays under the sheet's barrier; it persists by design when navigation is accessible (`measurements_card.dart`, `persist: accessible && go != null`), which the browser's semantics turn on.
- The lab group chart's axis uses "6.1" in EN and "6,1" in TR, while values stay as typed ("5,6 %" in EN as typed). As designed (kept as typed).

## Not reached

- **Vault gate:** a web build keeps no vault (as in Q008 and U045).
- **Genetics, plant compounds (Read a file tools), the backup and export flows beyond the restore chooser's cancel, a correction of other kinds (weight, blood pressure), the lab sheet's other errors:** no cell opens them. Phyto and genetics pages also do not use `ReadingWidth` (seen in the code, not in a browser).
- Real devices, Firefox, Safari, screen readers (TalkBack, VoiceOver, NVDA), the native desktop apps: not available in this container.
- The 385 cells not looked at by eye keep only the script's verdict.

## Screenshots

33 are kept here (the cells looked at, less the body guide and the EN lab group) and 2 in `../5c2702f716cf/` (35 in all); the other 387 here and 6 there were deleted for disk space. Their checks remain in each `matrix.json`, whose `screenshot` field still names the deleted files.

## Checks on the fixes

At 5c2702f: `dart format` (0 changed), `flutter analyze` (no issues), `TZ=UTC flutter test`: 1598 passed, 1 skipped, 0 failed.

## Commits

- 33af491: Q009 tool: the two cells and their checks (the matrix's source hash, this folder).
- 5c2702f: the two fixes with their EN/TR widget tests.
- the commit holding this report.
