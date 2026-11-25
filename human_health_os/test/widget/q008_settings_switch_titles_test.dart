// Q008 (screen matrix after U044): at 320 dp with 2× text, Settings broke
// the switch title "Measurements before the weight card" inside its first
// word ("Measurement / s"): a SwitchListTile's title was a plain Text, which
// breaks a word wider than the space beside the switch. Every switch title
// and subtitle in Settings now wraps between words only, drawn just small
// enough for an over-long word to fit (D-054, U042).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'f007_measurements_test.dart' show launch, tapKey;
import 'u035_text_fit_test.dart' show mainScroll;
import 'u042_headings_titles_test.dart' show expectWholeWords;

void main() {
  for (final locale in const [Locale('en', 'US'), Locale('tr', 'TR')]) {
    testWidgets('Settings switch titles never break inside a word, '
        '${locale.languageCode}, 320 dp, 2× text', (tester) async {
      await launch(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2.0,
      );
      await tapKey(tester, 'open-settings');
      final scroll = mainScroll('screen-settings');
      final position = tester.state<ScrollableState>(scroll).position;
      final checked = <Key?>{};
      for (var i = 0; i < 400; i++) {
        for (final e in find.byType(SwitchListTile).evaluate()) {
          final tile = e.widget as SwitchListTile;
          for (final part in [tile.title, tile.subtitle]) {
            if (part == null) continue;
            final paragraphs = find
                .descendant(
                  of: find.byWidget(part),
                  matching: find.byType(RichText),
                )
                .evaluate();
            for (final r in paragraphs) {
              expectWholeWords(r.renderObject! as RenderParagraph);
            }
          }
          checked.add(tile.key);
        }
        if (position.pixels >= position.maxScrollExtent) break;
        position.jumpTo(
          (position.pixels + 200).clamp(0.0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      // The appearance, contrast, Today, discovery and lock switches.
      expect(
        checked,
        containsAll(const [
          ValueKey('set-wide-spacing'),
          ValueKey('set-reduce-motion'),
          ValueKey('set-show-aion'),
          ValueKey('set-high-contrast'),
          ValueKey('set-pad-open'),
          ValueKey('set-measurements-first'),
          ValueKey('set-checkins-first'),
          ValueKey('set-discovery'),
          ValueKey('set-lock-hidden'),
        ]),
      );
    });
  }
}
