// Q007 (screen matrix after U043): the Documents and Preventive add sheets
// cut their field names with an ellipsis ("Title, in your wo…" at 2× text,
// "Başlık, kendi sözlerinle (ör. kan t…" in Turkish at 1×). As every
// other labelled field (WholeLabelField), the name is drawn whole: inside
// the field when it fits, above it otherwise.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;

Future<void> _launch(
  WidgetTester tester, {
  required Locale locale,
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, report: report);
  });
  final c = AppearanceController(
    MemoryAppearanceStore(),
    const AppearanceSettings(),
  );
  await tester.pumpWidget(HumanOsApp(services: s!, appearance: c));
  await settle(tester);
}

/// Opens [area] from the bottom bar's More sheet.
Future<void> _openFromMore(WidgetTester tester, String area) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('nav-bar')),
      matching: find.byIcon(Icons.more_horiz),
    ),
  );
  await tester.pumpAndSettle();
  final tile = find.descendant(
    of: find.byKey(const ValueKey('more-sheet')),
    matching: find.text(area),
  );
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('more-sheet')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await settle(tester);
}

/// Scrolls the area's lazy list to its add button and taps it.
Future<void> _tapAdd(WidgetTester tester, String screen, String key) async {
  final add = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    add,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(ValueKey('screen-$screen')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tapKey(tester, key);
}

/// Scrolls to each field of [keys] in turn; every name of [names] is drawn
/// at least once on the way, and no paragraph showing a name is cut.
Future<void> _eachField(
  WidgetTester tester,
  List<String> keys,
  List<String> names,
  String where,
) async {
  final seen = <String>{};
  for (final k in keys) {
    await tester.ensureVisible(find.byKey(ValueKey(k)));
    await tester.pumpAndSettle();
    for (final n in names) {
      if (find.text(n).evaluate().isEmpty) continue;
      seen.add(n);
      _expectWhole(tester, n, '$where, $k');
    }
  }
  expect(seen, names.toSet(), reason: '$where: names drawn');
}

/// No paragraph showing [n] is cut.
void _expectWhole(WidgetTester tester, String n, String reason) {
  {
    final f = find.text(n);
    for (final e in f.evaluate()) {
      final p = e.renderObject;
      if (p is! RenderParagraph) continue;
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: '$reason: "$n" cut (${p.size.width.round()} dp wide)',
      );
    }
  }
}

void main() {
  for (final (locale, scale) in [
    (const Locale('tr', 'TR'), 1.0),
    (const Locale('en', 'US'), 2.0),
    (const Locale('tr', 'TR'), 2.0),
  ]) {
    final tr = locale.languageCode == 'tr';
    final s = S(tr ? AppLang.tr : AppLang.en);
    final where = '${locale.languageCode} at 320 dp, $scale× text';

    testWidgets('Documents: every field name is whole, $where', (tester) async {
      await _launch(tester, locale: locale, textScale: scale);
      await _openFromMore(tester, s.docTitle);
      await _tapAdd(tester, 'documents', 'doc-add');
      final names = [s.docTitleField, s.docDate, s.docIssuer, s.docWhere];
      await _eachField(
        tester,
        ['doc-title', 'doc-date', 'doc-issuer', 'doc-where'],
        names,
        where,
      );
      // Each field still carries its name for a screen reader.
      for (final n in names) {
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(n))), findsWidgets);
      }
    });

    testWidgets('Preventive: every field name is whole, $where', (
      tester,
    ) async {
      await _launch(tester, locale: locale, textScale: scale);
      await _openFromMore(tester, tr ? 'Koruyucu' : 'Preventive');
      await _tapAdd(tester, 'preventive', 'prev-add');
      final names = [s.prevName, s.prevWhen];
      await _eachField(tester, ['prev-name', 'prev-when'], names, where);
      for (final n in names) {
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(n))), findsWidgets);
      }
    });
  }
}
