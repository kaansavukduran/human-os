// Real-device/desktop integration: real event loop, real file IO.
// Run: xvfb-run flutter test integration_test -d linux
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/app_services.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/config/app_config.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/crypto/vault_crypto.dart';
import 'package:human_health_os/src/data/local/encrypted_vault.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/storage_io.dart';
import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/features/today/backup_file_picker.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/navigation/app_shell.dart';
import 'package:integration_test/integration_test.dart';

const dev = AppConfig(
  profile: BuildProfile.development,
  version: 'it',
  sourceRevision: 'it',
);
const prod = AppConfig(
  profile: BuildProfile.production,
  version: 'it',
  sourceRevision: 'it',
);

/// Pumps real frames until [finder] shows up: key derivation runs in a
/// real isolate here, so settling the UI alone does not wait for it.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final shown = [
        for (final e in find.byType(Text).evaluate())
          (e.widget as Text).data ?? '',
      ];
      throw StateError('timed out waiting for $finder; on screen: $shown');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pump();
}

/// Today is a lazy list: scroll until the measurements card is built.
Future<void> revealMeasurements(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('measurements-card')),
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('screen-today')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> fillKey(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pump();
}

/// English for every launch: the app starts in Turkish when the device
/// language is neither Turkish nor English (U022), and the build host has
/// no language set.
AppearanceController english() => AppearanceController(
  MemoryAppearanceStore(),
  const AppearanceSettings(language: LanguageChoice.en),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('save weight → relaunch on the same file vault → same record', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-');
    final vault = File('${dir.path}/$vaultFileName');
    Future<void> launch() async {
      final repo = LogRepository(
        sink: FileLogSink(vault),
        durability: StorageDurability.localFile,
        location: vault.path,
      );
      await repo.open();
      final services = await servicesFor(dev, detectHostPlatform(), repo);
      await tester.pumpWidget(
        HumanOsApp(services: services, appearance: english()),
      );
      await tester.pumpAndSettle();
    }

    await launch();
    expect(find.byKey(const ValueKey('weight-empty')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('weight-input')), '77,9');
    await tester.tap(find.byKey(const ValueKey('weight-save')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('77.9 kg'), findsWidgets);
    expect(vault.readAsStringSync(), contains('"original_text":"77,9"'));

    await tester.pumpWidget(const SizedBox());
    await launch(); // fresh repository + fresh widget tree on the same file
    expect(find.byKey(const ValueKey('weight-latest')), findsOneWidget);
    expect(find.text('77.9 kg'), findsWidgets);

    // Moving the vault folder keeps the same profile (path ≠ identity).
    final moved = dir.renameSync('${dir.path}-moved');
    final repo2 = LogRepository(
      sink: FileLogSink(File('${moved.path}/$vaultFileName')),
      durability: StorageDurability.localFile,
      location: moved.path,
    );
    await repo2.open();
    expect((await repo2.profiles()).length, 1);
    moved.deleteSync(recursive: true);
  });

  testWidgets('F002: a pre-F002 Linux vault in HumanHealthOS/ moves to '
      'human-health-os/ and opens with the same vault, profile and record', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final data = Directory.systemTemp.createTempSync('hhos-it-xdg-');
    final env = {'XDG_DATA_HOME': data.path, 'HOME': data.path};
    final exe = '${data.path}/bin/human_health_os';

    // "Old app": write a vault where FORGE 002..F001 builds kept it.
    final legacy = File('${data.path}/HumanHealthOS/$vaultFileName');
    final old = LogRepository(
      sink: FileLogSink(legacy),
      durability: StorageDurability.localFile,
      location: legacy.path,
    );
    await old.open();
    final oldServices = await servicesFor(dev, HostPlatform.linux, old);
    final saved = await oldServices.heartbeat.recordWeightKg(
      profileId: oldServices.self.id,
      input: '81,3',
    );
    final bytes = legacy.readAsBytesSync();

    // "New app": the real adapter resolves, moves and opens the vault.
    final choice = await createPlatformRepository(
      dev,
      env: env,
      executablePath: exe,
    );
    expect(choice.notes.single.kind, StorageNoteKind.movedLegacyFolder);
    final moved = File('${data.path}/human-health-os/$vaultFileName');
    expect(moved.readAsBytesSync(), bytes, reason: 'moved, not rewritten');
    expect(legacy.existsSync(), isFalse);
    final report = await choice.repository.open();
    expect(report.warnings, isEmpty);
    expect(report.readOnly, isFalse);
    expect(choice.repository.description.vaultId, old.description.vaultId);
    final services = await servicesFor(
      dev,
      HostPlatform.linux,
      choice.repository,
      reason: choice.reason,
      notes: choice.notes,
      report: report,
    );
    expect(services.self.id, oldServices.self.id);
    final again = (await services.heartbeat.currentWeights(services.self.id))
        .single;
    expect(again.toJson(), saved.toJson(), reason: 'id, provenance, text');
    final header =
        jsonDecode(moved.readAsLinesSync().first) as Map<String, Object?>;
    expect(header['format_version'], vaultFormatVersion);

    await tester.pumpWidget(
      HumanOsApp(services: services, appearance: english()),
    );
    await tester.pumpAndSettle();
    expect(find.text('81.3 kg'), findsWidgets);
    expect(
      find.byKey(const ValueKey('storage-note-movedLegacyFolder')),
      findsOneWidget,
    );

    // Second start: nothing left to move, no note.
    final second = await createPlatformRepository(
      dev,
      env: env,
      executablePath: exe,
    );
    expect(second.notes, isEmpty);
    expect(second.repository.description.location, moved.path);
    data.deleteSync(recursive: true);
  });

  testWidgets('F003: a correction and a withdrawal survive a relaunch on the '
      'real file vault (append-only)', (tester) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-f003-');
    final vault = File('${dir.path}/$vaultFileName');
    LogRepository open() => LogRepository(
      sink: FileLogSink(vault),
      durability: StorageDurability.localFile,
      location: vault.path,
    );
    final a = open();
    await a.open();
    final s1 = await servicesFor(dev, HostPlatform.linux, a);
    final w = await s1.heartbeat.recordWeightKg(
      profileId: s1.self.id,
      input: '90',
    );
    final c = await s1.heartbeat.correctWeightKg(
      profileId: s1.self.id,
      targetId: w.id,
      input: '9',
    );
    final before = vault.readAsStringSync();
    await s1.heartbeat.amend(
      profileId: s1.self.id,
      targetId: c.id,
      reason: AmendReason.enteredInError,
    );
    expect(vault.readAsStringSync().startsWith(before), isTrue);

    final b = open(); // relaunch
    final report = await b.open();
    expect(report.warnings, isEmpty);
    final s2 = await servicesFor(dev, HostPlatform.linux, b, report: report);
    final entry = (await s2.heartbeat.timeline(s2.self.id)).single;
    expect(entry.heads.single.id, w.id);
    expect(entry.withdrawn, {c.id});
    await tester.pumpWidget(HumanOsApp(services: s2, appearance: english()));
    await tester.pumpAndSettle();
    expect(find.text('90 kg'), findsWidgets);
    expect(find.text('9 kg'), findsNothing);
    dir.deleteSync(recursive: true);
  });

  testWidgets('F004: a lab result keeps every printed field across a '
      'relaunch on the real file vault', (tester) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-f004-');
    final vault = File('${dir.path}/$vaultFileName');
    LogRepository open() => LogRepository(
      sink: FileLogSink(vault),
      durability: StorageDurability.localFile,
      location: vault.path,
    );
    final a = open();
    await a.open();
    final s1 = await servicesFor(dev, HostPlatform.linux, a);
    final saved = await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'LDL Kolesterol',
        value: '142',
        notReported: false,
        unit: '',
        sampleDate: '2026-10-03',
        sourceFlag: 'H',
        referenceText: '< 130',
      ),
    );

    final b = open(); // relaunch
    final report = await b.open();
    expect(report.warnings, isEmpty);
    final s2 = await servicesFor(dev, HostPlatform.linux, b, report: report);
    final again = (await s2.heartbeat.labTimeline(s2.self.id)).single.shown;
    expect(again.toJson(), saved.toJson());
    expect(again.quantity!.unit, isNull, reason: 'missing unit stays missing');
    await tester.pumpWidget(HumanOsApp(services: s2, appearance: english()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labs').first);
    await tester.pumpAndSettle();
    // The result list sits below the entry form: scroll until it is built.
    final value = find.text('142 (unit not given)');
    await tester.scrollUntilVisible(
      value,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-labs')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(value, findsOneWidget);
    expect(find.text('Lab flag: H'), findsOneWidget);
    dir.deleteSync(recursive: true);
  });

  testWidgets('F004-S2: a censored and a text lab result survive a relaunch '
      'on the real file vault, shown as printed', (tester) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-f004s2-');
    final vault = File('${dir.path}/$vaultFileName');
    LogRepository open() => LogRepository(
      sink: FileLogSink(vault),
      durability: StorageDurability.localFile,
      location: vault.path,
    );
    final a = open();
    await a.open();
    final s1 = await servicesFor(dev, HostPlatform.linux, a);
    final censored = await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'CRP',
        value: '< 5',
        notReported: false,
        unit: 'mg/L',
        sampleDate: '2026-10-03',
        kind: LabValueKind.censored,
      ),
    );
    final text = await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'HBsAg',
        value: 'Negatif',
        notReported: false,
        unit: '',
        sampleDate: '2026-10-03',
        kind: LabValueKind.text,
      ),
    );

    final b = open(); // relaunch
    final report = await b.open();
    expect(report.warnings, isEmpty);
    final s2 = await servicesFor(dev, HostPlatform.linux, b, report: report);
    final again = {
      for (final e in await s2.heartbeat.labTimeline(s2.self.id))
        e.shown.id: e.shown,
    };
    expect(again[censored.id]!.toJson(), censored.toJson());
    expect(again[text.id]!.toJson(), text.toJson());
    expect(again[censored.id]!.quantity, isNull, reason: 'never a number');
    expect(again[censored.id]!.schemaVersion, 14);
    await tester.pumpWidget(HumanOsApp(services: s2, appearance: english()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labs').first);
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byKey(const ValueKey('screen-labs')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final t in [
      'below 5 mg/L (as printed: < 5)',
      'Negatif (text as printed)',
    ]) {
      await tester.scrollUntilVisible(find.text(t), 200, scrollable: list);
      expect(find.text(t), findsOneWidget);
    }
    dir.deleteSync(recursive: true);
  });

  testWidgets('F004-S3: report time, method and the reference interval as '
      'printed survive a relaunch on the real file vault, after the one '
      'upgrade checkpoint', (tester) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-f004s3-');
    final vault = File('${dir.path}/$vaultFileName');
    LogRepository open() => LogRepository(
      sink: FileLogSink(vault),
      durability: StorageDurability.localFile,
      location: vault.path,
    );
    final a = open();
    await a.open();
    final s1 = await servicesFor(dev, HostPlatform.linux, a);
    final plain = await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'TSH',
        value: '1,9',
        notReported: false,
        unit: 'mIU/L',
        sampleDate: '2026-10-03',
      ),
    );
    var checkpoints = 0;
    final previous = a.beforeSchemaUpgrade;
    a.beforeSchemaUpgrade = () async {
      checkpoints++;
      await previous?.call();
    };
    final detailed = await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'HbA1c',
        value: '5,4',
        notReported: false,
        unit: '%',
        sampleDate: '2026-10-03',
        referenceText: '4,0 - 6,0',
        reportTime: '2026-10-04 14:20',
        method: 'HPLC',
        refLow: '4,0',
        refHigh: '6,0',
        refUnit: '%',
        refPartition: 'Kadın 20-49 yaş',
      ),
    );
    expect(checkpoints, 1, reason: 'the first schema 15 record');
    expect(plain.schemaVersion, 3);
    expect(detailed.schemaVersion, 15);

    final b = open(); // relaunch
    final report = await b.open();
    expect(report.warnings, isEmpty);
    final s2 = await servicesFor(dev, HostPlatform.linux, b, report: report);
    final again = {
      for (final e in await s2.heartbeat.labTimeline(s2.self.id))
        e.shown.id: e.shown,
    };
    expect(again[detailed.id]!.toJson(), detailed.toJson());
    expect(again[plain.id]!.toJson(), plain.toJson());
    expect(again[detailed.id]!.lab!.referenceText, '4,0 - 6,0');
    await tester.pumpWidget(HumanOsApp(services: s2, appearance: english()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Labs').first);
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byKey(const ValueKey('screen-labs')),
          matching: find.byType(Scrollable),
        )
        .first;
    // The report's other lines sit under the result's Details (U038).
    final details = find.byKey(ValueKey('details-lab-${detailed.id}'));
    await tester.scrollUntilVisible(details, 200, scrollable: list);
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    for (final t in [
      'Method as printed: HPLC',
      'Reference interval as printed: 4,0–6,0 % (Kadın 20-49 yaş)',
    ]) {
      await tester.scrollUntilVisible(find.text(t), 200, scrollable: list);
      expect(find.text(t), findsOneWidget);
    }
    dir.deleteSync(recursive: true);
  });

  testWidgets('F007-S8: blood glucose in the unit chosen and body fat as '
      'the device showed it survive a relaunch on the real file vault, after '
      'the one upgrade checkpoint', (tester) async {
    final dir = Directory.systemTemp.createTempSync('hhos-it-f007s8-');
    final vault = File('${dir.path}/$vaultFileName');
    LogRepository open() => LogRepository(
      sink: FileLogSink(vault),
      durability: StorageDurability.localFile,
      location: vault.path,
    );
    final a = open();
    await a.open();
    final s1 = await servicesFor(dev, HostPlatform.linux, a);
    final weight = await s1.heartbeat.recordWeightKg(
      profileId: s1.self.id,
      input: '72,4',
    );
    var checkpoints = 0;
    final previous = a.beforeSchemaUpgrade;
    a.beforeSchemaUpgrade = () async {
      checkpoints++;
      await previous?.call();
    };
    final glucose = await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.capillaryGlucose,
      input: const MeasurementInput(
        value: '5,3',
        unit: 'mmol/L',
        glucoseTiming: GlucoseTiming.fasting,
      ),
    );
    final fat = await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.bodyFatPercentage,
      input: const MeasurementInput(value: '24,5'),
    );
    final miss = await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.capillaryGlucose,
      input: const MeasurementInput(notMeasured: true),
    );
    expect(checkpoints, 1, reason: 'the first schema 16 record');
    expect(weight.schemaVersion, 3);
    expect(glucose.schemaVersion, 16);
    expect(fat.state, RecordState.reported);

    final b = open(); // relaunch
    final report = await b.open();
    expect(report.warnings, isEmpty);
    final s2 = await servicesFor(dev, HostPlatform.linux, b, report: report);
    final again = {for (final r in await b.records(s2.self.id)) r.id: r};
    for (final r in [weight, glucose, fat, miss]) {
      expect(again[r.id]!.toJson(), r.toJson());
    }
    expect(again[glucose.id]!.quantity, const Quantity(5.3, 'mmol/L'));
    expect(again[miss.id]!.quantity, isNull);
    await tester.pumpWidget(HumanOsApp(services: s2, appearance: english()));
    await tester.pumpAndSettle();
    for (final (code, shown) in [
      ('glucose.capillary', '5.3 mmol/L · Fasting'),
      ('body.fat_percentage', '24.5 %'),
    ]) {
      final f = find.byKey(ValueKey('measure-latest-value-$code'));
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Text>(f).data, shown);
    }
    dir.deleteSync(recursive: true);
  });

  testWidgets('F005 restore drill: backup -> lose the vault -> fresh start '
      '-> restore -> relaunch shows the same records', (tester) async {
    if (!Platform.isLinux) return;
    final data = Directory.systemTemp.createTempSync('hhos-it-f005-');
    final env = {'XDG_DATA_HOME': data.path, 'HOME': data.path};
    final exe = '${data.path}/bin/human_health_os';
    Future<AppServices> launch() async {
      final choice = await createPlatformRepository(
        dev,
        env: env,
        executablePath: exe,
      );
      final report = await choice.repository.open();
      return servicesFor(
        dev,
        HostPlatform.linux,
        choice.repository,
        report: report,
        files: choice.files,
      );
    }

    final s1 = await launch();
    final w = await s1.heartbeat.recordWeightKg(
      profileId: s1.self.id,
      input: '82,5',
    );
    await s1.heartbeat.recordLab(
      profileId: s1.self.id,
      input: const LabInput(
        analyte: 'HbA1c',
        value: '5,4',
        notReported: false,
        unit: '%',
        sampleDate: '2026-10-03',
        sourceFlag: 'H',
      ),
    );
    final vault = File('${data.path}/human-health-os/$vaultFileName');
    final original = vault.readAsStringSync();
    final bundle = await s1.makeBackup!(DateTime.utc(2026, 10, 7, 12));
    await s1.dataFiles!.save(
      DataFileKind.backup,
      'drill.hhosbackup.json',
      bundle,
    );

    vault.deleteSync(); // the disaster
    final s2 = await launch(); // a fresh start creates a new, empty vault
    expect(await s2.heartbeat.currentWeights(s2.self.id), isEmpty);
    expect(s2.self.id, isNot(s1.self.id));

    final saved = (await s2.dataFiles!.backups()).single;
    final staged = stageRestore(await s2.dataFiles!.read(saved));
    final out = await s2.dataFiles!.restore(
      staged,
      now: DateTime.utc(2026, 10, 7, 13),
    );
    expect(out.keptPrevious, isNotNull);
    expect(vault.readAsStringSync(), original);

    final s3 = await launch(); // relaunch after the restore
    expect(s3.self.id, s1.self.id);
    expect(
      (await s3.heartbeat.currentWeights(s3.self.id)).single.toJson(),
      w.toJson(),
    );
    await tester.pumpWidget(HumanOsApp(services: s3, appearance: english()));
    await tester.pumpAndSettle();
    expect(find.text('82.5 kg'), findsWidgets);
    data.deleteSync(recursive: true);
  });

  testWidgets('F006: a production build starts at the vault gate, creates '
      'the encrypted vault (production key cost, in an isolate), and after a '
      'relaunch refuses a wrong passphrase and opens with the right one', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final data = Directory.systemTemp.createTempSync('hhos-it-f006-');
    final env = {'HHOS_DATA_DIR': data.path, 'HOME': data.path};
    const pass = 'Mavi-Kedi 7 Ağaç Lamba!';

    Future<void> launch() async {
      final startup = await startApp(prod, HostPlatform.linux, env: env);
      expect(startup.gate, isNotNull, reason: 'never the shell first');
      await tester.pumpWidget(HumanOsApp.start(startup, appearance: english()));
      await tester.pumpAndSettle();
    }

    await launch();
    expect(find.byKey(const ValueKey('vault-gate-create')), findsOneWidget);
    expect(data.listSync(), isEmpty, reason: 'nothing written before create');
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tester.enterText(
      find.byKey(const ValueKey('gate-passphrase-confirm')),
      pass,
    );
    await tapKey(tester, 'gate-continue');
    await tester.pumpAndSettle();
    final key = tester
        .widget<SelectableText>(find.byKey(const ValueKey('gate-recovery-key')))
        .data!;
    await tapKey(tester, 'gate-key-written');
    await tester.pumpAndSettle();
    await confirmRecoveryGroups(tester, key);
    await tapKey(tester, 'gate-create-vault');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));

    final services = tester.widget<AppShell>(find.byType(AppShell)).services;
    expect(services.storage.encrypted, isTrue);
    await services.heartbeat.recordWeightKg(
      profileId: services.self.id,
      input: '74,2',
    );
    await services.heartbeat.recordLab(
      profileId: services.self.id,
      input: const LabInput(
        analyte: 'Açlık kan şekeri',
        value: '92,4',
        notReported: false,
        unit: 'mg/dL',
        sampleDate: '2026-10-03',
        laboratory: 'Örnek Laboratuvarı',
      ),
    );

    final file = File('${data.path}/vault.hhosvault');
    expect(
      data.listSync().map((e) => e.path.split('/').last).toList()..sort(),
      ['vault.hhosvault', 'vault.hhosvault.prefs'],
      reason:
          'only the encrypted vault and its sealed display preferences '
          '(U018), no plaintext log or copy',
    );
    final prefs = File('${data.path}/vault.hhosvault.prefs').readAsStringSync();
    for (final s in ['language', 'theme', 'font', pass, key]) {
      expect(prefs, isNot(contains(s)), reason: 'sealed: $s');
    }
    final stored = file.readAsStringSync();
    for (final s in [
      pass,
      key,
      'Açlık',
      'Örnek',
      '74,2',
      '92,4',
      'lab.result',
    ]) {
      expect(stored, isNot(contains(s)), reason: s);
    }
    final header = jsonDecode(stored.split('\n').first) as Map;
    expect(
      ((header['keys'] as List).first as Map)['kdf'],
      containsPair('memory_kib', 19456),
    );

    await tester.pumpWidget(const SizedBox());
    await launch(); // relaunch
    expect(find.byKey(const ValueKey('vault-gate-unlock')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('gate-passphrase')),
      'not the passphrase',
    );
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('gate-error')));

    expect(
      file.readAsStringSync(),
      stored,
      reason: 'a failed unlock writes nothing',
    );
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));
    expect(find.text('74.2 kg'), findsWidgets);
    data.deleteSync(recursive: true);
  });

  testWidgets('F006 on real files: recovery replaces the passphrase; key loss '
      'keeps the locked vault aside; a portable vault lives in UserData/ and '
      'keeps its identity when the folder moves', (tester) async {
    if (!Platform.isLinux) return;
    final root = Directory.systemTemp.createTempSync('hhos-it-f006b-');
    final app = Directory('${root.path}/HumanOS')..createSync();
    File('${app.path}/portable_mode.json').writeAsStringSync('{}');
    final exe = '${app.path}/human_health_os';

    Future<EncryptedVault> vaultAt(String exePath) async =>
        (await createPlatformRepository(prod, executablePath: exePath)).vault!;

    final v = await vaultAt(exe);
    expect(v.location, '${app.path}/UserData/vault.hhosvault');
    final key = newRecoveryKeyForIt();
    final created = await v.create(
      passphrase: 'first long passphrase',
      recoveryKey: key,
    );
    final svc = HeartbeatService(created.repository);
    final me = (await svc.ensureSelfProfile()).id;
    await svc.recordWeightKg(profileId: me, input: '70');
    final vaultId = created.repository.description.vaultId;

    // The folder moves to another place (another USB port, another PC).
    Directory('${root.path}/Moved').createSync();
    final movedApp = app.renameSync('${root.path}/Moved/HumanOS');
    final moved = await vaultAt('${movedApp.path}/human_health_os');
    final recovered = await moved.recover(
      recoveryKey: key.toLowerCase().replaceAll('-', ' '),
      newPassphrase: 'second long passphrase',
    );
    expect(recovered.repository.description.vaultId, vaultId);
    expect((await recovered.repository.records(me)).length, 1);
    await expectLater(
      moved.unlock('first long passphrase'),
      throwsA(isA<CryptoFailure>()),
    );

    // Both secrets lost: the vault is kept aside, never deleted.
    final file = File('${movedApp.path}/UserData/vault.hhosvault');
    final bytes = file.readAsBytesSync();
    final kept = await moved.setAside();
    expect(File(kept).readAsBytesSync(), bytes);
    expect(file.existsSync(), isFalse);
    expect((await moved.inspect()).access, VaultAccess.create);
    root.deleteSync(recursive: true);
  });

  testWidgets('F007 on real files: measurements typed on Today and a '
      'correction survive a relaunch; weight stays schema 3; the first '
      'measurement keeps a backup of the earlier vault on disk', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final data = Directory.systemTemp.createTempSync('hhos-it-f007-');
    final env = {'XDG_DATA_HOME': data.path, 'HOME': data.path};
    final exe = '${data.path}/bin/human_health_os';
    Future<AppServices> launch() async {
      final choice = await createPlatformRepository(
        dev,
        env: env,
        executablePath: exe,
      );
      final report = await choice.repository.open();
      expect(report.warnings, isEmpty);
      final services = await servicesFor(
        dev,
        HostPlatform.linux,
        choice.repository,
        report: report,
        files: choice.files,
      );
      await tester.pumpWidget(
        HumanOsApp(services: services, appearance: english()),
      );
      await tester.pumpAndSettle();
      await revealMeasurements(tester);
      return services;
    }

    final s1 = await launch();
    await s1.heartbeat.recordWeightKg(profileId: s1.self.id, input: '79,4');
    final vault = File('${data.path}/human-health-os/$vaultFileName');
    final beforeMeasurements = vault.readAsStringSync();

    await tapKey(tester, 'measure-tile-vital.blood_pressure');
    await tester.pumpAndSettle();
    await fillKey(tester, 'measure-systolic', '128');
    await fillKey(tester, 'measure-diastolic', '84');
    await tapKey(tester, 'measure-more');
    await tester.pumpAndSettle();
    await fillKey(tester, 'measure-context', 'sitting, left arm');
    await tapKey(tester, 'measure-save');
    await waitFor(tester, find.byKey(const ValueKey('measure-saved')));
    final message = tester
        .widget<Text>(find.byKey(const ValueKey('measure-saved')))
        .data!;
    expect(message, startsWith('Saved: 128/84 mmHg. Before saving this entry'));

    // The checkpoint is the vault exactly as it was before the measurement.
    final kept = (await s1.dataFiles!.backups()).single;
    expect(kept.id, startsWith('${data.path}/human-health-os/backups/'));
    expect(message, contains(kept.id));
    final staged = stageRestore(await s1.dataFiles!.read(kept));
    expect(staged.payload, beforeMeasurements);
    expect(staged.manifest.recordSchemaVersions, [3]);

    await tapKey(tester, 'measure-tile-vital.resting_heart_rate');
    await tester.pumpAndSettle();
    await fillKey(tester, 'measure-value', '57');
    await tapKey(tester, 'measure-save');
    // The blood-pressure snack bar can still be up with the same key; the
    // exact message (no backup sentence) proves one checkpoint only.
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == const ValueKey('measure-saved') &&
            (w.data ?? '').startsWith('Saved: 57 bpm'),
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.key == const ValueKey('measure-saved') &&
                  (w.data ?? '').startsWith('Saved: 57 bpm'),
            ),
          )
          .data,
      'Saved: 57 bpm',
      reason: 'one checkpoint, before the first measurement only',
    );
    expect((await s1.dataFiles!.backups()).length, 1);

    final reading = (await s1.heartbeat.measurementTimeline(
      s1.self.id,
      RecordKind.bloodPressure,
    )).single.heads.single;
    await s1.heartbeat.correctMeasurement(
      profileId: s1.self.id,
      targetId: reading.id,
      input: const MeasurementInput(systolic: '124', diastolic: '82'),
    );
    await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.waistCircumference,
      input: const MeasurementInput(value: '84,25', context: 'standing'),
    );
    // Slice 2: a height with a time typed on the screen; the first schema-5
    // record makes the second checkpoint, of the vault as it was then.
    final beforeHeight = vault.readAsStringSync();
    // Height sits under "More measurements" until it has a record (U036).
    if (find
        .byKey(const ValueKey('measure-tile-body.height'))
        .evaluate()
        .isEmpty) {
      await tapKey(tester, 'measurements-more');
      await tester.pumpAndSettle();
    }
    await tapKey(tester, 'measure-tile-body.height');
    await tester.pumpAndSettle();
    await fillKey(tester, 'measure-value', '172,5');
    await tapKey(tester, 'measure-more');
    await tester.pumpAndSettle();
    await fillKey(tester, 'measure-when', '2026-10-01 08:00Z');
    await tapKey(tester, 'measure-save');
    // The heart-rate snack bar ("Saved: 57 bpm") can still be on screen
    // with the same key on a busy machine: wait for this save's own message.
    await waitFor(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == const ValueKey('measure-saved') &&
            (w.data ?? '').startsWith('Saved: 172.5 cm.'),
      ),
    );
    expect(
      tester
          .widget<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.key == const ValueKey('measure-saved') &&
                  (w.data ?? '').startsWith('Saved: 172.5 cm.'),
            ),
          )
          .data,
      startsWith('Saved: 172.5 cm. Before saving this entry'),
    );
    final backups = await s1.dataFiles!.backups();
    expect(backups, hasLength(2));
    final newest = stageRestore(await s1.dataFiles!.read(backups.first));
    expect(newest.payload, beforeHeight);
    expect(newest.manifest.recordSchemaVersions, [3, 4]);
    final state = parseVaultLog(vault.readAsStringSync());
    expect(state.warnings, isEmpty);
    expect(
      [for (final id in state.order) state.records[id]!.schemaVersion],
      [3, 4, 4, 4, 4, 5],
    );
    final height = state.records[state.order.last]!;
    expect(height.observedAt, DateTime.utc(2026, 10, 1, 8));
    expect(height.recordedAt.isAfter(DateTime.utc(2026, 11)), isTrue);
    expect(vault.readAsStringSync().startsWith(beforeMeasurements), isTrue);

    await tester.pumpWidget(const SizedBox());
    final s2 = await launch(); // relaunch on the same files
    expect(s2.self.id, s1.self.id);
    String latest(RecordKind k) => tester
        .widget<Text>(find.byKey(ValueKey('measure-latest-value-${k.code}')))
        .data!;
    expect(latest(RecordKind.bloodPressure), '124/82 mmHg');
    expect(latest(RecordKind.restingHeartRate), '57 bpm');
    expect(latest(RecordKind.waistCircumference), '84.25 cm');
    expect(latest(RecordKind.height), '172.5 cm');
    final versions = (await s2.heartbeat.measurementTimeline(
      s2.self.id,
      RecordKind.bloodPressure,
    )).single;
    expect(versions.heads.single.supersedesId, reading.id);
    expect(versions.versions.length, 2, reason: 'the first reading is kept');
    expect(
      versions.versions.firstWhere((r) => r.id == reading.id).context,
      'sitting, left arm',
    );
    data.deleteSync(recursive: true);
  });

  testWidgets('F007 in a production encrypted vault: measurements leave no '
      'plaintext, the checkpoint backup is encrypted, and after a relaunch '
      'the gate unlocks to the same readings', (tester) async {
    if (!Platform.isLinux) return;
    final data = Directory.systemTemp.createTempSync('hhos-it-f007b-');
    final env = {'HHOS_DATA_DIR': data.path, 'HOME': data.path};
    const pass = 'Mavi-Kedi 7 Ağaç Lamba!';

    final choice = await createPlatformRepository(prod, env: env);
    final opened = await choice.vault!.create(
      passphrase: pass,
      recoveryKey: newRecoveryKeyForIt(),
    );
    final s1 = await servicesFor(
      prod,
      HostPlatform.linux,
      opened.repository,
      report: opened.report,
      files: opened.files,
    );
    await s1.heartbeat.recordWeightKg(profileId: s1.self.id, input: '74,2');
    await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.bloodPressure,
      input: const MeasurementInput(
        systolic: '131',
        diastolic: '87',
        context: 'sitting, left arm',
      ),
    );
    await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.waistCircumference,
      input: const MeasurementInput(value: '84,75'),
    );
    final hr = await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.restingHeartRate,
      input: const MeasurementInput(value: '57'),
    );
    await s1.heartbeat.correctMeasurement(
      profileId: s1.self.id,
      targetId: hr.id,
      input: const MeasurementInput(value: '56'),
    );
    await s1.heartbeat.recordMeasurement(
      profileId: s1.self.id,
      kind: RecordKind.height,
      input: const MeasurementInput(value: '172,5', when: '2026-10-01 08:00Z'),
    );
    expect(s1.checkpointSaved!.value, isNotNull);

    final file = File('${data.path}/vault.hhosvault');
    final stored = file.readAsStringSync();
    for (final s in [
      pass,
      'vital.blood_pressure',
      'body.waist_circumference',
      'blood_pressure',
      'sitting, left arm',
      '84,75',
      '74,2',
      'body.height',
      '172,5',
      '2026-10-01 08:00Z',
    ]) {
      expect(stored, isNot(contains(s)), reason: s);
    }
    // Two checkpoints, one for each step of the record schema (3 to 4, then
    // 4 to 5), both encrypted, neither replacing the other.
    final backups = Directory('${data.path}/backups').listSync();
    expect(backups, hasLength(2));
    final schemas = <List<int>>[];
    for (final b in backups) {
      final checkpoint = File(b.path).readAsStringSync();
      expect(checkpoint, contains(encryptionEnvelopeV1));
      final staged = stageRestore(checkpoint);
      expect(staged.manifest.encrypted, isTrue);
      schemas.add(staged.manifest.recordSchemaVersions);
      for (final s in [
        '74,2',
        'body.weight',
        'blood_pressure',
        'body.height',
      ]) {
        expect(checkpoint, isNot(contains(s)), reason: s);
      }
    }
    expect(
      schemas,
      containsAll([
        [3],
        [3, 4],
      ]),
    );

    // Relaunch: the gate first, then the same readings.
    final startup = await startApp(prod, HostPlatform.linux, env: env);
    expect(startup.gate, isNotNull);
    await tester.pumpWidget(HumanOsApp.start(startup, appearance: english()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));
    await revealMeasurements(tester);
    String latest(RecordKind k) => tester
        .widget<Text>(find.byKey(ValueKey('measure-latest-value-${k.code}')))
        .data!;
    expect(latest(RecordKind.bloodPressure), '131/87 mmHg');
    expect(latest(RecordKind.waistCircumference), '84.75 cm');
    expect(latest(RecordKind.restingHeartRate), '56 bpm');
    expect(latest(RecordKind.height), '172.5 cm');
    data.deleteSync(recursive: true);
  });

  testWidgets('F005-S3 on real files: a development vault is backed up, an '
      'encrypted vault in another folder brings it in through the screens, '
      'a relaunch and unlock shows the records, and the vault file holds no '
      'plaintext marker', (tester) async {
    if (!Platform.isLinux) return;
    final devData = Directory.systemTemp.createTempSync('hhos-it-f005s3-dev-');
    final encData = Directory.systemTemp.createTempSync('hhos-it-f005s3-enc-');
    const marker = 'PLAINTEXT-MARKER-QX7';
    const pass = 'Mavi-Kedi 7 Ağaç Lamba!';

    // 1. The development build: records, then a backup on disk.
    final devEnv = {'XDG_DATA_HOME': devData.path, 'HOME': devData.path};
    final devChoice = await createPlatformRepository(
      dev,
      env: devEnv,
      executablePath: '${devData.path}/bin/human_health_os',
    );
    final devReport = await devChoice.repository.open();
    final d = await servicesFor(
      dev,
      HostPlatform.linux,
      devChoice.repository,
      report: devReport,
      files: devChoice.files,
    );
    final w = await d.heartbeat.recordWeightKg(
      profileId: d.self.id,
      input: '81,5',
    );
    await d.heartbeat.correctWeightKg(
      profileId: d.self.id,
      targetId: w.id,
      input: '81,2',
    );
    await d.heartbeat.recordDocument(
      profileId: d.self.id,
      title: '$marker kan tahlili',
      nature: DocumentType.labReport,
    );
    final devRecords = await d.heartbeat.repository.records(d.self.id);
    final backupPath = await d.dataFiles!.save(
      DataFileKind.backup,
      'dev.hhosbackup.json',
      await d.makeBackup!(DateTime.utc(2026, 11, 20, 8)),
    );
    final backupBytes = File(backupPath).readAsStringSync();
    expect(backupBytes, contains(marker), reason: 'the dev file is plain');

    // 2. The encrypted build in another folder, created through the gate;
    // the system chooser hands over the real backup file.
    final encEnv = {'HHOS_DATA_DIR': encData.path, 'HOME': encData.path};
    final picker = SystemBackupFilePicker(
      choose: (_) async => _RealFile(File(backupPath)),
    );
    final choice = await createPlatformRepository(prod, env: encEnv);
    final vault = choice.vault!;
    final gate = VaultGate(
      vault: vault,
      inspection: await vault.inspect(),
      open: (o) => servicesFor(
        prod,
        HostPlatform.linux,
        o.repository,
        reason: StorageReason.saving,
        report: o.report,
        files: o.files,
        derive: choice.derive,
        preferences: o.preferences,
        backupPicker: picker,
      ),
      memoryOnly: (reason, {detail}) => throw StateError('not used'),
    );
    await tester.pumpWidget(
      HumanOsApp.start(AppStartup.gate(gate), appearance: english()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tester.enterText(
      find.byKey(const ValueKey('gate-passphrase-confirm')),
      pass,
    );
    await tapKey(tester, 'gate-continue');
    await tester.pumpAndSettle();
    final key = tester
        .widget<SelectableText>(find.byKey(const ValueKey('gate-recovery-key')))
        .data!;
    await tapKey(tester, 'gate-key-written');
    await tester.pumpAndSettle();
    await confirmRecoveryGroups(tester, key);
    await tapKey(tester, 'gate-create-vault');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));

    final file = File('${encData.path}/vault.hhosvault');
    final before = file.readAsStringSync();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('import-development')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-today')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'import-development');
    await waitFor(tester, find.byKey(const ValueKey('import-preview')));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('import-preview-text')))
          .data,
      contains('It holds 3 records and 1 profile.'),
    );
    expect(file.readAsStringSync(), before, reason: 'nothing before confirm');
    await tapKey(tester, 'import-understand');
    await tester.pumpAndSettle();
    await tapKey(tester, 'confirm-import');
    await waitFor(tester, find.textContaining('Brought in 3 records'));

    // 3. The vault file: no plaintext marker, the earlier envelope kept.
    final stored = file.readAsStringSync();
    for (final s in [marker, 'kan tahlili', '81,5', '81,2', pass, key]) {
      expect(stored, isNot(contains(s)), reason: s);
    }
    final kept = encData
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('vault.hhosvault.before-restore-'))
        .toList();
    expect(kept, hasLength(1));
    expect(File('${encData.path}/${kept.single}').readAsStringSync(), before);
    expect(
      File(backupPath).readAsStringSync(),
      backupBytes,
      reason: 'the chosen file is never changed or deleted by the app',
    );

    // 4. Relaunch the real start path, unlock, see the records.
    await tester.pumpWidget(const SizedBox());
    final startup = await startApp(prod, HostPlatform.linux, env: encEnv);
    expect(startup.gate, isNotNull);
    await tester.pumpWidget(HumanOsApp.start(startup, appearance: english()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));
    expect(find.text('81.2 kg'), findsWidgets);
    final s = tester.widget<AppShell>(find.byType(AppShell)).services;
    expect(s.self.id, d.self.id);
    final got = await s.heartbeat.repository.records(s.self.id);
    expect(
      {for (final r in got) r.id: jsonEncode(r.toJson())},
      {for (final r in devRecords) r.id: jsonEncode(r.toJson())},
    );
    // F005-S4 (G-76, D-053): the vault now holds records; it still offers
    // the import (scrolled to below), now as a merge.
    // 5. One more record in the encrypted vault, one more in the
    // development build, and a new development backup that overlaps.
    final own = await s.heartbeat.recordWeightKg(
      profileId: s.self.id,
      input: '80,4',
    );
    final devNew = await d.heartbeat.recordWeightKg(
      profileId: d.self.id,
      input: '79,9',
    );
    final backup2 = await d.dataFiles!.save(
      DataFileKind.backup,
      'dev2.hhosbackup.json',
      await d.makeBackup!(DateTime.utc(2026, 11, 21, 8)),
    );
    final backup2Bytes = File(backup2).readAsStringSync();

    // 6. Unlock through a gate whose chooser hands over the second file,
    // bring it in through the screens.
    await tester.pumpWidget(const SizedBox());
    final picker2 = SystemBackupFilePicker(
      choose: (_) async => _RealFile(File(backup2)),
    );
    final choice2 = await createPlatformRepository(prod, env: encEnv);
    final vault2 = choice2.vault!;
    final gate2 = VaultGate(
      vault: vault2,
      inspection: await vault2.inspect(),
      open: (o) => servicesFor(
        prod,
        HostPlatform.linux,
        o.repository,
        reason: StorageReason.saving,
        report: o.report,
        files: o.files,
        derive: choice2.derive,
        preferences: o.preferences,
        backupPicker: picker2,
      ),
      memoryOnly: (reason, {detail}) => throw StateError('not used'),
    );
    await tester.pumpWidget(
      HumanOsApp.start(AppStartup.gate(gate2), appearance: english()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));
    final beforeMerge = file.readAsStringSync();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('import-development')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('screen-today')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'import-development');
    await waitFor(tester, find.byKey(const ValueKey('import-preview')));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('import-counts'))).data,
      'New, to be added: 1\n'
      'Already in this vault, skipped: 3\n'
      'Different from the record in this vault, blocking: 0',
    );
    expect(file.readAsStringSync(), beforeMerge, reason: 'nothing yet');
    await tapKey(tester, 'import-understand');
    await tester.pumpAndSettle();
    await tapKey(tester, 'confirm-import');
    await waitFor(
      tester,
      find.textContaining('New records added, encrypted in this vault: 1.'),
    );

    // 7. Nothing stored was rewritten: the vault file begins with every
    // byte it had; no plaintext; the file as it was is kept; the chosen
    // file unchanged.
    final merged = file.readAsStringSync();
    expect(merged.startsWith(beforeMerge), isTrue);
    expect(merged.length, greaterThan(beforeMerge.length));
    for (final x in [marker, 'kan tahlili', '79,9', '80,4', pass, key]) {
      expect(merged, isNot(contains(x)), reason: x);
    }
    final keptAll = encData
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('vault.hhosvault.before-restore-'))
        .map((n) => File('${encData.path}/$n').readAsStringSync())
        .toList();
    expect(keptAll, contains(beforeMerge));
    expect(File(backup2).readAsStringSync(), backup2Bytes);

    // 8. Relaunch, unlock: the union, each record byte for byte.
    await tester.pumpWidget(const SizedBox());
    final startup2 = await startApp(prod, HostPlatform.linux, env: encEnv);
    await tester.pumpWidget(HumanOsApp.start(startup2, appearance: english()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gate-passphrase')), pass);
    await tapKey(tester, 'gate-unlock');
    await waitFor(tester, find.byKey(const ValueKey('screen-today')));
    final s2 = tester.widget<AppShell>(find.byType(AppShell)).services;
    expect(s2.self.id, d.self.id);
    expect(s2.loadWarnings, isEmpty);
    final union = await s2.heartbeat.repository.records(s2.self.id);
    final expected = [...devRecords, own, devNew];
    expect(
      {for (final r in union) r.id: jsonEncode(r.toJson())},
      {for (final r in expected) r.id: jsonEncode(r.toJson())},
    );
    expect(union, hasLength(5));
    devData.deleteSync(recursive: true);
    encData.deleteSync(recursive: true);
  });
}

/// A real file as the system chooser hands it over.
class _RealFile implements ChosenFile {
  _RealFile(this.file);

  final File file;

  @override
  String get name => file.uri.pathSegments.last;

  @override
  Future<int?> size() => file.length();

  @override
  Future<List<int>> read() => file.readAsBytes();
}

/// A fixed, synthetic recovery key: integration runs stay reproducible.
String newRecoveryKeyForIt() => 'K7QM-2XRA-PLMN-B3DE-ZZ4H-QW5T-RT6Y-HJ7U';

/// Types back the two recovery key groups the gate asks for (G-38).
Future<void> confirmRecoveryGroups(WidgetTester tester, String key) async {
  final groups = key.split('-');
  for (var n = 1; n <= groups.length; n++) {
    final f = find.byKey(ValueKey('gate-confirm-group-$n'));
    if (f.evaluate().isNotEmpty) await tester.enterText(f, groups[n - 1]);
  }
  await tester.pump();
}
