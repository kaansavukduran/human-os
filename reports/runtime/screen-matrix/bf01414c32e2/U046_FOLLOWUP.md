# U046 follow-up: screen matrix after the review follow-ups

These are the review follow-ups to U046 (`../a6778060f00c/U046_REVIEW.md`, approved with follow-ups). The commits are 7cf0484 (app and tests) and bf01414 (matrix tool).

1. **Derived "Technical details" / "Teknik ayrıntılar"**: on this Flutter, `ExpansionTile` exposed neither a button flag nor an expanded state. The header is now one `Semantics(button: true, expanded: open)` node over an `InkWell`, following the disclosure pattern of `FieldDetails` (`sheet_parts.dart`). Its text is excluded, so the name is read once. Test: group 1b of `test/widget/u046_open_points_test.dart` (EN and TR). The group asserts `isButton`, `hasExpandedState`, `isExpanded` false, then true, then false again, plus the tap and focus actions and the label, and that the IDs are hidden while it is closed. On the old code (the `ExpansionTile`) both languages fail with "missing flags: isButton,hasExpandedState".
2. **The USDA button on TR Plant chemicals**: the English label is one constant, `usdaCsvButton` in `lib/src/l10n/strings.dart`, quoted verbatim in both languages. The TR text adds a gloss: `"Download these results as: CSV" (Bu sonuçları CSV olarak indir) düğmesini seç`. Test 3c checks the constant, the EN quote and the TR quote with its gloss. The tool has one exact exception: on screen `Plant chemicals`, in `tr-TR`, the substring `"Download these results as: CSV"` (quotes included) is removed before the English-word check (reason: "foreign site UI label, glossed"). Any other English in that label, or the same words without the quotes or on another screen, still fails. Other quoted text is not excepted.
3. **`text_scaled_2x` on paragraphs** (Genetics intro, Plant chemicals intro, the palette note in "Settings: theme under palette"): the tool now measures height per line. It cuts the paragraph's box from a screenshot and counts its lines as runs of ink rows. Runs lower than 40 % of the tallest, such as an i's dot, are not counted as lines. The cell is marked NOT TESTED if the box is not wholly in the window. Text scaled 1.3× that only wraps onto more lines now gives about 1.3 per line, not about 1.7 overall, so it cannot pass the 1.6 threshold. The single-line probes (Derived ID, "Heart", "unknown") were not changed.
4. **`machine_id_whole`** now also requires that the ID is read without word joiners: a node named exactly `DERIVED-BMI-1` (`getByLabel`), or reading exactly that as its text. In this build the semantics label reaches the page as text: 1 by text, 0 by name in every Derived cell. The visible text keeps its joiners, so it alone would not match.

## Run

The run used fresh development web builds of bf01414 on a clean tree (`working_tree_dirty: false`): `--release` and `--debug`, `APP_ENV=development`, `--no-web-resources-cdn`, `SOURCE_REVISION=bf01414`, no `APP_VERSION`. Browser: Chromium 153, with a new empty cache directory. main.dart.js sha256 hashes: release `b4c82783…`, debug `e6026a28…`. Builds and cache were deleted after the run. Selection: `MATRIX_ONLY='^u046'`, the same 6 screens × 6 groups as before.

| | Cells | PASS | FAIL |
|---|---|---|---|
| Script (`matrix.md`) | 36 | 36 | 0 |
| By eye (only the cells looked at) | 5 | 5 | 0 |

Per check (36 cells):

| Check | Result |
|---|---|
| heading_visible, controls_named, no_page_errors, no_console_errors, no_failed_requests, no_horizontal_scroll, no_flutter_overflow, no_flutter_exceptions, no_stacked_headings, not_cut_at_list_end | 36 PASS each |
| theme_applied | 30 PASS (6 not applicable: the palette cell) |
| touch_targets | 24 PASS (12 not applicable: desktop) |
| **no_english_on_tr** | **18 PASS** (was 15 PASS, 3 FAIL). The 3 Plant chemicals cells name the exception in their detail |
| text_scaled_2x | 12 PASS |
| title_whole, reading_column | 12 PASS each |
| derived_plain_titles, **machine_id_whole**, parts_not_buttons, version_localised, theme_note_shown | 6 PASS each |

What `text_scaled_2x` measured on the paragraphs (1× → 2×, height per line):

| Paragraph | 1× | 2× | Ratio |
|---|---|---|---|
| Genetics intro, EN and TR | 3 lines, 25.4 px | 5 lines, 49.3 px | ×1.94 |
| Plant chemicals intro, EN | 5 lines, 21.2 px | 9 lines, 38.0 px | ×1.79 |
| Plant chemicals intro, TR | 6 lines, 21.2 px | 10 lines, 38.0 px | ×1.79 |
| Palette note, EN | 3 lines, 21.2 px | 6 lines, 41.1 px | ×1.94 |
| Palette note, TR | 3 lines, 21.2 px | 7 lines, 41.1 px | ×1.94 |

Plant chemicals stays below ×2 because `WholeWordText` draws the whole intro slightly smaller so that "phytochem.nal.usda.gov" stays whole (see below). The single-line probes: Derived ID ×1.94, "Heart" ×1.80, "unknown" ×1.94.

## By eye

I looked at 5 cells; their screenshots are kept here and the rest were deleted for disk space. Line counts were compared against the tool's counts where shown.

- **TR Plant chemicals, 320 dp, 1×**: the intro reads `… sonra "Download these results as: CSV" (Bu sonuçları CSV olarak indir) düğmesini seç. …`. The gloss sits directly after the quote, and the address is whole. 6 lines, as the tool counted.
- **TR Plant chemicals, 2×**: the same text on 10 lines (tool: 10), with "phytochem.nal.usda.gov" whole on the first line. The quote breaks between words ("results / as: CSV"), never inside one.
- **TR Settings with Matrix, 2×**: the note under "Açık veya koyu" is on 7 lines (tool: 7) and wraps between words.
- **EN Genetics, 2×**: the intro is on 5 lines (tool: 5).
- **TR Derived, 2×**: "Teknik ayrıntılar" is opened with a "less" chevron at the right edge. Under it, "Formül kimliği, sürüm 1" and "DERIVED-BMI-1" are each whole on their own lines. As before, the opened header keeps a light highlight after the tap (Material's hover or focus overlay).

All 5 PASS. The other 31 cells have only the script's verdict.

## Noted, not changed

- **`WholeWordText` shrinks the whole paragraph**, not only the long word (the U042 rule). In the plant-chemicals intro, the whole intro is drawn smaller so the address stays whole: per-line height ×1.79 at 2×, not ×1.94. In About ("This build"), a value wider than its half of the row ("GELİŞTİRME" at 2× TR) is drawn smaller than the other values in the list.
- **The body guide's parts are separate text nodes.** A screen reader hears each part as its own text, with the bullet not read. There is no list role, and the number of items is not announced.
- **Two unknown models would share the fallback title**: "A worked-out number" / "Hesaplanan bir sayı". Only the ID under "Technical details" would tell them apart. Today the core pack has two known models, each with its own name.

## Not reached

The same limits as `../a6778060f00c/U046_REVIEW.md` apply:

- **Pages with data**: Genetics and Plant chemicals with a loaded file, and Derived with numbers.
- **Other palettes**: only Matrix was run for the note.
- **The rest of the matrix**: not re-run.
- **Other platforms**: no real devices, other browsers, screen readers or native desktop apps.

The expanded state on the web was not read back by the tool: the cell opens the header only when `aria-expanded` is not `true`, and does not record the attribute. The widget test asserts the semantics flags.

## Checks on the code

At bf01414: `dart format` (0 changed), `flutter analyze` (no issues), `TZ=UTC flutter test`: 1634 passed, 1 skipped, 0 failed (was 1631: group 1b EN and TR, test 3c).
