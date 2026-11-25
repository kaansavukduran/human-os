// U044 (docs/DESIGN.md "U044"), findings 1 and 2 of the Q007 review:
// 1. No add or edit sheet puts a heading straight under its title (the
//    Medications sheet had "From the pack" under "Add a medicine or
//    supplement", the Labs sheet "The result" under its title): between
//    two headings there is always something else.
// 2. Every text field's name is whole: never cut with an ellipsis, never
//    broken inside a word, and it stays the field's screen-reader name.
//    Swept over every add and edit sheet, Today's weight field, the
//    Timeline correction, Settings, the glossary search and the vault
//    gate, in EN and TR at 320 dp with 1× and 2× text and on a desktop.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/guide/glossary_screen.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';
import 'package:human_health_os/src/presentation/widgets/whole_label_field.dart';

import 'f006_vault_gate_test.dart' as gate;
import 'f007_measurements_test.dart'
    show launch, settle, showAllMeasurements, tapKey;
import 'u035_text_fit_test.dart' show mainScroll;
import 'u042_headings_titles_test.dart' show expectWholeWords;

const _locales = [Locale('en', 'US'), Locale('tr', 'TR')];

const _windows = [
  ('320 dp, 1×', Size(320, 640), 1.0),
  ('320 dp, 2×', Size(320, 640), 2.0),
  ('desktop', Size(1440, 900), 1.0),
];

Finder _the(Element e) =>
    find.byElementPredicate((x) => x == e, skipOffstage: false);

/// The labels a screen reader hears on [node] and the nodes inside it.
String _heard(SemanticsNode node) {
  final out = <String>[];
  void down(SemanticsNode n) {
    out.add(n.getSemanticsData().label);
    n.visitChildren((c) {
      down(c);
      return true;
    });
  }

  down(node);
  return out.join(' | ');
}

bool _isIcon(Element e) =>
    e.widget is RichText &&
    (e.widget as RichText).text.style?.fontFamily == 'MaterialIcons';

/// Every text field built (on screen or scrolled away) shows its name
/// whole: its own floating label, or the label [WholeLabelField] draws
/// above it. The name is never ellipsized, never broken inside a word, lies
/// inside its box, and is the field's screen-reader name. Returns the names.
List<String> expectWholeFieldNames(
  WidgetTester tester,
  String where, {
  Finder? within,
}) {
  final names = <String>[];
  final fields = find.byType(TextField, skipOffstage: false);
  for (final e
      in (within == null
              ? fields
              : find.descendant(of: within, matching: fields))
          .evaluate()) {
    final field = e.widget as TextField;
    final own = field.decoration?.labelText;
    final whole = find.ancestor(
      of: _the(e),
      matching: find.byType(WholeLabelField, skipOffstage: false),
    );
    final name =
        own ??
        (whole.evaluate().isEmpty
            ? null
            : tester.widget<WholeLabelField>(whole.first).label);
    expect(name, isNotNull, reason: '$where: a field ${field.key} has no name');
    final scope = own != null ? _the(e) : whole.first;
    final shown = [
      for (final r
          in find
              .descendant(
                of: scope,
                matching: find.byType(RichText, skipOffstage: false),
                skipOffstage: false,
              )
              .evaluate())
        if ((r.renderObject! as RenderParagraph).text.toPlainText() == name)
          r.renderObject! as RenderParagraph,
    ];
    expect(shown, isNotEmpty, reason: '$where: "$name" is not drawn');
    for (final p in shown) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: '$where: "$name" cut (${p.size.width.round()} dp wide)',
      );
      expect(
        p.textSize.width,
        lessThanOrEqualTo(p.size.width + 0.5),
        reason: '$where: "$name" wider than its box',
      );
      expectWholeWords(p);
    }
    expect(
      _heard(tester.getSemantics(_the(e))),
      contains(name),
      reason: '$where: "$name" is not the field\'s screen-reader name',
    );
    names.add(name!);
  }
  return names;
}

/// Between any two headings inside [root] (semantics headers, one under
/// the other) something else is drawn: no heading stands on a heading.
void expectNoStackedHeadings(WidgetTester tester, Finder root, String where) {
  final heads = find
      .descendant(
        of: root,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true,
        ),
      )
      .evaluate()
      .toList();
  bool inHeading(Element e) => heads.any(
    (h) =>
        find.descendant(of: _the(h), matching: _the(e)).evaluate().isNotEmpty,
  );
  final content = [
    for (final e
        in find
            .descendant(of: root, matching: find.byType(RichText))
            .evaluate())
      if (!_isIcon(e) &&
          (e.widget as RichText).text.toPlainText().trim().isNotEmpty &&
          !inHeading(e))
        tester.getRect(_the(e)),
    for (final e
        in find
            .descendant(
              of: root,
              matching: find.byWidgetPredicate(
                (w) => w is TextField || w is WholeChip,
              ),
            )
            .evaluate())
      tester.getRect(_the(e)),
  ];
  final rects = [for (final h in heads) (h, tester.getRect(_the(h)))]
    ..sort((a, b) => a.$2.top.compareTo(b.$2.top));
  for (var i = 0; i + 1 < rects.length; i++) {
    final (ha, a) = rects[i];
    final (hb, b) = rects[i + 1];
    if (b.top < a.bottom - 0.5) continue; // side by side
    final between = content.any(
      (c) => c.top >= a.bottom - 0.5 && c.bottom <= b.top + 0.5,
    );
    String said(Element h) => [
      for (final r
          in find
              .descendant(of: _the(h), matching: find.byType(RichText))
              .evaluate())
        (r.widget as RichText).text.toPlainText(),
    ].join(' ');
    expect(
      between,
      isTrue,
      reason: '$where: heading "${said(hb)}" stands right under "${said(ha)}"',
    );
  }
}

Finder get _sheet => find.byType(BottomSheet).last;

/// Checks the open sheet, then closes it.
Future<List<String>> _checkSheet(WidgetTester tester, String where) async {
  final semantics = tester.ensureSemantics();
  expectNoStackedHeadings(tester, _sheet, where);
  final names = expectWholeFieldNames(tester, where, within: _sheet);
  expect(tester.takeException(), isNull, reason: where);
  semantics.dispose();
  Navigator.of(tester.element(_sheet)).pop();
  await settle(tester);
  return names;
}

Future<void> _open(WidgetTester tester, DestinationId id) async {
  tester.widget<DestinationSwitch>(find.byType(DestinationSwitch).first).go(id);
  await settle(tester);
}

/// Taps [key] on [screen], scrolling its list from the top to it first
/// (a measurement tile may sit under "More measurements").
Future<void> _tapOn(WidgetTester tester, String screen, String key) async {
  final f = find.byKey(ValueKey(key));
  final scroll = mainScroll(screen);
  Future<void> toTop() async {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  await toTop();
  if (f.evaluate().isEmpty && key.startsWith('measure-tile-')) {
    final more = find.byKey(const ValueKey('measurements-more'));
    await tester.scrollUntilVisible(more, 200, scrollable: scroll);
    await showAllMeasurements(tester);
    await toTop();
  }
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: scroll);
  }
  await tapKey(tester, key);
}

/// Scrolls the vault gate's list to [key].
Future<void> _gateScrollTo(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      100,
      // The gate's list, not a text field's own (sideways) scroller.
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
}

/// Taps [key] on the vault gate, scrolling its list to it first.
Future<void> _gateTap(WidgetTester tester, String key) async {
  await _gateScrollTo(tester, key);
  await tapKey(tester, key);
}

Future<AppServices> _launch(
  WidgetTester tester,
  Locale locale,
  Size size,
  double scale,
) => launch(tester, locale: locale, size: size, textScale: scale);

void main() {
  for (final locale in _locales) {
    for (final (window, size, scale) in _windows) {
      final label = '${locale.languageCode}, $window';

      testWidgets('every add and edit sheet: one heading at a time, field '
          'names whole, $label', (tester) async {
        final s = await _launch(tester, locale, size, scale);
        final seeded = (await tester.runAsync(() async {
          final item = await s.heartbeat.addMedication(
            profileId: s.self.id,
            name: 'Vitamin D3',
            category: MedicationCategory.supplement,
          );
          final w = await s.heartbeat.recordWeightKg(
            profileId: s.self.id,
            input: '72.4',
            observedAt: DateTime.now().subtract(const Duration(days: 1)),
          );
          return (item.id, w.id);
        }))!;
        final (item, weight) = seeded;
        final checked = <String>[];

        // Today: its own fields, then each sheet.
        await _open(tester, DestinationId.today);
        final semantics = tester.ensureSemantics();
        expectWholeFieldNames(tester, '$label, Today');
        semantics.dispose();
        for (final key in [
          'sleep-add',
          'feel-open',
          'measure-tile-${RecordKind.bloodPressure.code}',
          'measure-tile-${RecordKind.capillaryGlucose.code}',
          'measure-tile-${RecordKind.waistCircumference.code}',
        ]) {
          await _open(tester, DestinationId.today);
          await _tapOn(tester, 'screen-today', key);
          checked.addAll(await _checkSheet(tester, '$label, $key'));
        }

        for (final (id, add) in [
          (DestinationId.labs, 'lab-add'),
          (DestinationId.medications, 'meds-add'),
          (DestinationId.medications, 'meds-plan-add-$item'),
          (DestinationId.medications, 'meds-dose-$item'),
          (DestinationId.nutrition, 'food-add'),
          (DestinationId.activity, 'act-add'),
          (DestinationId.conditions, 'cond-add'),
          (DestinationId.preventive, 'prev-add'),
          (DestinationId.documents, 'doc-add'),
        ]) {
          await _open(tester, id);
          await _tapOn(tester, 'screen-${id.name}', add);
          checked.addAll(await _checkSheet(tester, '$label, $add'));
        }

        // The Timeline correction of the saved weight.
        await _open(tester, DestinationId.timeline);
        await _tapOn(tester, 'screen-timeline', 'timeline-entry-$weight');
        await tapKey(tester, 'action-correct-$weight');
        checked.addAll(await _checkSheet(tester, '$label, correction'));

        // Settings (the exact interface size) and the glossary search.
        await tapKey(tester, 'open-settings');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-interface-input')),
          200,
          scrollable: mainScroll('screen-settings'),
        );
        await tester.pumpAndSettle();
        final s2 = tester.ensureSemantics();
        checked.addAll(expectWholeFieldNames(tester, '$label, Settings'));
        s2.dispose();
        Navigator.of(
          tester.element(find.byKey(const ValueKey('screen-settings'))),
        ).pop();
        await settle(tester);
        Navigator.of(
          tester.element(find.byType(Scaffold).first),
        ).push(MaterialPageRoute<void>(builder: (_) => const GlossaryScreen()));
        await settle(tester);
        final s3 = tester.ensureSemantics();
        checked.addAll(expectWholeFieldNames(tester, '$label, glossary'));
        s3.dispose();

        // Some sheets were checked with fields in them.
        expect(checked.length, greaterThanOrEqualTo(30));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the vault gate: field names whole, $label', (tester) async {
        final disk = gate.Disk();
        // Create a vault on a tall window, then open the gate again at the
        // size under test.
        await gate.launch(tester, disk);
        await gate.createThroughGate(tester);
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.platformDispatcher.localesTestValue = [locale];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final g = await tester.runAsync(() => gate.gateOn(disk));
        await tester.pumpWidget(HumanOsApp(gate: g));
        await settle(tester);
        final names = <String>{};
        // The gate's list builds only what is in view: checked from top to
        // bottom.
        Future<void> check(String step) async {
          final list = find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .first;
          final position = tester.state<ScrollableState>(list).position;
          position.jumpTo(0);
          await tester.pumpAndSettle();
          for (var i = 0; i < 40; i++) {
            final semantics = tester.ensureSemantics();
            names.addAll(expectWholeFieldNames(tester, '$label, $step'));
            semantics.dispose();
            if (position.pixels >= position.maxScrollExtent) break;
            position.jumpTo(
              (position.pixels + 200).clamp(0, position.maxScrollExtent),
            );
            await tester.pumpAndSettle();
          }
          position.jumpTo(0);
          await tester.pumpAndSettle();
        }

        expect(find.byKey(const ValueKey('vault-gate-unlock')), findsOneWidget);
        await check('unlock');
        await _gateTap(tester, 'gate-use-recovery');
        await check('recover');
        // Passphrase; recovery key, new passphrase, repeated.
        expect(names.length, greaterThanOrEqualTo(4));

        // A new vault: its passphrase and the recovery key's two groups.
        await tester.pumpWidget(const SizedBox());
        final fresh = gate.Disk();
        final g2 = await tester.runAsync(() => gate.gateOn(fresh));
        await tester.pumpWidget(HumanOsApp(gate: g2));
        await settle(tester);
        await check('create');
        for (final k in ['gate-passphrase', 'gate-passphrase-confirm']) {
          await _gateScrollTo(tester, k);
          await gate.type(tester, k, gate.pass);
        }
        await _gateTap(tester, 'gate-continue');
        await _gateTap(tester, 'gate-key-written');
        await check('confirm the recovery key');
        // And the repeated passphrase and the two key groups.
        expect(names.length, greaterThanOrEqualTo(7), reason: '$names');
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('every labelled field in lib/ takes its label from WholeLabelField', () {
    // `labelText:` is only ever the builder's own argument: a field never
    // names itself with a label Material would cut.
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i].trim();
        if (l.startsWith('//')) continue;
        if (l.contains('labelText:') && !l.startsWith('labelText: labelText')) {
          found.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(found, isEmpty);
  });
}
