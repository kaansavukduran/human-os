// Q008 (screen matrix after U044): at 320 dp with 2× text, the Timeline
// correction of a finger-prick glucose cut the help line under "When it
// was measured" after three lines ("… Change it only if the r…"): its
// fields allowed at most 3 helper lines. No text in the correction sheet
// is cut, in English or Turkish.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u035_text_fit_test.dart' show mainScroll;

void main() {
  for (final locale in const [Locale('en', 'US'), Locale('tr', 'TR')]) {
    testWidgets('Timeline correction of a glucose: no text cut, '
        '${locale.languageCode}, 320 dp, 2× text', (tester) async {
      final s = await launch(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2.0,
      );
      final rec = (await tester.runAsync(
        () => s.heartbeat.recordMeasurement(
          profileId: s.self.id,
          kind: RecordKind.capillaryGlucose,
          input: const MeasurementInput(value: '6', unit: 'mmol/L'),
        ),
      ))!;
      tester
          .widget<DestinationSwitch>(find.byType(DestinationSwitch).first)
          .go(DestinationId.timeline);
      await settle(tester);
      final entry = find.byKey(ValueKey('timeline-entry-${rec.id}'));
      await tester.scrollUntilVisible(
        entry,
        200,
        scrollable: mainScroll('screen-timeline'),
      );
      await tapKey(tester, 'timeline-entry-${rec.id}');
      await tapKey(tester, 'action-correct-${rec.id}');

      final sheet = find.byType(BottomSheet).last;
      final scroll = find
          .descendant(of: sheet, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      var seenWhenHelp = false;
      for (var i = 0; i < 200; i++) {
        for (final e
            in find
                .descendant(of: sheet, matching: find.byType(RichText))
                .evaluate()) {
          final p = e.renderObject! as RenderParagraph;
          final text = p.text.toPlainText();
          if (text.startsWith('YYYY-')) seenWhenHelp = true;
          expect(p.didExceedMaxLines, isFalse, reason: '"$text" is cut');
        }
        if (position.pixels >= position.maxScrollExtent) break;
        position.jumpTo(
          (position.pixels + 150).clamp(0.0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
      }
      expect(seenWhenHelp, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
