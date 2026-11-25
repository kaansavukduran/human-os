// F005-S3 (G-76, D-050) through the screens: an empty encrypted vault
// offers "Bring in records from the development build"; the chosen file is
// checked, previewed with its counts and the warning that it is not
// encrypted and never deleted by the app; nothing changes before the
// confirmation; after a restart and unlock the records are there. The
// entry is not offered by a development build or a vault with records.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/local/encrypted_vault.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/ports/storage_status.dart';

import 'f005s2_web_restore_test.dart' show FakePicker;
import 'f006_vault_gate_test.dart'
    show
        Disk,
        LinkedFiles,
        cheap,
        createThroughGate,
        dev,
        latest,
        pass,
        prod,
        saveWeight,
        settle,
        tapKey,
        textOf,
        type;

const enWarning =
    'The file you chose is not encrypted. Anyone who opens it can read your '
    'health records. Human OS does not delete it for you: once the records '
    'are here, delete the file yourself, and its copies.';
const trWarning =
    'Seçtiğin dosya şifreli değil. Onu açan herkes sağlık kayıtlarını '
    'okuyabilir. Human OS onu senin yerine silmez: kayıtlar buraya gelince '
    'dosyayı ve kopyalarını kendin sil.';

const enMergeExplain =
    'If you also kept records in the development build, choose a backup or '
    'an export you made there. Records already in this vault are skipped, '
    'new ones are added, and nothing here is changed or replaced. You see '
    'the counts before anything changes.';

/// A development backup with a weight and its correction.
Future<String> devBackup() async {
  final repo = LogRepository(
    sink: MemoryLogSink(),
    durability: StorageDurability.localFile,
    location: 'dev',
  );
  await repo.open();
  final svc = HeartbeatService(repo);
  final me = (await svc.ensureSelfProfile()).id;
  final w = await svc.recordWeightKg(profileId: me, input: '81,5');
  await svc.correctWeightKg(profileId: me, targetId: w.id, input: '81,2');
  return createBackupBundle(
    vaultLogText: (await (repo.sink as MemoryLogSink).read())!,
    appVersion: '0.1.0+1',
    sourceRevision: 'dev',
    createdAt: DateTime.utc(2026, 11, 19, 8),
  );
}

Future<VaultGate> gateWith(Disk disk, FakePicker picker) async {
  final vault = EncryptedVault(
    raw: disk.raw,
    location: 'test vault',
    newKdf: cheap,
    filesFor: (sink) => LinkedFiles(disk.raw, sink),
  );
  return VaultGate(
    vault: vault,
    inspection: await vault.inspect(),
    open: (o) => servicesFor(
      prod,
      HostPlatform.linux,
      o.repository,
      reason: StorageReason.saving,
      report: o.report,
      files: o.files,
      backupPicker: picker,
    ),
    memoryOnly: (reason, {detail}) async {
      final r = inMemoryRepository();
      await r.open();
      return servicesFor(prod, HostPlatform.linux, r, reason: reason);
    },
  );
}

Future<void> launch(
  WidgetTester tester,
  Disk disk,
  FakePicker picker, {
  Locale? locale,
  Size size = const Size(1280, 2600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (locale != null) {
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }
  final gate = await tester.runAsync(() => gateWith(disk, picker));
  await tester.pumpWidget(HumanOsApp(gate: gate));
  await settle(tester);
}

/// Scrolls Today's own list until [key] is built and visible.
Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    300,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('screen-today')),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          ),
        )
        .first,
  );
  await settle(tester);
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

void main() {
  testWidgets('an empty encrypted vault brings in a development backup: '
      'preview with counts and the warning, confirmation required, then '
      'after a restart and unlock the records are there', (tester) async {
    final bundle = (await tester.runAsync(devBackup))!;
    final picker = FakePicker(bundle, 'human-os-backup-dev.hhosbackup.json');
    final disk = Disk();
    await launch(tester, disk, picker);
    await createThroughGate(tester);
    expect(find.byKey(const ValueKey('import-explain')), findsOneWidget);
    final before = disk.raw.text;

    await tapKey(tester, 'import-development');
    expect(picker.picks, 1);
    expect(find.byKey(const ValueKey('import-preview')), findsOneWidget);
    final preview = textOf(tester, 'import-preview-text');
    expect(preview, contains('human-os-backup-dev.hhosbackup.json'));
    expect(preview, contains('a development backup'));
    expect(preview, contains('It holds 2 records and 1 profile.'));
    expect(preview, contains('Checksum, version and contents were checked.'));
    expect(textOf(tester, 'import-warning-text'), enWarning);
    expect(enabled(tester, 'confirm-import'), isFalse);
    expect(disk.raw.text, before, reason: 'nothing written before confirm');

    await tapKey(tester, 'import-understand');
    expect(enabled(tester, 'confirm-import'), isTrue);
    await tapKey(tester, 'confirm-import');
    expect(
      textOf(tester, 'data-message'),
      startsWith(
        'Brought in 2 records and 1 profile, encrypted in this vault. Close '
        'and reopen Human OS, then unlock it with your passphrase as before. '
        'The file you chose is not encrypted and was not changed: delete it '
        'yourself when you no longer need it.',
      ),
    );
    expect(disk.raw.text, isNot(contains('81,2')));
    expect(enabled(tester, 'create-backup'), isFalse, reason: 'restart first');
    expect(find.byKey(const ValueKey('import-development')), findsNothing);

    await launch(tester, disk, picker);
    await type(tester, 'gate-passphrase', pass);
    await tapKey(tester, 'gate-unlock');
    expect(latest(tester), '81.2 kg');
    // F005-S4 (D-053): a vault with records is offered a merge.
    expect(find.byKey(const ValueKey('import-development')), findsOneWidget);
    expect(textOf(tester, 'import-explain'), enMergeExplain);
  });

  testWidgets('cancel and no file change nothing; a refused file says why '
      'and the vault is untouched', (tester) async {
    final bundle = (await tester.runAsync(devBackup))!;
    final picker = FakePicker(null);
    final disk = Disk();
    await launch(tester, disk, picker);
    await createThroughGate(tester);
    final before = disk.raw.text;

    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'data-message'),
      'No file chosen. Nothing was changed.',
    );

    picker.text = bundle;
    await tapKey(tester, 'import-development');
    await tapKey(tester, 'import-understand');
    await tapKey(tester, 'cancel-import');
    expect(
      textOf(tester, 'data-message'),
      'Nothing was brought in. Nothing was changed.',
    );
    expect(disk.raw.text, before);

    picker.text = bundle.replaceFirst('81,5', '91,5');
    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'data-message'),
      startsWith('This backup is damaged: its content does not match'),
    );
    expect(find.byKey(const ValueKey('import-preview')), findsNothing);
    expect(disk.raw.text, before);
  });

  testWidgets('the entry says at once that records are merged once a '
      'record is saved, without leaving Today (F005-S4)', (tester) async {
    final bundle = (await tester.runAsync(devBackup))!;
    final disk = Disk();
    await launch(tester, disk, FakePicker(bundle));
    await createThroughGate(tester);
    expect(find.byKey(const ValueKey('import-development')), findsOneWidget);
    await saveWeight(tester, '80');
    expect(latest(tester), '80 kg');
    expect(find.byKey(const ValueKey('import-development')), findsOneWidget);
    expect(textOf(tester, 'import-explain'), enMergeExplain);
  });

  testWidgets('Turkish: the entry, the warning and the confirmation', (
    tester,
  ) async {
    final bundle = (await tester.runAsync(devBackup))!;
    final disk = Disk();
    await launch(tester, disk, FakePicker(bundle), locale: const Locale('tr'));
    await createThroughGate(tester);
    expect(
      find.text('Geliştirme sürümündeki kayıtları buraya getir'),
      findsOneWidget,
    );
    await tapKey(tester, 'import-development');
    expect(textOf(tester, 'import-warning-text'), trWarning);
    expect(
      textOf(tester, 'import-preview-text'),
      contains('2 kayıt ve 1 profil içeriyor.'),
    );
    expect(
      find.text('Dosyanın ben silene kadar şifresiz kaldığını anlıyorum'),
      findsOneWidget,
    );
    expect(find.text('Getir'), findsOneWidget);
  });

  testWidgets('320 dp at 2x text: the entry and the preview fit, the '
      'confirmation can be reached', (tester) async {
    final bundle = (await tester.runAsync(devBackup))!;
    final disk = Disk();
    await launch(
      tester,
      disk,
      FakePicker(bundle),
      size: const Size(320, 4000),
      textScale: 2,
    );
    await createThroughGate(tester);
    expect(tester.takeException(), isNull);
    await reveal(tester, 'import-development');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'import-development');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('import-warning-text')), findsOneWidget);
    await tapKey(tester, 'import-understand');
    await tapKey(tester, 'confirm-import');
    expect(tester.takeException(), isNull);
    expect(textOf(tester, 'data-message'), startsWith('Brought in 2 records'));
  });

  testWidgets('a development build never offers it (its own behaviour is '
      'unchanged)', (tester) async {
    tester.view.physicalSize = const Size(1280, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final services = await tester.runAsync(() async {
      final repo = LogRepository(
        sink: MemoryLogSink(),
        durability: StorageDurability.localFile,
        location: 'dev',
      );
      await repo.open();
      return servicesFor(
        dev,
        HostPlatform.linux,
        repo,
        files: MemoryDataFiles(),
      );
    });
    expect(services!.stageDevelopmentImport, isNull);
    await tester.pumpWidget(HumanOsApp(services: services));
    await settle(tester);
    expect(find.byKey(const ValueKey('your-data-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-development')), findsNothing);
  });
}
