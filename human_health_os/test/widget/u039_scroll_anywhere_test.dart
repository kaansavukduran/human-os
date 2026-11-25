// U039: on a wide window the page scrolls wherever the pointer is.
// 1. The scroll view of every screen under the reading-width wrapper spans
//    the whole body (its scrollbar at the window edge); the content inside
//    it stays one centred column of 840 dp, padding included.
// 2. At 1440x900 a mouse wheel, a trackpad pan and a drag over the left
//    margin, outside the column, scroll the page: Today, Timeline, Labs, a
//    lab group, each record area, Learn and its pages, Settings and About.
// 3. On a phone the column is the full width, less the page padding.
// 4. 320 dp, 2× text: the changed screens overflow nowhere and cut no text.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/records/record_details.dart';
import 'package:human_health_os/src/navigation/destinations.dart';
import 'package:human_health_os/src/presentation/theme/spacing.dart';

import 'about_helper.dart' show openAbout;
import 'f007_measurements_test.dart' show launch, settle, tapKey;
import 'u034_learn_test.dart' show openLearn;
import 'u035_text_fit_test.dart' show mainScroll, sweep;

const _desktop = Size(1440, 900);

/// Where the content of [scroller] is drawn: the left edge of its leftmost
/// box, the right edge of its rightmost one and the widest box, leaving out
/// the boxes that span the whole scroll view (the viewport, the scrollbar,
/// a full-width padding).
({double left, double right, double width}) contentExtent(
  WidgetTester tester,
  Finder scroller,
) {
  final root = tester.renderObject<RenderBox>(scroller);
  final full = root.size.width;
  var left = double.infinity;
  var right = double.negativeInfinity;
  var width = 0.0;
  void visit(RenderObject o) {
    if (o is RenderBox && o.hasSize && o.size.width < full - 1) {
      final r = o.localToGlobal(Offset.zero) & o.size;
      if (r.width > 0) {
        if (r.left < left) left = r.left;
        if (r.right > right) right = r.right;
        if (r.width > width) width = r.width;
      }
      return; // Its children are inside it.
    }
    o.visitChildren(visit);
  }

  root.visitChildren(visit);
  return (left: left, right: right, width: width);
}

/// The scroll view of [screenKey] fills the body beside the rail (or the
/// window, on a pushed page), and its content is one centred column of
/// [kReadingWidth], [kPagePadding]'s 16 dp at each side included.
void expectReadingColumn(WidgetTester tester, String screenKey) {
  final scroller = mainScroll(screenKey);
  final view = tester.getRect(scroller);
  final window = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(view.right, closeTo(window.width, 0.5), reason: screenKey);
  final column = contentExtent(tester, scroller);
  final expected = view.width >= kReadingWidth
      ? kReadingWidth - 2 * Space.l
      : view.width - 2 * Space.l;
  expect(column.width, closeTo(expected, 0.5), reason: screenKey);
  // Centred, the page padding inside the column.
  final side = (view.width - (expected + 2 * Space.l)) / 2;
  expect(column.left, closeTo(view.left + side + Space.l, 0.5));
  expect(column.right, lessThanOrEqualTo(view.right - side - Space.l + 0.5));
}

/// A wheel, a trackpad pan and a drag over the left margin, halfway
/// between the scroll view's edge and the reading column, each scroll the
/// page.
Future<void> scrollsInMargin(WidgetTester tester, String screenKey) async {
  final scroller = mainScroll(screenKey);
  final element = scroller.evaluate().first;
  final scrollable = find.byElementPredicate((e) => e == element);
  final view = tester.getRect(scrollable);
  final side = (view.width - kReadingWidth) / 2;
  expect(side, greaterThan(100), reason: screenKey);
  final at = Offset(view.left + side / 2, view.center.dy);
  // Outside the column: no content under the pointer.
  final column = contentExtent(tester, scrollable);
  expect(at.dx, lessThan(column.left - Space.l), reason: screenKey);
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(position.maxScrollExtent, greaterThan(0), reason: screenKey);

  Future<void> top() async {
    position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  await top();
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, 240)));
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0), reason: '$screenKey: wheel');
  // A wheel turned back goes back.
  final down = position.pixels;
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
  await tester.pumpAndSettle();
  expect(position.pixels, lessThan(down), reason: '$screenKey: wheel up');

  await top();
  final pad = TestPointer(2, PointerDeviceKind.trackpad);
  await tester.sendEventToBinding(pad.panZoomStart(at));
  for (var i = 1; i <= 4; i++) {
    await tester.sendEventToBinding(
      pad.panZoomUpdate(at, pan: Offset(0, -60.0 * i)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.sendEventToBinding(pad.panZoomEnd());
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0), reason: '$screenKey: trackpad');

  await top();
  await tester.dragFrom(at, const Offset(0, -240));
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0), reason: '$screenKey: drag');
  await top();
}

Future<void> _open(WidgetTester tester, DestinationId id) async {
  final rail = find.byKey(const ValueKey('nav-rail'));
  final primary = find.descendant(
    of: rail,
    matching: find.byIcon(destinationById(id).icon),
  );
  if (primary.evaluate().isNotEmpty) {
    await tester.tap(primary.first);
  } else {
    final item = find.byKey(ValueKey('rail-planned-${id.name}'));
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
  }
  await settle(tester);
}

/// Enough of every kind that each screen is longer than the window.
Future<void> _seed(AppServices s) async {
  final me = s.self.id;
  final h = s.heartbeat;
  String day(int i) => '2026-0${1 + i % 9}-1${i % 9}';
  for (var i = 0; i < 14; i++) {
    await h.recordWeightKg(profileId: me, input: '${70 + i}');
    await h.recordLab(
      profileId: me,
      input: LabInput(
        analyte: 'HbA1c',
        value: '5,$i',
        notReported: false,
        unit: '%',
        sampleDate: day(i),
        specimen: 'Kan',
        laboratory: 'Lab A',
        sourceFlag: '',
        referenceText: '4,0 - 6,0',
        method: 'HPLC',
      ),
    );
    await h.addMedication(
      profileId: me,
      name: 'Medicine $i',
      category: MedicationCategory.medicine,
    );
    await h.recordFood(profileId: me, what: 'Soup $i');
    await h.recordActivity(profileId: me, what: 'Walk $i', minutes: '30');
    await h.recordCondition(
      profileId: me,
      name: 'Condition $i',
      nature: ConditionType.condition,
      time: ConditionTime.current,
      source: ConditionSource.selfReported,
    );
    await h.recordPreventive(
      profileId: me,
      name: 'Check-up $i',
      nature: PreventiveType.checkup,
      status: PreventiveStatus.done,
      source: ConditionSource.selfReported,
    );
    await h.recordDocument(
      profileId: me,
      title: 'Letter $i',
      nature: DocumentType.letter,
    );
  }
}

Future<void> _launchSeeded(WidgetTester tester) async {
  final s = await launch(tester, size: _desktop);
  await tester.runAsync(() => _seed(s));
}

const _areas = [
  (DestinationId.timeline, 'screen-timeline'),
  (DestinationId.labs, 'screen-labs'),
  (DestinationId.medications, 'screen-medications'),
  (DestinationId.nutrition, 'screen-nutrition'),
  (DestinationId.activity, 'screen-activity'),
  (DestinationId.conditions, 'screen-conditions'),
  (DestinationId.preventive, 'screen-preventive'),
  (DestinationId.documents, 'screen-documents'),
];

/// [key]'s column is 840 dp; a page longer than the window scrolls from
/// the left margin, and on a short one (Learn's three rows, About) the margin is
/// still part of its scroll view.
Future<void> _check(WidgetTester tester, String key, {bool? long}) async {
  expect(find.byKey(ValueKey(key)), findsOneWidget);
  expectReadingColumn(tester, key);
  if (long ?? true) {
    await scrollsInMargin(tester, key);
    return;
  }
  final view = tester.getRect(mainScroll(key));
  final at = Offset(
    view.left + (view.width - kReadingWidth) / 4,
    view.center.dy,
  );
  final hit = HitTestResult();
  WidgetsBinding.instance.hitTestInView(hit, at, tester.view.viewId);
  // The scroll view's own gesture detector takes the pointer there.
  final scroller = tester.renderObject(mainScroll(key));
  expect(
    hit.path.any((e) => e.target == scroller),
    isTrue,
    reason: '$key: the margin is part of the scroll view',
  );
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await settle(tester);
}

void main() {
  testWidgets('1440x900: Today, Timeline, Labs, every record area and '
      'Learn scroll from the left margin; the column stays 840 dp', (
    tester,
  ) async {
    await _launchSeeded(tester);
    await settle(tester);
    await _check(tester, 'screen-today');
    for (final (id, key) in _areas) {
      await _open(tester, id);
      await _check(tester, key);
    }
    await _open(tester, DestinationId.learn);
    await _check(tester, 'screen-learn', long: _long(tester, 'screen-learn'));
  });

  testWidgets('1440x900: a lab group and Settings scroll from the left '
      'margin, About takes it; the column stays 840 dp', (tester) async {
    await _launchSeeded(tester);
    await _open(tester, DestinationId.labs);
    final group = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          RegExp(r'^lab-group-(?!name|rule|row)')
              .hasMatch((w.key! as ValueKey<String>).value),
    );
    await tester.scrollUntilVisible(
      group.first,
      300,
      scrollable: mainScroll('screen-labs'),
    );
    await tapKey(
      tester,
      (tester.widget(group.first).key! as ValueKey<String>).value,
    );
    await settle(tester);
    await _check(tester, 'screen-lab-group');
    await _back(tester);
    await tapKey(tester, 'open-settings');
    await _check(tester, 'screen-settings');
    await _back(tester);
    await openAbout(tester);
    // About fits a 900 dp window: its margin is still its scroll view's.
    await _check(tester, 'screen-about', long: _long(tester, 'screen-about'));
  });

  testWidgets('1440x900: the glossary, a glossary entry, the body guide, '
      'a body system and How to keep the 840 dp column; each that is longer '
      'than the window scrolls from the left margin', (tester) async {
    await launch(tester, size: _desktop);
    await openLearn(tester);
    Future<void> page(String key, {required bool long}) =>
        _check(tester, key, long: long);

    await tapKey(tester, 'tool-glossary');
    await settle(tester);
    await page('screen-glossary', long: true);
    final entry = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          RegExp(r'^glossary-(?!search|none|unit)')
              .hasMatch((w.key! as ValueKey<String>).value),
    );
    final first = (tester.widget(entry.first).key! as ValueKey<String>).value;
    await tapKey(tester, first);
    await settle(tester);
    final entryKey = 'screen-$first';
    await page(entryKey, long: _long(tester, entryKey));
    await _back(tester);
    await _back(tester);
    await tapKey(tester, 'tool-guide');
    await settle(tester);
    await page('screen-guide', long: _long(tester, 'screen-guide'));
    final system = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('guide-system-'),
    );
    final sys = (tester.widget(system.first).key! as ValueKey<String>).value;
    await tapKey(tester, sys);
    await settle(tester);
    final sysKey = 'screen-guide-${sys.replaceFirst('guide-system-', '')}';
    await page(sysKey, long: _long(tester, sysKey));
    await _back(tester);
    await _back(tester);
    await tapKey(tester, 'tool-howto');
    await settle(tester);
    await page('screen-howto', long: _long(tester, 'screen-howto'));
  });

  testWidgets('phone, 390 dp: the column is the full width, less the page '
      'padding', (tester) async {
    await launch(tester, size: const Size(390, 844));
    expectReadingColumn(tester, 'screen-today');
    await tapKey(tester, 'open-settings');
    expectReadingColumn(tester, 'screen-settings');
  });

  testWidgets('320 dp, 2× text: Today, Settings and About overflow '
      'nowhere and cut no text', (tester) async {
    await launch(tester, size: const Size(320, 640), textScale: 2.0);
    expect(await sweep(tester, mainScroll('screen-today')), isEmpty);
    await tapKey(tester, 'open-settings');
    expect(await sweep(tester, mainScroll('screen-settings')), isEmpty);
    await _back(tester);
    await openAbout(tester);
    expect(await sweep(tester, mainScroll('screen-about')), isEmpty);
  });
}

bool _long(WidgetTester tester, String key) =>
    tester.state<ScrollableState>(mainScroll(key)).position.maxScrollExtent > 0;
