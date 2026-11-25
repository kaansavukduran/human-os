// F005-S4 (G-76, D-053) through the screens: an encrypted vault that holds
// records still offers "Bring in records from the development build"; the
// preview counts new records, records already here (skipped) and
// conflicts (blocking); a conflict, a file with nothing new and records of
// another profile are refused in words, with one way out; nothing changes
// before the confirmation. EN and TR, and 320 dp at 2x text.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/l10n/strings.dart';

import 'f005s2_web_restore_test.dart' show FakePicker;
import 'f005s3_dev_import_test.dart' show FilesOn, enabled, launch, reveal;
import 'f006_vault_gate_test.dart'
    show
        Disk,
        LinkedFiles,
        createThroughGate,
        latest,
        pass,
        saveWeight,
        tapKey,
        textOf,
        type;

/// A development build kept in memory across one test.
class DevBuild {
  DevBuild._(this.sink, this.svc, this.me);

  final MemoryLogSink sink;
  final HeartbeatService svc;
  final String me;

  static Future<DevBuild> start() async {
    final sink = MemoryLogSink();
    final repo = LogRepository(
      sink: sink,
      durability: StorageDurability.localFile,
      location: 'dev',
    );
    await repo.open();
    final svc = HeartbeatService(repo);
    final me = (await svc.ensureSelfProfile()).id;
    final w = await svc.recordWeightKg(profileId: me, input: '81,5');
    await svc.correctWeightKg(profileId: me, targetId: w.id, input: '81,2');
    return DevBuild._(sink, svc, me);
  }

  Future<String> backup([String Function(String log)? edit]) async {
    final log = (await sink.read())!;
    return createBackupBundle(
      vaultLogText: edit == null ? log : edit(log),
      appVersion: '0.1.0+1',
      sourceRevision: 'dev',
      createdAt: DateTime.utc(2026, 11, 22, 8),
    );
  }
}

/// The first record of [log] saved a second later: same id, other bytes.
String conflicting(String log) {
  final lines = log.split('\n');
  final i = lines.indexWhere((l) => l.contains('"op":"record.append"'));
  final data = ((jsonDecode(lines[i]) as Map)['data']! as Map)
      .cast<String, Object?>();
  data['recorded_at'] = DateTime.parse(data['recorded_at']! as String)
      .add(const Duration(seconds: 1))
      .toUtc()
      .toIso8601String();
  lines[i] = encodeOp('record.append', data);
  return lines.join('\n');
}

/// R026: [log] with its last record (a correction) given another id, so
/// the file corrects the same entry as the vault but with another record.
String competing(String log) {
  final lines = log.split('\n');
  final i = lines.lastIndexWhere((l) => l.contains('"op":"record.append"'));
  final data = ((jsonDecode(lines[i]) as Map)['data']! as Map)
      .cast<String, Object?>();
  expect(data['supersedes_id'], isNotNull);
  data['id'] = 'b2f7c1c4-0000-4000-8000-00000000c0de';
  lines[i] = encodeOp('record.append', data);
  return lines.join('\n');
}

/// U040: data files whose switch fails with [refusal] once it is set: a
/// record saved while the import was being prepared, or a copy that could
/// not be moved into place.
class SwitchRefused extends LinkedFiles {
  SwitchRefused(super.raw, super.sink);

  static BackupError? refusal;

  @override
  Future<RestoreOutcome> restore(
    StagedRestore staged, {
    required DateTime now,
    FutureOr<void> Function()? beforeSwitch,
  }) async {
    final refused = refusal;
    if (refused == null) {
      return super.restore(staged, now: now, beforeSwitch: beforeSwitch);
    }
    await beforeSwitch?.call();
    throw refused;
  }
}

/// An encrypted vault holding the development records (brought in while
/// empty), reopened and unlocked.
Future<void> vaultWithDevRecords(
  WidgetTester tester,
  Disk disk,
  FakePicker picker, {
  Locale? locale,
  Size size = const Size(1280, 2600),
  double textScale = 1,
  FilesOn? files,
}) async {
  await launch(tester, disk, picker);
  await createThroughGate(tester);
  await tapKey(tester, 'import-development');
  await tapKey(tester, 'import-understand');
  await tapKey(tester, 'confirm-import');
  await launch(
    tester,
    disk,
    picker,
    locale: locale,
    size: size,
    textScale: textScale,
    files: files,
  );
  await type(tester, 'gate-passphrase', pass);
  await tapKey(tester, 'gate-unlock');
}

const enCountsTwoNew =
    'New, to be added: 1\n'
    'Already in this vault, skipped: 2\n'
    'Different from the record in this vault, blocking: 0';

void main() {
  testWidgets('a vault with records: preview counts new and skipped, '
      'confirmation required, nothing written before it; after a restart '
      'the union is there', (tester) async {
    final dev = (await tester.runAsync(DevBuild.start))!;
    final picker = FakePicker((await tester.runAsync(dev.backup))!);
    final disk = Disk();
    await vaultWithDevRecords(tester, disk, picker);
    expect(latest(tester), '81.2 kg');
    expect(
      textOf(tester, 'import-explain'),
      startsWith('If you also kept records in the development build'),
    );

    await tester.runAsync(
      () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
    );
    picker.text = (await tester.runAsync(dev.backup))!;
    final before = disk.raw.text!;
    await tapKey(tester, 'import-development');
    expect(textOf(tester, 'import-preview-title'), 'Bring these records in?');
    expect(textOf(tester, 'import-counts'), enCountsTwoNew);
    expect(
      textOf(tester, 'import-preview-text'),
      contains('It holds 3 records and 1 profile.'),
    );
    expect(find.byKey(const ValueKey('import-warning-text')), findsOneWidget);
    expect(enabled(tester, 'confirm-import'), isFalse);
    expect(disk.raw.text, before);

    await tapKey(tester, 'import-understand');
    await tapKey(tester, 'confirm-import');
    expect(
      textOf(tester, 'data-message'),
      startsWith(
        'New records added, encrypted in this vault: 1. Already here, '
        'skipped: 2. Close and reopen Human OS',
      ),
    );
    expect(disk.raw.text!.startsWith(before), isTrue, reason: 'appended');
    expect(disk.raw.text, isNot(contains('79,9')));

    await launch(tester, disk, picker);
    await type(tester, 'gate-passphrase', pass);
    await tapKey(tester, 'gate-unlock');
    expect(latest(tester), '79.9 kg');
  });

  testWidgets('a conflict blocks the whole import: counts, the reason in '
      'words, one button; nothing written', (tester) async {
    final dev = (await tester.runAsync(DevBuild.start))!;
    final picker = FakePicker((await tester.runAsync(dev.backup))!);
    final disk = Disk();
    await vaultWithDevRecords(tester, disk, picker);
    await tester.runAsync(
      () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
    );
    picker.text = (await tester.runAsync(() => dev.backup(conflicting)))!;
    final before = disk.raw.text;
    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'import-preview-title'),
      'These records cannot be brought in',
    );
    expect(
      textOf(tester, 'import-counts'),
      'New, to be added: 1\n'
      'Already in this vault, skipped: 1\n'
      'Different from the record in this vault, blocking: 1',
    );
    const reason =
        'Records in the file with the same identity as a record in this '
        'vault but different content: 1. Human OS never overwrites either one, '
        'so nothing is brought in. Keep the version you want in one place '
        '(correct it there), make a new backup or export, and try again. '
        'Nothing was changed.';
    expect(textOf(tester, 'import-stop-text'), reason);
    expect(find.byKey(const ValueKey('confirm-import')), findsNothing);
    expect(find.byKey(const ValueKey('import-understand')), findsNothing);
    await tapKey(tester, 'close-import');
    expect(textOf(tester, 'data-message'), reason);
    expect(disk.raw.text, before);
  });

  testWidgets('nothing new, cancel, and records of another profile change '
      'nothing and say why', (tester) async {
    final dev = (await tester.runAsync(DevBuild.start))!;
    final picker = FakePicker((await tester.runAsync(dev.backup))!);
    final disk = Disk();
    await vaultWithDevRecords(tester, disk, picker);
    final before = disk.raw.text;

    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'import-stop-text'),
      'Every record in this file is already in this vault, exactly as '
      'saved. There is nothing to bring in. Nothing was changed.',
    );
    await tapKey(tester, 'close-import');
    expect(disk.raw.text, before);

    await tester.runAsync(
      () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
    );
    picker.text = (await tester.runAsync(dev.backup))!;
    await tapKey(tester, 'import-development');
    await tapKey(tester, 'import-understand');
    await tapKey(tester, 'cancel-import');
    expect(
      textOf(tester, 'data-message'),
      'Nothing was brought in. Nothing was changed.',
    );
    expect(disk.raw.text, before);

    // A vault of its own with a record: another SELF profile.
    final other = Disk();
    await launch(tester, other, picker);
    await createThroughGate(tester);
    await saveWeight(tester, '70');
    final otherBefore = other.raw.text;
    await tapKey(tester, 'import-development');
    expect(find.byKey(const ValueKey('import-preview')), findsNothing);
    expect(
      textOf(tester, 'data-message'),
      startsWith(
        'The records in this file belong to a different profile than the '
        'one in this vault. A record keeps the profile it was saved under, '
        'and moving it would rewrite it, which Human OS never does.',
      ),
    );
    expect(other.raw.text, otherBefore);
  });

  testWidgets('Turkish: the entry, the counts and the refusals', (
    tester,
  ) async {
    final dev = (await tester.runAsync(DevBuild.start))!;
    final picker = FakePicker((await tester.runAsync(dev.backup))!);
    final disk = Disk();
    await vaultWithDevRecords(tester, disk, picker, locale: const Locale('tr'));
    expect(
      textOf(tester, 'import-explain'),
      startsWith('Geliştirme sürümünde de kayıt tuttuysan'),
    );
    await tester.runAsync(
      () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
    );
    picker.text = (await tester.runAsync(dev.backup))!;
    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'import-counts'),
      'Yeni, eklenecek: 1\n'
      'Bu kasada zaten var, atlanacak: 2\n'
      'Bu kasadakinden farklı, engelliyor: 0',
    );
    expect(find.text('Getir'), findsOneWidget);
    await tapKey(tester, 'cancel-import');

    picker.text = (await tester.runAsync(() => dev.backup(conflicting)))!;
    await tapKey(tester, 'import-development');
    expect(textOf(tester, 'import-preview-title'), 'Bu kayıtlar getirilemez');
    expect(
      textOf(tester, 'import-stop-text'),
      startsWith(
        'Dosyada bu kasadaki bir kayıtla aynı kimliğe ama farklı içeriğe '
        'sahip kayıt sayısı: 1.',
      ),
    );
    expect(find.text('Kapat'), findsOneWidget);
    await tapKey(tester, 'close-import');

    final other = Disk();
    await launch(tester, other, picker, locale: const Locale('tr'));
    await createThroughGate(tester);
    await saveWeight(tester, '70');
    await tapKey(tester, 'import-development');
    expect(
      textOf(tester, 'data-message'),
      startsWith(
        'Bu dosyadaki kayıtlar bu kasadakinden farklı bir profile ait.',
      ),
    );
  });

  for (final tr in [false, true]) {
    testWidgets('320 dp at 2x text (${tr ? 'TR' : 'EN'}): the merge entry, '
        'the counts and a refusal fit; the actions can be reached', (
      tester,
    ) async {
      final dev = (await tester.runAsync(DevBuild.start))!;
      final picker = FakePicker((await tester.runAsync(dev.backup))!);
      final disk = Disk();
      await vaultWithDevRecords(
        tester,
        disk,
        picker,
        locale: tr ? const Locale('tr') : const Locale('en'),
        size: const Size(320, 4000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, 'import-development');
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
      );
      picker.text = (await tester.runAsync(() => dev.backup(conflicting)))!;
      await tapKey(tester, 'import-development');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('import-counts')), findsOneWidget);
      await tapKey(tester, 'close-import');
      expect(tester.takeException(), isNull);

      picker.text = (await tester.runAsync(dev.backup))!;
      await tapKey(tester, 'import-development');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'import-understand');
      await tapKey(tester, 'confirm-import');
      expect(tester.takeException(), isNull);
      expect(
        textOf(tester, 'data-message'),
        startsWith(
          tr
              ? 'Bu kasaya şifreli olarak eklenen yeni kayıt: 1.'
              : 'New records added, encrypted in this vault: 1.',
        ),
      );
    });
  }

  for (final tr in [false, true]) {
    testWidgets('R026 (${tr ? 'TR' : 'EN'}, 320 dp at 2x text): a correction '
        'that competes with one this vault already holds is counted and '
        'blocks the import in words; one button; nothing written', (
      tester,
    ) async {
      final dev = (await tester.runAsync(DevBuild.start))!;
      // The development build corrects its correction once more; the vault
      // receives that correction (brought in while empty).
      await tester.runAsync(() async {
        final head = (await dev.svc.currentWeights(dev.me)).single;
        await dev.svc.correctWeightKg(
          profileId: dev.me,
          targetId: head.id,
          input: '81,0',
        );
      });
      final picker = FakePicker((await tester.runAsync(dev.backup))!);
      final disk = Disk();
      await vaultWithDevRecords(
        tester,
        disk,
        picker,
        locale: tr ? const Locale('tr') : const Locale('en'),
        size: const Size(320, 4000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      // A file whose last correction is another record of the same entry.
      picker.text = (await tester.runAsync(() => dev.backup(competing)))!;
      final before = disk.raw.text;
      await reveal(tester, 'import-development');
      await tapKey(tester, 'import-development');
      expect(tester.takeException(), isNull);
      expect(
        textOf(tester, 'import-preview-title'),
        tr ? 'Bu kayıtlar getirilemez' : 'These records cannot be brought in',
      );
      expect(
        textOf(tester, 'import-counts'),
        tr
            ? 'Yeni, eklenecek: 1\n'
                  'Bu kasada zaten var, atlanacak: 2\n'
                  'Bu kasadakinden farklı, engelliyor: 0\n'
                  'Bu kasada başka türlü düzeltilmiş ya da kaldırılmış bir '
                  'kaydı düzeltiyor ya da kaldırıyor, engelliyor: 1'
            : 'New, to be added: 1\n'
                  'Already in this vault, skipped: 2\n'
                  'Different from the record in this vault, blocking: 0\n'
                  'Correcting or removing a record this vault corrected or '
                  'removed another way, blocking: 1',
      );
      final reason = tr
          ? 'Bu kasada başka türlü düzeltilmiş ya da kaldırılmış bir kaydı '
                'dosyada da düzelten ya da kaldıran kayıt sayısı: 1. Human OS '
                'bir kayda yapılan iki değişiklik arasında asla seçim yapmaz; '
                'bu yüzden hiçbir şey getirilmez. Kayıtlar hiç silinmez; bu '
                'yüzden bu dosya buraya getirilemez. Bundan sonra kayıtları '
                'yalnız tek bir yerden getir. Hiçbir şey değişmedi.'
          : 'Records in the file that correct or remove a record this vault '
                'already corrected or removed another way: 1. Human OS never '
                'chooses between two changes to one record, so nothing is '
                'brought in. Records are never deleted, so this file cannot '
                'come in here. From now on, bring in records from only one '
                'place. Nothing was changed.';
      expect(textOf(tester, 'import-stop-text'), reason);
      expect(find.byKey(const ValueKey('confirm-import')), findsNothing);
      expect(find.byKey(const ValueKey('import-understand')), findsNothing);
      expect(find.text(tr ? 'Kapat' : 'Close'), findsOneWidget);
      await tapKey(tester, 'close-import');
      expect(tester.takeException(), isNull);
      expect(textOf(tester, 'data-message'), reason);
      expect(disk.raw.text, before);
    });
  }
  for (final tr in [false, true]) {
    testWidgets('U040 (${tr ? 'TR' : 'EN'}, 320 dp at 2x text): an import '
        'whose switch is refused because a record was saved meanwhile says '
        'the records were not brought in (not "restore"), with no advice to '
        'try again; nothing written', (tester) async {
      final dev = (await tester.runAsync(DevBuild.start))!;
      final picker = FakePicker((await tester.runAsync(dev.backup))!);
      final disk = Disk();
      SwitchRefused.refusal = null;
      addTearDown(() => SwitchRefused.refusal = null);
      await vaultWithDevRecords(
        tester,
        disk,
        picker,
        locale: tr ? const Locale('tr') : const Locale('en'),
        size: const Size(320, 4000),
        textScale: 2,
        files: SwitchRefused.new,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
      );
      picker.text = (await tester.runAsync(dev.backup))!;
      final before = disk.raw.text;
      SwitchRefused.refusal = const BackupError(
        'RESTORE_NOT_SWITCHED',
        vaultChangedBeforeSwitch,
      );
      await reveal(tester, 'import-development');
      await tapKey(tester, 'import-development');
      await tapKey(tester, 'import-understand');
      await tapKey(tester, 'confirm-import');
      expect(tester.takeException(), isNull);
      final message = textOf(tester, 'data-message');
      expect(
        message,
        tr
            ? 'Kayıtlar getirilmedi: hazırlanırken bir kayıt kaydedildi ve '
                  'Human OS onun üzerine asla yazmaz. Diskte hiçbir şey '
                  'değişmedi. Human OS yeniden başlayana kadar kayıt '
                  'durduruldu.'
            : 'The records were not brought in: a record was saved while '
                  'they were being prepared, and Human OS never replaces it. '
                  'Nothing was changed on disk. Saving stays paused until '
                  'Human OS restarts.',
      );
      expect(message, isNot(contains(tr ? 'Geri yükleme' : 'restore')));
      expect(message, isNot(contains(tr ? 'yeniden dene' : 'try again')));
      expect(disk.raw.text, before);
    });
  }
  for (final tr in [false, true]) {
    testWidgets('U040 (${tr ? 'TR' : 'EN'}, 320 dp at 2x text): an import '
        'whose updated copy could not be moved into place says the records '
        'could not be brought in, never "restored copy"', (tester) async {
      final dev = (await tester.runAsync(DevBuild.start))!;
      final picker = FakePicker((await tester.runAsync(dev.backup))!);
      final disk = Disk();
      SwitchRefused.refusal = null;
      addTearDown(() => SwitchRefused.refusal = null);
      await vaultWithDevRecords(
        tester,
        disk,
        picker,
        locale: tr ? const Locale('tr') : const Locale('en'),
        size: const Size(320, 4000),
        textScale: 2,
        files: SwitchRefused.new,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => dev.svc.recordWeightKg(profileId: dev.me, input: '79,9'),
      );
      picker.text = (await tester.runAsync(dev.backup))!;
      SwitchRefused.refusal = const BackupError('RESTORE_SWITCH_FAILED', '');
      await reveal(tester, 'import-development');
      await tapKey(tester, 'import-development');
      await tapKey(tester, 'import-understand');
      await tapKey(tester, 'confirm-import');
      expect(tester.takeException(), isNull);
      final message = textOf(tester, 'data-message');
      expect(
        message,
        tr
            ? 'Kayıtlar getirilemedi: güncellenen veri dosyası yerine '
                  'taşınamadı. Önceki veri dosyası eski yerinde. Bir şey '
                  'kaydetmeden önce uygulamayı yeniden başlat.'
            : 'The records could not be brought in: the updated data file '
                  'could not be moved into place. The previous data file is '
                  'back where it was. Restart Human OS before saving anything.',
      );
      // Every variant, on disk and in the browser, names the import.
      final s = S(tr ? AppLang.tr : AppLang.en);
      final variants = [
        message,
        s.backupError('RESTORE_SWITCH_FAILED', 'kept.copy', true),
        s.browserRestoreFailed('RESTORE_SWITCH_FAILED', '', importing: true)!,
        s.browserRestoreFailed(
          'RESTORE_SWITCH_FAILED',
          'kept.copy',
          importing: true,
        )!,
      ];
      for (final v in variants) {
        expect(
          v,
          startsWith(
            tr
                ? 'Kayıtlar getirilemedi:'
                : 'The records could not be brought in:',
          ),
        );
        expect(
          v,
          isNot(contains(tr ? 'geri yüklenen kopya' : 'restored copy')),
        );
      }
      expect(variants[1], contains('kept.copy'));
      expect(variants[3], contains('"kept.copy"'));
    });
  }
}
