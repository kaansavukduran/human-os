# Q005: screen matrix after U041

Run of `tools/flutter_screen_matrix.mjs` at 5a5a70e (tool commits only after fc445d0; the app code equals fc445d0, the `Q005 fix:` commit), against fresh development web builds (`--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`), Chromium 153, `MATRIX_ONLY='^(base (small-phone|desktop)|text-2x|sheets|u041)'`: 320x640 at 1× and 2× text and 1440x900, EN and TR. Machine results: `matrix.json`, `matrix.md`. Every U041 screenshot was looked at by eye; the result below adds what the script cannot see.

## Result

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`) | 198 | 180 | 18 |
| After review by eye | 198 | 179 | 19 |

New U041 cells (72): `u041` and `u041-text-2x` groups: first run (both steps), the empty states of Nutrition, Activity, Conditions, Preventive and Documents, the weight card's empty state, the empty visit summary, Derived, the Timeline switch with its help line, the how-to.

New checks for every cell: `no_stacked_headings`, `no_english_on_tr` (TR cells), `title_whole` (first run, Summary, Derived, how-to), `howto_no_numbers`, `switch_help_read_with_switch`; touch targets are now measured against 48 dp (44 before). Overflow and Flutter exceptions come from the debug build: none in any cell.

## FAIL

1. **Stacked headings on Today** (18 script cells: every Today cell and every "Today: restore from file" cell, EN and TR, phone 1×/2× and desktop). The section heading "Tools" / "Araçlar" stands directly above the group heading "For a visit and your numbers" / "Muayene ve sayıların için" (`today_screen.dart`, `_ToolGroup` is also a header). Present since before U041; Q004 had no such check. Not fixed: which of the two goes is a design choice for a UI Forge. Screenshots: `q005_small-phone_en-US_Today-tools-stacked-headings.png`, `q005_small-phone_tr-TR_Today-tools-stacked-headings.png`, `q005_desktop_tr-TR_Today-tools-stacked-headings.png` (the matrix's own Today shots show the top of the page, not this section, and are not kept).
2. **Derived title broken inside words, TR, 320 dp, 2× text** (found by eye; the script's `title_whole` passes because the box is inside the window). `WrappingTitleBar` wraps "Kayıtlarından hesaplananlar" as "Kayıtlarında / n hesaplan / anlar": a single word is wider than the 232 dp the title gets, so Flutter breaks it mid-word. EN ("Worked out / from your / records") and the Summary title in both languages wrap between words. Not fixed: the remedy (shrinking only a word that cannot fit, a shorter title, or more width) needs a decision, since U041 chose never to shrink these titles. Screenshot: `u041-text-2x_small-phone_tr-TR_Derived.png`.

## Fixed in this Forge

- **App, `Q005 fix:` fc445d0**: Turkish first run said "kilo, tansiyon" and Settings "Ölçümler kilo kartından önce", against U041's one word for body weight (the card is "Vücut ağırlığı", the field "Ağırlık (kg)"). Both now say "ağırlık". Widget test `test/widget/q005_weight_word_test.dart` (EN and TR, first run at 320 dp with 2× text). Before: `before-fix_u041-text-2x_small-phone_tr-TR_First-run-welcome_kilo.png`; after: `u041-text-2x_small-phone_tr-TR_First-run-welcome.png`. Full `flutter test`: 1473 passed; `flutter analyze` clean.
- **Tool** (5deb387, 3f415eb, 782a362, 5a5a70e): first run is opened from Settings ("Show the introduction again"), because a development web build keeps nothing and never offers it at start; its title is read from the live-region heading that also says the step; step 2 is scrolled to the top; a tab reopened from a pushed page is scrolled to the top before its heading is awaited (Derived failed after Summary); reveal stops at the real navigation bar, does not take a box Flutter clipped at the bar as in view, moves a cut target up by what is missing and still brings far targets to a third of the window (clear of a sheet's own Save bar); a target taller than the space counts when its top is in view; a slider is measured by its semantics node (48x48), not the engine's range `<input>` (48x44), which had failed Settings at 48 dp.

## Seen, not a FAIL

- The how-to's title "How to use Human OS" / "Human OS nasıl kullanılır" keeps AppBar's 1.34× cap and a FittedBox, so at 2× text it is drawn at about its 1× size, whole (`u041-text-2x_small-phone_tr-TR_Learn-how-to.png`). U041 lifted the cap only for first run, Summary and Derived.
- No English word on any TR cell; no tap target under 48 dp; no horizontal scroll; no overflow; no number in front of the how-to's six tasks; the Timeline switch is one control that reads its help line; first run, Summary and Derived sit in the centred 840 dp column on the desktop; no scrollbar on screens that fit (desktop Timeline, Summary, Derived, first run), one on Today, which scrolls.
- Screenshots of cells outside U041 were deleted for disk space (their checks remain in `matrix.json`).
