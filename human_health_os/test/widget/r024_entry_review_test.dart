// R024 (review of U037):
// 1. Each details toggle names its field for a screen reader:
//    "<show/hide words>: <field label>", in English and Turkish.
// 2. The first run's last line is true in every build: in a development
//    build, before a new vault's passphrase screen, and replayed from
//    Settings ("Later, on Today, …", never "Then …").
// 3. A medicine with no dose today says so without "yet" (nothing is due:
//    the plan may be paused, stopped or as needed).
// 4. "Change the plan" opens a sheet titled "Change the plan".
// 5. The reference-interval toggle explains, so it says "More about this".
// 6. Turkish names strength as "Etken madde miktarı".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f006_vault_gate_test.dart' show Disk;
import 'f007_measurements_test.dart' show launch, tapKey;
import 'u005_settings_test.dart' show launchWith;
import 'u014_first_run_test.dart' show launchReal;
import 'u015_tools_intro_test.dart' show launchGate;
import 'u037_entry_test.dart' show open;

const _en = Locale('en', 'US');
const _tr = Locale('tr', 'TR');

Finder _inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

String _spoken(WidgetTester tester, String key) =>
    tester.getSemantics(find.byKey(ValueKey(key))).getSemanticsData().label;

Future<String> _seed(AppServices s, {PlanState? state}) async {
  final item = await s.heartbeat.addMedication(
    profileId: s.self.id,
    name: 'Vitamin D3',
    category: MedicationCategory.supplement,
  );
  await s.heartbeat.planMedication(
    profileId: s.self.id,
    itemRootId: item.id,
    schedule: '1 capsule every morning',
    source: PlanSource.ownChoice,
  );
  if (state != null) {
    await s.heartbeat.setPlanState(
      profileId: s.self.id,
      itemRootId: item.id,
      state: state,
    );
  }
  return item.id;
}

void main() {
  for (final (locale, lang) in [(_en, AppLang.en), (_tr, AppLang.tr)]) {
    final s = S(lang);
    final code = locale.languageCode;

    testWidgets('$code: every details toggle on the Labs sheet says its '
        'field; the interval toggle says "More about this"', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester, locale: locale);
      await open(tester, DestinationId.labs);
      await tapKey(tester, 'lab-add');
      await tapKey(tester, 'lab-more');
      final fields = {
        'lab-analyte': s.labAnalyte,
        'lab-value': s.labValueLabel(LabValueKind.number),
        'lab-unit': s.labUnit,
      };
      final spoken = <String>{};
      for (final MapEntry(key: id, value: label) in fields.entries) {
        final toggle = '$id-details';
        expect(
          _spoken(tester, toggle),
          s.fieldDetailsFor(s.fieldDetailsShow, label),
          reason: id,
        );
        expect(
          find.bySemanticsLabel(s.fieldDetailsFor(s.fieldDetailsShow, label)),
          findsOneWidget,
          reason: id,
        );
        spoken.add(_spoken(tester, toggle));
        await tapKey(tester, toggle);
        expect(
          _spoken(tester, toggle),
          s.fieldDetailsFor(s.fieldDetailsHide, label),
          reason: id,
        );
        await tapKey(tester, toggle);
      }
      expect(spoken, hasLength(fields.length), reason: 'each one apart');
      // The bare words are never a node of their own.
      expect(find.bySemanticsLabel(s.fieldDetailsShow), findsNothing);

      // The interval toggle opens an explanation, not typing help.
      final interval = find.byKey(const ValueKey('lab-interval-details'));
      await tester.ensureVisible(interval);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: interval, matching: find.text(s.fieldMoreShow)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: interval, matching: find.text(s.fieldDetailsShow)),
        findsNothing,
      );
      expect(
        _spoken(tester, 'lab-interval-details'),
        s.fieldDetailsFor(s.fieldMoreShow, s.labIntervalTitle),
      );
      await tapKey(tester, 'lab-interval-details');
      expect(
        find.byKey(const ValueKey('lab-interval-explain')),
        findsOneWidget,
      );
      expect(
        _spoken(tester, 'lab-interval-details'),
        s.fieldDetailsFor(s.fieldDetailsHide, s.labIntervalTitle),
      );
      handle.dispose();
    });

    testWidgets('$code: "Change the plan" opens a sheet with that title', (
      tester,
    ) async {
      final app = await launch(tester, locale: locale);
      final id = (await tester.runAsync(() => _seed(app)))!;
      await open(tester, DestinationId.medications);
      expect(find.text(s.medsPlanChange), findsOneWidget);
      await tapKey(tester, 'meds-plan-add-$id');
      expect(_inSheet(find.text(s.medsPlanChange)), findsOneWidget);
      expect(_inSheet(find.text(s.medsPlanAdd)), findsNothing);
    });

    testWidgets('$code: with no plan the sheet is "Write the plan"', (
      tester,
    ) async {
      final app = await launch(tester, locale: locale);
      final id = (await tester.runAsync(
        () => app.heartbeat.addMedication(
          profileId: app.self.id,
          name: 'Vitamin D3',
          category: MedicationCategory.supplement,
        ),
      ))!.id;
      await open(tester, DestinationId.medications);
      await tapKey(tester, 'meds-plan-add-$id');
      expect(_inSheet(find.text(s.medsPlanAdd)), findsOneWidget);
      expect(_inSheet(find.text(s.medsPlanChange)), findsNothing);
    });

    testWidgets('$code: a paused item says no dose today, with no "yet"', (
      tester,
    ) async {
      final app = await launch(tester, locale: locale);
      final id = (await tester.runAsync(
        () => _seed(app, state: PlanState.paused),
      ))!;
      await open(tester, DestinationId.medications);
      final text = tester
          .widget<Text>(find.byKey(ValueKey('meds-today-$id')))
          .data!;
      expect(text, s.medsTodayNone);
      expect(
        text,
        lang == AppLang.en ? 'Today: no dose recorded' : 'Bugün: doz kaydı yok',
      );
      expect(text.toLowerCase(), isNot(contains('yet')));
      expect(text.toLowerCase(), isNot(contains('henüz')));
    });
  }

  group('the first run\'s last line is true in every build', () {
    void trueEverywhere(WidgetTester tester, S s) {
      final line = tester
          .widget<Text>(find.byKey(const ValueKey('first-then')))
          .data!;
      expect(line, s.firstThen);
      // Not "then": a vault build asks for a passphrase next, and a replay
      // from Settings returns to Settings.
      expect(line, isNot(startsWith('Then')));
      expect(line, isNot(startsWith('Sonra')));
    }

    test('the words', () {
      expect(
        S(AppLang.en).firstThen,
        'Later, on Today, type a first number, for example your weight, '
        'and press Save.',
      );
      expect(S(AppLang.tr).firstThen, startsWith('Daha sonra Bugün'));
    });

    testWidgets('a development build', (tester) async {
      await launchReal(tester, MemoryAppearanceStore());
      await tapKey(tester, 'first-next');
      trueEverywhere(tester, S(AppLang.en));
      await tapKey(tester, 'first-next');
      expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
    });

    testWidgets('a vault build: the passphrase screen comes next', (
      tester,
    ) async {
      await launchGate(tester, Disk());
      await tapKey(tester, 'first-next');
      trueEverywhere(tester, S(AppLang.en));
      await tapKey(tester, 'first-next');
      expect(find.byKey(const ValueKey('vault-gate-create')), findsOneWidget);
    });

    testWidgets('replayed from Settings: Settings comes back', (tester) async {
      await launchWith(tester);
      await tapKey(tester, 'open-settings');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('set-first-run')),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('screen-settings')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapKey(tester, 'set-first-run');
      await tapKey(tester, 'first-next');
      trueEverywhere(tester, S(AppLang.en));
      await tapKey(tester, 'first-next');
      expect(find.byKey(const ValueKey('screen-settings')), findsOneWidget);
    });
  });

  test(
    'Turkish strength is "Etken madde miktarı", for a label like 500 mg',
    () {
      final tr = S(AppLang.tr);
      expect(tr.medsStrength, 'Etken madde miktarı (isteğe bağlı)');
      expect(tr.medsStrength, isNot(contains('Güç')));
      expect(tr.medsStrengthHelp, contains('500 mg'));
    },
  );
}
