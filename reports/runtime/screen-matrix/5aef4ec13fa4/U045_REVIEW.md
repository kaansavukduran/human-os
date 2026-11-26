# U045: screen matrix on the Q008 fixes and U045

Run of `tools/flutter_screen_matrix.mjs` at 5aef4ec (the U045 tool changes; app code equals 7a758bb, the U045 app commit, which sits on 47c08f2, main after Q008). Fresh development web builds of 7a758bb (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`, `SOURCE_REVISION=7a758bb`), Chromium 153, a new empty cache directory, working tree clean. Builds and cache were deleted after the run; `matrix.json` and `matrix.md` name them `scratch/…`. Build hashes (main.dart.js sha256): release `855e04f7…`, debug `dedd90f9…`.

Selection (a subset of the matrix, not the whole of it):

- `MATRIX_ONLY='^(base small-phone|text-2x|q008|u043)'`
- `MATRIX_CELLS='^(Settings|Activity: add sheet|Timeline: correction|Today|Timeline|Labs|Nutrition|Learn|Today: (sleep|feeling|glucose) sheet|(Nutrition|Conditions|Preventive|Documents|Medications): add sheet|Trend: weight|Learn: body guide)$'`
- `MATRIX_SWEEP_SHOTS` (not part of the verdict): Settings at 320 dp 2×, every `q008-text-2x` cell, the 840 rail at 2× (Today; these 12 sweep shots were not looked at).

| Asked for | Group(s) | Cells |
|---|---|---|
| Settings 320x640 2× EN/TR (Q008 switch titles) | `text-2x` (Settings; also Today, Timeline, Labs, Nutrition, Learn), with `base small-phone` as its 1× reference | 12 + 12 |
| Timeline correction 320x640 2× EN/TR (help, errors) | `q008-text-2x` (with `q008` at 1× and desktop) | 4 + 8 |
| Activity add sheet TR 2× | `q008-text-2x` (EN too) | in the 4 above |
| Compact rail 840 and 1000 x 900, 1× and 2× | `q008-rail`, `q008-rail-text-2x` (Today, Timeline, Labs, Nutrition, Learn) | 20 + 20 |
| Theme groups | `u043` (dark, 320 dp and desktop), `u043-text-2x` (dark), `u043-light-2x` (Light chosen in Settings) | 40 + 20 + 20 |

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`) | 156 | 156 | 0 |
| By eye (only the cells looked at, see below) | 20 | 20 | 0 |

The by-eye count covers only the cells whose screenshots were looked at: Settings 2× EN and TR (all 59 EN sweep shots; TR sweeps 10–59 of 64, the first ten and last four were not looked at), Timeline correction 2× EN and TR (all sweep shots), Activity add sheet 2× EN and TR (all sweep shots) and TR at 1× and on the desktop, 8 rail cells (840 1× Today EN/TR, 840 2× Today EN/TR, 840 2× Timeline EN, 1000 1× Timeline EN/TR, 1000 2× Labs TR) and 4 theme-group cells (light 2× Medications TR and Trend EN, dark 320 dp Conditions TR, desktop Medications TR). The other 136 cells keep the script's verdict only.

Per check (script): heading_visible, controls_named, no_page_errors, no_console_errors, no_failed_requests, no_horizontal_scroll, no_flutter_overflow, no_flutter_exceptions (debug build), no_stacked_headings, not_cut_at_list_end, theme_applied: 156 PASS each. touch_targets 92 PASS (64 not applicable: desktop and rail windows). rail_in_window 40 PASS. text_scaled_2x 76 PASS. chip_checked 72 PASS. no_english_on_tr 78 PASS.

## U045's tool changes, run in a browser

- **`rail_in_window` counts only the rail's own items.** The web build gives the rail a semantics group 80 px wide; the check takes the outermost node within 81 px of the left edge (at least 200 px tall) above a control near the left edge, and counts the buttons and tabs inside it. Every rail cell: `11 items inside the rail node (0,85 80x815)` at 1×, `(0,101 80x799)` at 2×; widest item ends at x 80, lowest at y 854 of 900 (2×). A control outside that node cannot add to the count any more. **Not shown in a browser:** a page with such a control (none exists today), so the exclusion is proven by the code and the logged node, not by a failing cell.
- **`theme_applied` measures rendered colours** in all 156 cells (no palette group was in this run). Dark cells: the most common colour is the dark surface `#101819`, the dark card `#172224` (320 dp sheets), or the dark surface under the black 54 % modal barrier `#070b0b` (desktop sheets); dark surfaces cover 73–100 % of the window, light surfaces 0 %. Light cells: `#ffffff` (card) or `#f6f8f8` (surface), light surfaces 75–92 %, dark surfaces at most 4 % (text). The first trial without the barrier colours failed the desktop sheets (`#070b0b`, not a theme surface); the barrier was then added as Material's documented `Colors.black54`. **Not shown:** a cell where the theme is wrong; a swap would fail on both conditions (the most common colour and the 25 % share), but no run proves it.

## By eye, PASS

- **Settings, 320 dp, 2× (Q008 fix, aa5b6a7):** every switch title wraps only between words in both languages: "Measurements / before the / weight card", "Open the / number pad in / every / measurement", "Sleep and / How you feel / at the top of / Today"; "Ölçümler / ağırlık / kartından / önce", "Harfler, / sözcükler ve / satırlar / arasında daha / fazla boşluk". Q008's "Measurement / s before the" is gone (`text-2x_small-phone_en-US_Settings_sweep41.png`, `…_sweep42.png`, `…_tr-TR_Settings_sweep20.png`, `…_sweep44.png`).
- **Typed-date pattern (U045 #3):** the Activity help reads "SS:DD ya da / YYYY-AA-GG SS:DD; / boş = şimdi" at 2× (Q008: "YYYY-AA- / GG SS:DD"), EN "HH:MM, or / YYYY-MM-DD HH:MM; / blank = now" (`q008-text-2x_small-phone_tr-TR_Activity-add-sheet_sweep01.png`, `…_en-US_Activity-add-sheet_sweep03.png`). The correction help "YYYY-AA-GG SS:DD, / cihazının saati. …" and Settings' "biçim / YYYY-AA-GG SS:DD / olarak kalır." keep the date whole too. No visible mark where the word joiners are.
- **Timeline correction, 2× (Q008 fix):** the help under "When it was measured" / "Ölçüm zamanı" is whole on six lines, nothing ellipsized, in both languages (`q008-text-2x_small-phone_*_Timeline-correction_sweep*.png`).
- **Rail (U045 #1):** the selected label ("Today", "Timeline", "Bugün", "Zaman / çizelgesi", "Tahliller") is drawn in the same font and size as the unselected labels, in bold, at 1× and 2× (the 8 rail cells above); at 2× all labels grow together (capped at 1.3×) and "Zaman çizelgesi" wraps between its words. Q008 noted the selected label drawn at the default size; it no longer stands out. "Medications" / "İlaçlar" stays about 1× at 2×, as designed (D-054). The extended rail on the desktop (1440) shows the selected "İlaçlar" at the same size as the others.
- **Themes:** dark sheets and pages use the dark card and surface; the light 2× cells are light throughout, with the Light chip ticked.

## Not reached

- **Timeline correction error messages** (Q008's `errorMaxLines` follow-up): no cell types an invalid time, so no error line is shown in the browser. Widget-tested only (`test/widget/q008_correction_helpers_test.dart`).
- **Vault gate:** a web build keeps no vault (as in Q008).
- The rest of the matrix (palettes, phone, tablet, other sheets and tools) was not run here; their last run is Q008.

## Seen, not a FAIL

- TR Settings, About: "Yüklü sürüm: unknown (kaynak 7a758bb)". `unknown` is the build's fallback when `APP_VERSION` is not passed (`app_config.dart`); this test build did not pass it. A release build passes it. Not changed (out of scope).
- Activity's time chips sit partly under the Save bar in the cell's own shot (as in Q008); they scroll.

## Screenshots

32 are kept (21 cell shots, 11 sweep shots); the other 304 were deleted for disk space. Their checks remain in `matrix.json`, whose `screenshot` field still names the deleted files.
