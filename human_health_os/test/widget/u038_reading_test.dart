// U038: airy, understandable reading.
// 1. The machinery of a record (when it was saved, where it came from, the
//    report's other lines) sits behind "Details" / "Ayrıntılar": hidden by
//    default, a button with an expanded state for a screen reader, reached
//    and opened by keyboard.
// 2. The Timeline has a day header before each day's first entry, in plain
//    words ("Today", "Yesterday", a date), on the local day of a timed
//    record and the calendar day of a lab sample date (no time-zone shift).
//    Run in UTC and with TZ=America/New_York.
// 3. Rows show the value as typed, never reformatted.
// 4. Learn's entries are plain rows with a one-line description; the body
//    guide is rows, not a grid of cards.
// 5. Settings: light or dark, palette, colour, text size and language come
//    first; lock, updates and About last.
// 6. 320 dp, 2× text, EN and TR: the changed screens overflow nowhere and
//    cut no text, with every Details open.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/date_style.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'package:human_health_os/src/features/timeline/timeline_screen.dart'
    show dayLabel, recordDayOf;

import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u034_learn_test.dart' show openLearn;
import 'u035_text_fit_test.dart' show cutTexts, mainScroll, sweep;
import 'u039_scroll_anywhere_test.dart' show expectReadingColumn;

LabInput _lab(String value, String date, {String flag = ''}) => LabInput(
  analyte: 'HbA1c',
  value: value,
  notReported: false,
  unit: '%',
  sampleDate: date,
  specimen: 'Kan',
  laboratory: 'Lab A',
  sourceFlag: flag,
  referenceText: '4,0 - 6,0',
  method: 'HPLC',
);

String _iso(DateTime d) => formatDay(d.year, d.month, d.day, DateOrder.iso);

Future<void> _go(WidgetTester tester, DestinationId id) async {
  final rail = find.byKey(const ValueKey('nav-rail'));
  if (rail.evaluate().isNotEmpty) {
    await tester.tap(
      find.descendant(
        of: rail,
        matching: find.byIcon(destinationById(id).icon),
      ),
    );
  } else {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('nav-bar')),
        matching: find.byIcon(destinationById(id).icon),
      ),
    );
  }
  await settle(tester);
}

/// A weight today ("78,40" as typed), a blood pressure yesterday, a weight
/// at 02:00 UTC on 1 October (30 September in New York) and a lab sample
/// dated 1 October (the same day everywhere).
Future<Map<String, HealthRecord>> _seed(AppServices s) async {
  final now = DateTime.now();
  final out = <String, HealthRecord>{};
  await (() async {
    out['today'] = await s.heartbeat.recordWeightKg(
      profileId: s.self.id,
      input: '78,40',
    );
    out['yesterday'] = await s.heartbeat.recordMeasurement(
      profileId: s.self.id,
      kind: RecordKind.bloodPressure,
      input: MeasurementInput(
        systolic: '118',
        diastolic: '76',
        when: _wall(DateTime(now.year, now.month, now.day - 1, 12)),
      ),
    );
    out['utc'] = await s.heartbeat.recordWeightKg(
      profileId: s.self.id,
      input: '81',
      observedAt: DateTime.utc(2026, 10, 1, 2),
    );
    out['lab'] = await s.heartbeat.recordLab(
      profileId: s.self.id,
      input: _lab('5,40', '2026-10-01', flag: 'H'),
    );
    out['lab2'] = await s.heartbeat.recordLab(
      profileId: s.self.id,
      input: _lab('5,9', '2026-05-12'),
    );
  })();
  return out;
}

String _wall(DateTime local) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

Future<Map<String, HealthRecord>> _launchSeeded(
  WidgetTester tester, {
  Locale? locale,
  Size size = const Size(1280, 3200),
  double textScale = 1.0,
}) async {
  final s = await launch(
    tester,
    locale: locale,
    size: size,
    textScale: textScale,
  );
  final out = (await tester.runAsync(() => _seed(s)))!;
  // The screens read the records when they open.
  return out;
}

/// Drags [scroller] up until [f] is built and its centre is on screen,
/// settling after each drag (a lazy list builds rows only near view).
Future<void> _bring(WidgetTester tester, Finder f, Finder scroller) async {
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 0; i < 100; i++) {
    if (f.evaluate().isNotEmpty) {
      final y = tester.getCenter(f).dy;
      if (y > 80 && y < height - 120) return;
    }
    await tester.drag(scroller, const Offset(0, -120));
    await tester.pumpAndSettle();
  }
  fail('not reached: $f');
}

Finder _in(Finder of, Finder what) => find.descendant(of: of, matching: what);

void main() {
  test('day labels: today, yesterday, then the date; a sample date is its '
      'own calendar day; a timed record falls on its local day', () {
    const s = S(AppLang.en);
    final now = DateTime(2026, 11, 24, 9);
    expect(dayLabel(s, DateTime(2026, 11, 24), now), 'Today');
    expect(dayLabel(s, DateTime(2026, 11, 23), now), 'Yesterday');
    expect(dayLabel(s, DateTime(2026, 11, 22), now), '2026-11-22');
    expect(dayLabel(const S(AppLang.tr), DateTime(2026, 11, 23), now), 'Dün');
    // Across a month boundary.
    expect(
      dayLabel(s, DateTime(2026, 11, 30), DateTime(2026, 12, 1, 0, 5)),
      'Yesterday',
    );
    final timed = DateTime.utc(2026, 10, 1, 2);
    expect(_iso(recordDayOf(timed, dateOnly: false)), _iso(timed.toLocal()));
    expect(
      _iso(recordDayOf(DateTime.utc(2026, 10, 1), dateOnly: true)),
      '2026-10-01',
    );
  });

  testWidgets('Timeline: day headers in plain words before each day\'s '
      'first entry, newest first, in this time zone', (tester) async {
    final r = await _launchSeeded(tester);
    await _go(tester, DestinationId.timeline);
    final now = DateTime.now();
    final today = find.byKey(ValueKey('timeline-day-${_iso(now)}'));
    final yesterday = find.byKey(
      ValueKey(
        'timeline-day-${_iso(DateTime(now.year, now.month, now.day - 1))}',
      ),
    );
    expect(_in(today, find.text('Today')), findsOneWidget);
    expect(_in(yesterday, find.text('Yesterday')), findsOneWidget);
    // 02:00 UTC on 1 October is 30 September in New York, 1 October in UTC.
    final localDay = _iso(DateTime.utc(2026, 10, 1, 2).toLocal());
    final timedHeader = find.byKey(ValueKey('timeline-day-$localDay'));
    await tester.scrollUntilVisible(
      timedHeader,
      300,
      scrollable: mainScroll('screen-timeline'),
    );
    expect(_in(timedHeader, find.text(localDay)), findsOneWidget);
    // The lab sample date is 1 October in every zone.
    final labHeader = find.byKey(const ValueKey('timeline-day-2026-10-01'));
    await tester.scrollUntilVisible(
      labHeader,
      300,
      scrollable: mainScroll('screen-timeline'),
    );
    expect(labHeader, findsOneWidget);
    // Headers are headings for a screen reader.
    expect(
      tester.getSemantics(_in(today, find.text('Today'))),
      matchesSemantics(isHeader: true, label: 'Today'),
    );
    // Each header comes before its day's entries.
    double y(Finder f) => tester.getTopLeft(f).dy;
    await tester.scrollUntilVisible(
      today,
      -300,
      scrollable: mainScroll('screen-timeline'),
    );
    expect(
      y(today),
      lessThan(y(find.byKey(ValueKey('timeline-entry-${r['today']!.id}')))),
    );
    expect(
      y(find.byKey(ValueKey('timeline-entry-${r['today']!.id}'))),
      lessThan(y(yesterday)),
    );
    // One header per day: the two days in October are not merged with
    // today's.
    final headers = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('timeline-day-'),
      skipOffstage: false,
    );
    final keys = {
      for (final e in headers.evaluate())
        ((e.widget.key! as ValueKey<String>).value),
    };
    expect(keys.length, headers.evaluate().length);
  });

  testWidgets('Timeline rows: what and the value as typed, then the time; '
      'source and state wait in the record\'s Details', (tester) async {
    final r = await _launchSeeded(tester);
    await _go(tester, DestinationId.timeline);
    final row = find.byKey(ValueKey('timeline-entry-${r['today']!.id}'));
    expect(_in(row, find.text('78.40 kg')), findsOneWidget);
    // Typed decimals are kept ("78,40" is not shortened to 78.4).
    final bp = find.byKey(ValueKey('timeline-entry-${r['yesterday']!.id}'));
    expect(_in(bp, find.text('118/76 mmHg')), findsOneWidget);
    // No machinery on the row.
    expect(_in(row, find.textContaining('Manual entry')), findsNothing);
    expect(_in(row, find.textContaining('Observed')), findsNothing);
    // The sheet: versions first, machinery hidden until Details.
    await tester.tap(row);
    await settle(tester);
    final sheet = find.byKey(const ValueKey('timeline-detail'));
    expect(_in(sheet, find.text('78.40 kg')), findsOneWidget);
    expect(_in(sheet, find.textContaining('Manual entry')), findsNothing);
    final toggle = find.byKey(ValueKey('details-timeline-${r['today']!.id}'));
    expect(toggle, findsOneWidget);
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
        label: 'Details: Body weight',
      ),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      _in(sheet, find.textContaining('Observed · Manual entry')),
      findsOneWidget,
    );
    expect(_in(sheet, find.textContaining('entered ')), findsOneWidget);
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
        label: 'Hide details: Body weight',
      ),
    );
  });

  testWidgets('Labs: the value as printed, the lab\'s flag and range in '
      'view; laboratory, source and report lines behind Details, opened by '
      'keyboard', (tester) async {
    final r = await _launchSeeded(tester);
    await _go(tester, DestinationId.labs);
    final id = r['lab']!.id;
    final row = find.byKey(ValueKey('lab-row-$id'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: mainScroll('screen-labs'),
    );
    expect(_in(row, find.text('5,40 %')), findsOneWidget);
    expect(_in(row, find.text('Lab flag: H')), findsOneWidget);
    expect(
      _in(row, find.text('Lab\'s printed range: 4,0 - 6,0')),
      findsOneWidget,
    );
    expect(_in(row, find.text('Lab A')), findsNothing);
    expect(_in(row, find.text('Manual entry')), findsNothing);
    expect(_in(row, find.text('Method as printed: HPLC')), findsNothing);
    expect(find.byKey(ValueKey('lab-correct-$id')), findsOneWidget);
    // Tab reaches the toggle; Enter opens it.
    final toggle = find.byKey(ValueKey('details-lab-$id'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    var focused = false;
    for (var i = 0; i < 80 && !focused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      focused = Focus.of(tester.element(_in(toggle, find.byType(Row))))
          .hasFocus;
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final open = find.byKey(ValueKey('details-lab-$id-text'));
    expect(_in(open, find.text('Lab A')), findsOneWidget);
    expect(_in(open, find.text('Manual entry')), findsOneWidget);
    expect(_in(open, find.text('Method as printed: HPLC')), findsOneWidget);
    // Same test over time: one plain row, the rule behind Details.
    expect(find.byKey(const ValueKey('labs-group-rule')), findsNothing);
    await tapKey(tester, 'details-labs-groups');
    expect(find.byKey(const ValueKey('labs-group-rule')), findsOneWidget);
  });

  testWidgets('Same test over time: name first, the rule and each result\'s '
      'laboratory behind Details, values as printed', (tester) async {
    final r = await _launchSeeded(tester);
    await _go(tester, DestinationId.labs);
    await tapKey(tester, 'lab-group-${r['lab']!.id}');
    expect(find.byKey(const ValueKey('lab-group-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-group-rule')), findsNothing);
    final row = find.byKey(ValueKey('lab-group-row-${r['lab']!.id}'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: mainScroll('screen-lab-group'),
    );
    expect(_in(row, find.text('5,40 %')), findsOneWidget);
    expect(_in(row, find.text('Laboratory: Lab A')), findsNothing);
    await tapKey(tester, 'details-lab-group-${r['lab']!.id}');
    expect(_in(row, find.textContaining('Lab A')), findsOneWidget);
    await tapKey(tester, 'details-lab-group');
    expect(find.byKey(const ValueKey('lab-group-rule')), findsOneWidget);
  });

  testWidgets('Learn: three plain rows, one line each; the body guide is '
      'rows, not cards', (tester) async {
    await launch(tester, size: const Size(1280, 1600));
    await openLearn(tester);
    for (final key in ['tool-glossary', 'tool-guide', 'tool-howto']) {
      final row = find.byKey(ValueKey(key));
      expect(row, findsOneWidget);
      expect(_in(row, find.byType(Card)), findsNothing);
      final texts = tester.widgetList<Text>(_in(row, find.byType(Text)));
      expect(texts.length, 2, reason: key);
      // The description is one short sentence, a line on a desktop.
      final hint = texts.last.data!;
      expect(hint.length, lessThanOrEqualTo(80), reason: key);
      expect(hint.contains('. '), isFalse, reason: key);
    }
    await tapKey(tester, 'tool-guide');
    expect(find.byType(Card), findsNothing);
    // One centred column of 840 dp in a full-width scroll view (U039).
    expectReadingColumn(tester, 'screen-guide');
  });

  testWidgets('Settings: the most used first, advanced last', (tester) async {
    await launch(tester);
    await tapKey(tester, 'open-settings');
    const s = S(AppLang.en);
    final order = [
      s.settingsTheme,
      s.settingsPalette,
      s.settingsAccent,
      s.settingsTextSize,
      s.settingsLanguage,
      s.settingsInterfaceScale,
      s.settingsFont,
      s.settingsUnits,
      s.lockTitle,
      s.settingsUpdatesTitle,
    ];
    final ys = [for (final t in order) tester.getTopLeft(find.text(t)).dy];
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], greaterThan(ys[i - 1]), reason: order[i]);
    }
    // About is the last row.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('settings-about'))).dy,
      greaterThan(ys.last),
    );
    // The font samples open on demand.
    expect(find.text(s.fontPreviewNote), findsNothing);
    await tapKey(tester, 'details-font-previews');
    expect(find.text(s.fontPreviewNote), findsOneWidget);
  });

  for (final (name, locale) in [
    ('en', const Locale('en', 'US')),
    ('tr', const Locale('tr', 'TR')),
  ]) {
    testWidgets('$name, 320 dp, 2× text: Timeline with its sheet, Labs with '
        'Details open, Same test over time and Learn fit', (tester) async {
      final r = await _launchSeeded(
        tester,
        locale: locale,
        size: const Size(320, 640),
        textScale: 2.0,
      );
      await _go(tester, DestinationId.timeline);
      expect(await sweep(tester, mainScroll('screen-timeline')), isEmpty);
      final row = find.byKey(ValueKey('timeline-entry-${r['today']!.id}'));
      await tester.drag(mainScroll('screen-timeline'), const Offset(0, 20000));
      await tester.pumpAndSettle();
      await _bring(tester, row, mainScroll('screen-timeline'));
      await tester.tap(row);
      await settle(tester);
      await tapKey(tester, 'details-timeline-${r['today']!.id}');
      expect(tester.takeException(), isNull);
      expect(cutTexts(tester), isEmpty);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('timeline-detail'))),
      ).pop();
      await settle(tester);

      await _go(tester, DestinationId.labs);
      Future<void> reach(String key) =>
          _bring(tester, find.byKey(ValueKey(key)), mainScroll('screen-labs'));
      await reach('details-lab-${r['lab']!.id}');
      await tester.ensureVisible(
        find.byKey(ValueKey('details-lab-${r['lab']!.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('details-lab-${r['lab']!.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('details-lab-${r['lab']!.id}-text')),
        findsOneWidget,
      );
      expect(await sweep(tester, mainScroll('screen-labs')), isEmpty);
      await tester.drag(mainScroll('screen-labs'), const Offset(0, 20000));
      await tester.pumpAndSettle();
      await reach('lab-group-${r['lab']!.id}');
      await tester.tap(find.byKey(ValueKey('lab-group-${r['lab']!.id}')));
      await settle(tester);
      await tapKey(tester, 'details-lab-group');
      expect(await sweep(tester, mainScroll('screen-lab-group')), isEmpty);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('screen-lab-group'))),
      ).pop();
      await settle(tester);

      // Learn from the More sheet, scrolled to its row at 2× text.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('nav-bar')),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await tester.pumpAndSettle();
      final learn = find.descendant(
        of: find.byKey(const ValueKey('more-sheet')),
        matching: find.byIcon(Icons.school_outlined),
      );
      await tester.scrollUntilVisible(
        learn,
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('more-sheet')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(learn);
      await tester.pumpAndSettle();
      await tester.tap(learn);
      await settle(tester);
      expect(find.byKey(const ValueKey('screen-learn')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(cutTexts(tester), isEmpty);
    });
  }
}
