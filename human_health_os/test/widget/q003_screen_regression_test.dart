// Q003: regression tests for screens changed in U032..F005-S3 (About, Learn,
// record-area scaffold, lab groups, text fit, app lock, import).
// - Every new post-A001 surface meets the tap-target, label and text-contrast
//   guidelines at phone size in English and Turkish.
// - At 320x640 with 2× text (EN and TR), About, Learn (and its entries),
//   LabGroup and the F005-S3 import flow + preview dialog fit without
//   overflow or clipped labels.
// - Standalone section headings on About, Labs ("Same test over time") and
//   LabGroup ("Every result, newest first") are not merged with their cards
//   or surrounding content.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/l10n/strings.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'a001_guidelines_test.dart'
    show launchAt, meetsAll, meetsAllScrolled, open;
import 'about_helper.dart' show openAbout;
import 'f005s2_web_restore_test.dart' show FakePicker;
import 'f005s3_dev_import_test.dart' as imp;
import 'f006_vault_gate_test.dart' show Disk, createThroughGate, pass, tapKey;
import 'f007_measurements_test.dart' as meas;
import 'u034_learn_test.dart' show revealOnLearn;
import 'u035_text_fit_test.dart' show cutTexts, mainScroll, sweep;

const _small = Size(320, 640);

/// Opens Learn on any viewport, scrolling the lazy More sheet if needed.
Future<void> _openLearnSmall(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('nav-bar')),
      matching: find.byIcon(Icons.more_horiz),
    ),
  );
  await tester.pumpAndSettle();
  final sheetScroll = find
      .descendant(
        of: find.byKey(const ValueKey('more-sheet')),
        matching: find.byType(Scrollable),
      )
      .first;
  final tile = find.descendant(
    of: find.byKey(const ValueKey('more-sheet')),
    matching: find.byIcon(Icons.school_outlined),
  );
  await tester.scrollUntilVisible(tile, 200, scrollable: sheetScroll);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('screen-learn')), findsOneWidget);
}

/// Completes the encrypted vault creation gate on a 320x640 2× text viewport
/// where fields sit below the fold inside a lazy ListView.
Future<void> _createThroughGateSmall(WidgetTester tester) async {
  Finder verticalScroll() => find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;

  Future<void> revealInGate(String key) async {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: verticalScroll());
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  await revealInGate('gate-passphrase');
  await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
  await revealInGate('gate-passphrase-confirm');
  await tester.enterText(
    find.byKey(const ValueKey('gate-passphrase-confirm')),
    pass,
  );
  await revealInGate('gate-continue');
  await tapKey(tester, 'gate-continue');
  await revealInGate('gate-recovery-key');
  final w = tester.widget(find.byKey(const ValueKey('gate-recovery-key')));
  final key = w is Text ? w.data! : (w as SelectableText).data!;
  await revealInGate('gate-key-written');
  await tapKey(tester, 'gate-key-written');
  final groups = key.split('-');
  for (var n = 1; n <= groups.length; n++) {
    final f = find.byKey(ValueKey('gate-confirm-group-$n'));
    if (f.evaluate().isEmpty) {
      try {
        await tester.scrollUntilVisible(
          f,
          150,
          scrollable: verticalScroll(),
          maxScrolls: 15,
        );
      } catch (_) {}
    }
    if (f.evaluate().isNotEmpty) {
      await tester.ensureVisible(f);
      await tester.enterText(f, groups[n - 1]);
    }
  }
  await tester.pump();
  await revealInGate('gate-create-vault');
  await tapKey(tester, 'gate-create-vault');
}

/// Seeds two HbA1c results so Labs shows "Same test over time".
Future<HealthRecord> _seedTwoLabs(HeartbeatService svc, String me) async {
  await svc.recordLab(
    profileId: me,
    input: const LabInput(
      analyte: 'HbA1c',
      value: '5,4',
      notReported: false,
      unit: '%',
      sampleDate: '2025-01-10',
      specimen: 'Kan',
      laboratory: 'Lab A',
      sourceFlag: '',
      referenceText: '4,0 - 6,0',
    ),
  );
  return svc.recordLab(
    profileId: me,
    input: const LabInput(
      analyte: 'HbA1c',
      value: '5,6',
      notReported: false,
      unit: '%',
      sampleDate: '2026-10-03',
      specimen: 'Kan',
      laboratory: 'Lab B',
      sourceFlag: '',
      referenceText: '4,0 - 6,0',
    ),
  );
}

void main() {
  for (final (locale, lang) in const [
    (Locale('en', 'US'), AppLang.en),
    (Locale('tr', 'TR'), AppLang.tr),
  ]) {
    final s = S(lang);
    final code = locale.languageCode;

    testWidgets('$code: Learn at 390x844 meets the tap-target, label and '
        'text-contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await launchAt(tester, locale: locale);
      await open(tester, DestinationId.learn);
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-learn')),
      );
      handle.dispose();
    });

    testWidgets('$code: Settings → About at 390x844 meets the tap-target, '
        'label and text-contrast guidelines and exposes standalone section '
        'headings', (tester) async {
      final handle = tester.ensureSemantics();
      await launchAt(tester, locale: locale);
      await openAbout(tester);
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-about')),
      );
      tester
          .state<ScrollableState>(mainScroll('screen-about'))
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      // Each section title is its own header semantics node, not merged into
      // the card's body rows.
      for (final title in [s.thisBuild, s.capabilities]) {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          scrollable: mainScroll('screen-about'),
        );
        final node = tester.getSemantics(find.text(title));
        expect(node.label, title, reason: '$code About heading "$title"');
        expect(node.flagsCollection.isHeader, isTrue);
      }
      handle.dispose();
    });

    testWidgets('$code, 320x640, 2× text: About cuts no label and nothing '
        'overflows', (tester) async {
      await meas.launch(tester, locale: locale, size: _small, textScale: 2.0);
      await openAbout(tester);
      expect(cutTexts(tester), isEmpty);
      final cut = await sweep(tester, mainScroll('screen-about'));
      expect(cut, isEmpty, reason: '$code About cut: $cut');
    });

    testWidgets('$code, 320x640, 2× text: Learn and its entries cut no '
        'label and nothing overflows', (tester) async {
      await meas.launch(tester, locale: locale, size: _small, textScale: 2.0);
      await _openLearnSmall(tester);
      final cutLearn = await sweep(tester, mainScroll('screen-learn'));
      expect(cutLearn, isEmpty, reason: '$code Learn cut: $cutLearn');
      final subCuts = <String, Set<String>>{};
      for (final (rowKey, screenKey) in const [
        ('tool-glossary', 'screen-glossary'),
        ('tool-guide', 'screen-guide'),
        ('tool-howto', 'screen-howto'),
      ]) {
        await revealOnLearn(tester, rowKey);
        await tapKey(tester, rowKey);
        expect(find.byKey(ValueKey(screenKey)), findsOneWidget);
        final c = cutTexts(tester);
        if (c.isNotEmpty) subCuts[screenKey] = c;
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
      }
      expect(subCuts, isEmpty, reason: '$code Learn entries cut: $subCuts');
    });

    testWidgets('$code: Lab groups on Labs and LabGroupScreen meet the '
        'accessibility guidelines at 390x844', (tester) async {
      final handle = tester.ensureSemantics();
      final services = await meas.launch(
        tester,
        locale: locale,
        size: const Size(390, 844),
      );
      final newest = (await tester.runAsync(
        () => _seedTwoLabs(services.heartbeat, services.self.id),
      ))!;
      await open(tester, DestinationId.labs);
      await meetsAllScrolled(tester, find.byKey(const ValueKey('screen-labs')));
      tester
          .state<ScrollableState>(mainScroll('screen-labs'))
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(s.labGroupsTitle),
        200,
        scrollable: mainScroll('screen-labs'),
      );
      final groupHeading = tester.getSemantics(find.text(s.labGroupsTitle));
      expect(groupHeading.label, s.labGroupsTitle);
      expect(groupHeading.flagsCollection.isHeader, isTrue);

      final btn = find.byKey(ValueKey('lab-group-${newest.id}'));
      await tester.scrollUntilVisible(
        btn,
        200,
        scrollable: mainScroll('screen-labs'),
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-lab-group')), findsOneWidget);
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-lab-group')),
      );
      tester
          .state<ScrollableState>(mainScroll('screen-lab-group'))
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(s.labGroupEvery),
        200,
        scrollable: mainScroll('screen-lab-group'),
      );
      final everyHeading = tester.getSemantics(find.text(s.labGroupEvery));
      expect(everyHeading.label, s.labGroupEvery);
      expect(everyHeading.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('$code, 320x640, 2× text: LabGroupScreen cuts no label and '
        'nothing overflows', (tester) async {
      final services = await meas.launch(
        tester,
        locale: locale,
        size: _small,
        textScale: 2.0,
      );
      final newest = (await tester.runAsync(
        () => _seedTwoLabs(services.heartbeat, services.self.id),
      ))!;
      await open(tester, DestinationId.labs);
      final btn = find.byKey(ValueKey('lab-group-${newest.id}'));
      await tester.scrollUntilVisible(
        btn,
        200,
        scrollable: mainScroll('screen-labs'),
      );
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-lab-group')), findsOneWidget);
      final cut = await sweep(tester, mainScroll('screen-lab-group'));
      expect(cut, isEmpty, reason: '$code LabGroup cut: $cut');
    });

    testWidgets('$code, 320x640, 2× text: Labs add sheet (including More '
        'from the report) cuts no field label and nothing overflows', (
      tester,
    ) async {
      await meas.launch(tester, locale: locale, size: _small, textScale: 2.0);
      await open(tester, DestinationId.labs);
      final addBtn = find.byKey(const ValueKey('lab-add'));
      await tester.scrollUntilVisible(
        addBtn,
        200,
        scrollable: mainScroll('screen-labs'),
      );
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lab-form')), findsOneWidget);
      final sheetScroll = find
          .descendant(
            of: find.byKey(const ValueKey('lab-form')),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      final more = find.byKey(const ValueKey('lab-more'));
      await tester.scrollUntilVisible(more, 200, scrollable: sheetScroll);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      tester.state<ScrollableState>(sheetScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      final cut = await sweep(tester, sheetScroll);
      expect(cut, isEmpty, reason: '$code LabSheet cut: $cut');
    });

    testWidgets('$code, 320x640, 2× text: F005-S3 import entry and preview '
        'dialog fit without overflow and confirmation is reachable', (
      tester,
    ) async {
      final bundle = (await tester.runAsync(imp.devBackup))!;
      final disk = Disk();
      await imp.launch(
        tester,
        disk,
        FakePicker(bundle),
        locale: locale,
        size: _small,
        textScale: 2.0,
      );
      await _createThroughGateSmall(tester);
      expect(tester.takeException(), isNull);
      await imp.reveal(tester, 'import-development');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'import-development');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('import-preview')), findsOneWidget);
      final dialogScroll = find
          .descendant(
            of: find.byKey(const ValueKey('import-preview')),
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('import-understand')),
        120,
        scrollable: dialogScroll,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('import-understand')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boxCenter = tester.getCenter(
        find.byKey(const ValueKey('import-understand')),
      );
      expect(
        boxCenter.dy,
        lessThan(_small.height),
        reason: '$code import-understand must be on screen at 320x640 2× text',
      );
      await tester.tap(find.byKey(const ValueKey('import-understand')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final confirmBtn = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('confirm-import')),
      );
      expect(confirmBtn.enabled, isTrue);
      final confirmCenter = tester.getCenter(
        find.byKey(const ValueKey('confirm-import')),
      );
      expect(confirmCenter.dy, lessThan(_small.height));
      await tester.tap(find.byKey(const ValueKey('confirm-import')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('import-preview')), findsNothing);
    });

    testWidgets('$code: F005-S3 import preview dialog meets the guidelines '
        'at 390x844', (tester) async {
      final handle = tester.ensureSemantics();
      final bundle = (await tester.runAsync(imp.devBackup))!;
      final disk = Disk();
      await imp.launch(
        tester,
        disk,
        FakePicker(bundle),
        locale: locale,
        size: const Size(390, 844),
      );
      await createThroughGate(tester);
      await imp.reveal(tester, 'import-development');
      await tapKey(tester, 'import-development');
      expect(find.byKey(const ValueKey('import-preview')), findsOneWidget);
      await meetsAll(tester);
      await tapKey(tester, 'cancel-import');
      handle.dispose();
    });
  }
}
