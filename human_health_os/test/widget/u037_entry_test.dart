// U037: airy, understandable entry.
// 1. Each entry sheet (Labs, a measurement, Medications add / plan / dose,
//    Conditions) has one primary action, Save, and a quiet Cancel.
// 2. Optional fields say "optional" / "isteğe bağlı" in their label;
//    required ones do not.
// 3. Helper text is one short line; the longer explanation opens behind
//    "What to type here" / "Ne yazılır?".
// 4. A refused save says the error in plain words next to its field and
//    moves focus there (FieldFocus).
// 5. At 320 dp and 2× text, in English and Turkish, the changed sheets, the
//    Medications list and the first run cut no text and nothing overflows.
// 6. Medications: a plan alone is never a dose taken; "I took it" / "I
//    skipped it" only open the dose sheet, nothing is recorded until Save.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f004_labs_test.dart' show interpretive, judged;
import 'f007_measurements_test.dart'
    show fill, launch, openSheet, settle, tapKey;
import 'u014_first_run_test.dart' show launchReal;
import 'u035_text_fit_test.dart' show cutTexts, mainScroll, sweep;

const _en = Locale('en', 'US');
const _tr = Locale('tr', 'TR');
const _small = Size(320, 640);

/// Opens an area at any window size (a rail or a bottom bar).
Future<void> open(WidgetTester tester, DestinationId id) async {
  tester.widget<DestinationSwitch>(find.byType(DestinationSwitch).first).go(id);
  await settle(tester);
  expect(find.byKey(ValueKey('screen-${id.name}')), findsOneWidget);
}

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

InputDecoration _decoration(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).decoration!;

/// The field's name: its own label, or the whole label drawn above it.
String _label(WidgetTester tester, String key) =>
    _decoration(tester, key).labelText ??
    tester.getSemantics(find.byKey(ValueKey(key))).getSemanticsData().label;

/// Adds "Vitamin D3" (and, when [plan], a plan) through the service.
Future<String> _seedItem(AppServices s, {bool plan = true}) async {
  final item = await s.heartbeat.addMedication(
    profileId: s.self.id,
    name: 'Vitamin D3',
    category: MedicationCategory.supplement,
  );
  if (plan) {
    await s.heartbeat.planMedication(
      profileId: s.self.id,
      itemRootId: item.id,
      schedule: '1 capsule every morning',
      source: PlanSource.ownChoice,
    );
  }
  return item.id;
}

Future<String> _medsWithItem(
  WidgetTester tester,
  AppServices s, {
  bool plan = true,
}) async {
  final id = (await tester.runAsync(() => _seedItem(s, plan: plan)))!;
  await open(tester, DestinationId.medications);
  return id;
}

/// The sheet's scrolling column.
Finder _sheetScroll() => _inSheet(
  find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  ),
).first;

/// Like [sweep], for a sheet that may fit without scrolling.
Future<Set<String>> _sweepSheet(WidgetTester tester) async {
  final scroller = _sheetScroll();
  final position = tester.state<ScrollableState>(scroller).position;
  if (position.maxScrollExtent <= 0) {
    expect(tester.takeException(), isNull);
    return cutTexts(tester);
  }
  return sweep(tester, scroller);
}

/// Taps a record area's Add action, scrolling the lazy list to it first.
Future<void> _add(WidgetTester tester, String key, String screen) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    200,
    scrollable: mainScroll(screen),
  );
  await tapKey(tester, key);
}

/// Every sheet U037 changed, opened on a fresh screen, by its Save key.
final _sheets = <String, Future<void> Function(WidgetTester, AppServices)>{
  'lab-save': (tester, s) async {
    await open(tester, DestinationId.labs);
    await _add(tester, 'lab-add', 'screen-labs');
  },
  'measure-save': (tester, s) => _add(
    tester,
    'measure-tile-${RecordKind.bloodPressure.code}',
    'screen-today',
  ),
  'meds-item-save': (tester, s) async {
    await open(tester, DestinationId.medications);
    await _add(tester, 'meds-add', 'screen-medications');
  },
  'meds-plan-save': (tester, s) async {
    final id = await _medsWithItem(tester, s);
    await _add(tester, 'meds-plan-add-$id', 'screen-medications');
  },
  'meds-dose-save': (tester, s) async {
    final id = await _medsWithItem(tester, s);
    await _add(tester, 'meds-dose-$id', 'screen-medications');
  },
  'cond-save': (tester, s) async {
    await open(tester, DestinationId.conditions);
    await _add(tester, 'cond-add', 'screen-conditions');
  },
};

const _cancelOf = {
  'lab-save': 'lab-cancel',
  'measure-save': 'measure-cancel',
  'meds-item-save': 'meds-cancel',
  'meds-plan-save': 'meds-cancel',
  'meds-dose-save': 'meds-cancel',
  'cond-save': 'cond-cancel',
};

void main() {
  group('one primary action per sheet', () {
    for (final MapEntry(key: save, value: openIt) in _sheets.entries) {
      testWidgets('$save: Save is the one filled button; Cancel is quiet', (
        tester,
      ) async {
        final s = await launch(tester, size: const Size(390, 844));
        await openIt(tester, s);
        final filled = _inSheet(find.byType(FilledButton));
        expect(filled, findsOneWidget);
        expect(tester.widget<FilledButton>(filled).key, ValueKey(save));
        expect(
          tester.widget(find.byKey(ValueKey(_cancelOf[save]!))),
          isA<TextButton>(),
        );
        expect(_inSheet(find.byType(OutlinedButton)), findsNothing);
      });
    }
  });

  group('optional fields are marked; helper text is one short line', () {
    for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
      final s = S(lang);
      final optional = lang == AppLang.en ? '(optional)' : '(isteğe bağlı)';
      final code = locale.languageCode;

      /// Every helper in the open sheet: one line, one sentence at most.
      void shortHelpers(WidgetTester tester) {
        for (final f in _inSheet(find.byType(TextField)).evaluate()) {
          final helper = (f.widget as TextField).decoration?.helperText;
          if (helper == null) continue;
          expect(helper.length, lessThanOrEqualTo(56), reason: helper);
          // One sentence: no full stop inside ("e.g." / "ör." aside).
          final plain = helper.replaceAll(
            RegExp(r'(e\.g\.|ör\.) ', caseSensitive: false),
            '',
          );
          expect(plain.contains('. '), isFalse, reason: helper);
        }
      }

      testWidgets('$code: the Labs sheet', (tester) async {
        await launch(tester, locale: locale);
        await open(tester, DestinationId.labs);
        await tapKey(tester, 'lab-add');
        for (final k in [
          'lab-unit',
          'lab-specimen',
          'lab-laboratory',
          'lab-flag',
          'lab-range',
        ]) {
          expect(_label(tester, k), contains(optional), reason: k);
        }
        for (final k in ['lab-analyte', 'lab-value', 'lab-date']) {
          expect(_label(tester, k), isNot(contains(optional)), reason: k);
        }
        await tapKey(tester, 'lab-more');
        shortHelpers(tester);
        // The details are behind the toggle, and read once opened.
        for (final (id, text) in [
          ('lab-analyte', s.labAnalyteDetails),
          ('lab-value', s.labValueDetails(LabValueKind.number)),
          ('lab-unit', s.labUnitDetails),
        ]) {
          expect(find.text(text), findsNothing, reason: id);
          final toggle = find.byKey(ValueKey('$id-details'));
          expect(find.text(s.fieldDetailsShow), findsWidgets);
          expect(
            tester
                .getSemantics(toggle)
                .flagsCollection
                .isExpanded
                .toBoolOrNull(),
            isFalse,
          );
          await tapKey(tester, '$id-details');
          expect(find.byKey(ValueKey('$id-details-text')), findsOneWidget);
          expect(find.text(text), findsOneWidget, reason: id);
          expect(
            tester
                .getSemantics(toggle)
                .flagsCollection
                .isExpanded
                .toBoolOrNull(),
            isTrue,
          );
          await tapKey(tester, '$id-details');
          expect(find.text(text), findsNothing, reason: id);
        }
        // Sections are small labels, not paragraphs.
        expect(find.text(s.labSectionAlso), findsOneWidget);
      });

      testWidgets('$code: the Medications sheets', (tester) async {
        final app = await launch(tester, locale: locale);
        final id = await _medsWithItem(tester, app);
        await tapKey(tester, 'meds-add');
        for (final k in ['meds-strength', 'meds-form', 'meds-ingredients']) {
          expect(_label(tester, k), contains(optional), reason: k);
        }
        expect(_label(tester, 'meds-name'), isNot(contains(optional)));
        expect(find.text(s.medsSectionMore), findsOneWidget);
        shortHelpers(tester);
        await tapKey(tester, 'meds-cancel');
        await tapKey(tester, 'meds-plan-add-$id');
        expect(_label(tester, 'meds-schedule'), isNot(contains(optional)));
        shortHelpers(tester);
        await tapKey(tester, 'meds-cancel');
        await tapKey(tester, 'meds-dose-$id');
        for (final k in ['meds-amount', 'meds-when']) {
          expect(_label(tester, k), contains(optional), reason: k);
        }
        shortHelpers(tester);
      });

      testWidgets('$code: the Conditions sheet and a measurement', (
        tester,
      ) async {
        await launch(tester, locale: locale);
        await open(tester, DestinationId.conditions);
        await tapKey(tester, 'cond-add');
        expect(_label(tester, 'cond-since'), contains(optional));
        expect(_label(tester, 'cond-name'), isNot(contains(optional)));
        // Plain questions over the choices.
        expect(find.text(s.condAskNature), findsOneWidget);
        expect(find.text(s.condAskTime), findsOneWidget);
        expect(find.text(s.condAskSource), findsOneWidget);
        shortHelpers(tester);
        await tapKey(tester, 'cond-cancel');
        await open(tester, DestinationId.today);
        await openSheet(tester, RecordKind.bloodPressure);
        // The first thing under the title is a field, not two links.
        final title = tester.getRect(
          _inSheet(find.text(s.recordKind(RecordKind.bloodPressure))),
        );
        final trend = tester.getRect(
          find.byKey(const ValueKey('measure-trend')),
        );
        expect(trend.top, lessThan(title.bottom));
        expect(
          tester.widget(find.byKey(const ValueKey('measure-trend'))),
          isA<IconButton>(),
        );
        // "I did not measure this" comes after the numbers.
        expect(
          tester
              .getRect(find.byKey(const ValueKey('measure-not-measured')))
              .top,
          greaterThan(
            tester.getRect(find.byKey(const ValueKey('measure-diastolic'))).top,
          ),
        );
        await tapKey(tester, 'measure-more');
        expect(_label(tester, 'measure-context'), contains(optional));
        expect(_label(tester, 'measure-when'), contains(optional));
        shortHelpers(tester);
      });
    }
  });

  group('errors are said next to their field, which takes focus', () {
    testWidgets('Labs: a value that is not a number', (tester) async {
      await launch(tester);
      await open(tester, DestinationId.labs);
      await tapKey(tester, 'lab-add');
      await fill(tester, 'lab-analyte', 'HbA1c');
      await fill(tester, 'lab-value', '-');
      await tester.tap(find.byKey(const ValueKey('lab-analyte')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'lab-save');
      final error = find.byKey(const ValueKey('lab-error'));
      expect(error, findsOneWidget);
      expect(tester.widget<Text>(error).data, isNotEmpty);
      // Between the value field and the unit field.
      final top = tester.getRect(error).top;
      expect(
        top,
        greaterThan(
          tester.getRect(find.byKey(const ValueKey('lab-value'))).bottom,
        ),
      );
      expect(
        top,
        lessThan(tester.getRect(find.byKey(const ValueKey('lab-unit'))).top),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('lab-value')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('Conditions: a name left empty', (tester) async {
      await launch(tester);
      await open(tester, DestinationId.conditions);
      await tapKey(tester, 'cond-add');
      await tapKey(tester, 'cond-save');
      final name = tester.widget<TextField>(
        find.byKey(const ValueKey('cond-name')),
      );
      expect(name.decoration!.errorText, isNotNull);
      expect(name.focusNode!.hasFocus, isTrue);
    });

    testWidgets('Medications: a dose time that cannot be read', (tester) async {
      final app = await launch(tester);
      final id = await _medsWithItem(tester, app);
      await tapKey(tester, 'meds-dose-$id');
      await fill(tester, 'meds-when', 'tomorrow-ish');
      await tester.tap(find.byKey(const ValueKey('meds-amount')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'meds-dose-save');
      final when = tester.widget<TextField>(
        find.byKey(const ValueKey('meds-when')),
      );
      expect(when.decoration!.errorText, isNotNull);
      expect(when.focusNode!.hasFocus, isTrue);
      final saved = await tester.runAsync(
        () => app.heartbeat.medications(app.self.id),
      );
      expect(saved!.single.doses, isEmpty, reason: 'nothing written');
    });
  });

  group('320 dp, 2× text: nothing cut, nothing overflows', () {
    for (final locale in [_en, _tr]) {
      final code = locale.languageCode;
      for (final MapEntry(key: save, value: openIt) in _sheets.entries) {
        if (save == 'lab-save') continue; // q003 sweeps the Labs sheet.
        testWidgets('$code: the sheet of $save', (tester) async {
          final s = await launch(
            tester,
            locale: locale,
            size: _small,
            textScale: 2.0,
          );
          await openIt(tester, s);
          final cut = await _sweepSheet(tester);
          expect(cut, isEmpty, reason: '$code $save cut: $cut');
        });
      }

      testWidgets('$code: the Medications list with a plan and a dose', (
        tester,
      ) async {
        final s = await launch(
          tester,
          locale: locale,
          size: _small,
          textScale: 2.0,
        );
        await tester.runAsync(() async {
          final id = await _seedItem(s);
          await s.heartbeat.recordDose(
            profileId: s.self.id,
            itemRootId: id,
            status: IntakeStatus.taken,
            amount: '1 capsule',
          );
        });
        await open(tester, DestinationId.medications);
        final cut = await sweep(tester, mainScroll('screen-medications'));
        expect(cut, isEmpty, reason: '$code Medications cut: $cut');
      });

      testWidgets('$code: both first-run steps', (tester) async {
        final store = MemoryAppearanceStore();
        tester.platformDispatcher.localesTestValue = [locale];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await launchReal(tester, store);
        tester.view.physicalSize = _small;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        for (var step = 0; step < 2; step++) {
          final cut = await sweep(tester, mainScroll('screen-first-run'));
          expect(cut, isEmpty, reason: '$code first run $step cut: $cut');
          if (step == 0) await tapKey(tester, 'first-next');
        }
      });
    }
  });

  group('Medications: planned ≠ taken, reminder ≠ completion', () {
    testWidgets('a plan alone is no dose; "I skipped it" records nothing '
        'until Save; each dose is counted from dose records only', (
      tester,
    ) async {
      final en = S(AppLang.en);
      final app = await launch(tester);
      final id = await _medsWithItem(tester, app);
      String textOf(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(textOf('meds-today-$id'), en.medsTodayNone);
      expect(textOf('meds-counts-$id'), en.medsNoDoses);
      expect(
        textOf('meds-plan-$id'),
        'Plan (active): 1 capsule every morning (My own choice)',
      );
      // Today and its actions come before the plan.
      expect(
        tester.getRect(find.byKey(ValueKey('meds-dose-$id'))).top,
        lessThan(tester.getRect(find.byKey(ValueKey('meds-plan-$id'))).top),
      );
      expect(find.text(en.medsPlanChange), findsOneWidget);

      Future<int> doses() async =>
          (await tester.runAsync(() => app.heartbeat.medications(app.self.id)))!
              .single
              .doses
              .length;

      // "I skipped it" opens the sheet with Skipped chosen; Cancel writes
      // nothing.
      await tapKey(tester, 'meds-skip-$id');
      expect(
        tester
            .widget<WholeChip>(
              find.byKey(const ValueKey('meds-status-skipped')),
            )
            .selected,
        isTrue,
      );
      await tapKey(tester, 'meds-cancel');
      expect(await doses(), 0);
      expect(textOf('meds-today-$id'), en.medsTodayNone);

      // Save records it.
      await tapKey(tester, 'meds-skip-$id');
      await tapKey(tester, 'meds-dose-save');
      expect(await doses(), 1);
      expect(textOf('meds-today-$id'), en.medsToday(0, 1));
      expect(textOf('meds-counts-$id'), en.medsDoseCounts(0, 1));

      // "I took it" opens it with Taken chosen.
      await tapKey(tester, 'meds-dose-$id');
      expect(
        tester
            .widget<WholeChip>(find.byKey(const ValueKey('meds-status-taken')))
            .selected,
        isTrue,
      );
      await tapKey(tester, 'meds-dose-save');
      expect(textOf('meds-today-$id'), en.medsToday(1, 1));
      expect(textOf('meds-counts-$id'), en.medsDoseCounts(1, 1));
    });

    test('the new words judge nothing and give no advice', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        for (final w in [
          s.medsTookIt,
          s.medsSkippedIt,
          s.medsToday(1, 0),
          s.medsTodayNone,
          s.medsPlanChange,
          s.medsDoseStatusLabel,
          s.medsPlanScheduleHelp,
          s.medsStrengthHelp,
          s.medsFormHelp,
          s.medsDoseAmountHelp,
          s.medsDoseWhenHelp,
          s.medsSectionMore,
          s.labSectionAlso,
          s.labAnalyteHelp,
          s.labAnalyteDetails,
          s.labUnitHelp,
          s.labUnitDetails,
          s.labIntervalShort,
          for (final k in LabValueKind.values) s.labValueHelp(k),
          s.condAskNature,
          s.condAskTime,
          s.condAskSource,
          s.condSinceHelp,
          s.contextHelp,
          s.fieldDetailsShow,
          s.fieldDetailsHide,
          s.firstThen,
        ]) {
          expect(interpretive.hasMatch(w), isFalse, reason: w);
          expect(judged.hasMatch(w), isFalse, reason: w);
        }
        // These name the printed form ("above", "a limit"); they judge no
        // value.
        for (final k in LabValueKind.values) {
          final w = s.labValueDetails(k);
          expect(interpretive.hasMatch(w), isFalse, reason: w);
        }
      }
    });
  });
}
