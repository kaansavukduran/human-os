// F005-S4 (G-76, D-053): records of a development build merge into an
// encrypted vault that already holds records, on real files. Matched by
// id: identical bytes skipped, different bytes refuse the whole import,
// new ids appended after the vault's stored lines, which stay byte for
// byte; another profile is refused, never re-attached; a broken chain is
// refused; nothing is written before the staged write, on a refusal or on
// a failed switch, and the previous envelope is kept.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/heartbeat_service.dart';
import 'package:human_health_os/src/data/backup/backup_bundle.dart';
import 'package:human_health_os/src/data/backup/data_files.dart';
import 'package:human_health_os/src/data/backup/data_files_io.dart';
import 'package:human_health_os/src/data/backup/dev_import.dart';
import 'package:human_health_os/src/data/crypto/recovery_key.dart';
import 'package:human_health_os/src/data/crypto/vault_crypto.dart';
import 'package:human_health_os/src/data/local/encrypted_vault.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/data/local/storage_io.dart';
import 'package:human_health_os/src/data/local/vault_envelope.dart';
import 'package:human_health_os/src/data/local/vault_log.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const pass = 'Mavi-Kedi 7 Ağaç Lamba!';
const marker = 'PLAINTEXT-MARKER-QX7 Tahlil raporu';
final t0 = DateTime.utc(2026, 11, 22, 9);

KdfParams cheap() =>
    KdfParams(salt: randomBytes(16), memoryKib: 64, iterations: 1);

Matcher importError(String code) =>
    throwsA(isA<ImportError>().having((e) => e.code, 'code', code));
Matcher backupError(String code) =>
    throwsA(isA<BackupError>().having((e) => e.code, 'code', code));

String canon(HealthRecord r) => jsonEncode(r.toJson());

String bundleOf(String log) => createBackupBundle(
  vaultLogText: log,
  appVersion: '0.1.0+1',
  sourceRevision: 'dev',
  createdAt: t0,
);

void main() {
  late Directory tmp;
  late File devFile;
  late File vaultFile;
  late LogRepository devRepo;
  late HeartbeatService dev;
  late String me;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('hhos-merge-');
    Directory('${tmp.path}/dev').createSync();
    Directory('${tmp.path}/enc').createSync();
    devFile = File('${tmp.path}/dev/vault.hhoslog.jsonl');
    vaultFile = File('${tmp.path}/enc/vault-staging.hhosvault');
    devRepo = LogRepository(
      sink: FileLogSink(devFile),
      durability: StorageDurability.localFile,
      location: devFile.path,
    );
    await devRepo.open();
    dev = HeartbeatService(devRepo);
    me = (await dev.ensureSelfProfile()).id;
    final w = await dev.recordWeightKg(profileId: me, input: '81,5');
    await dev.correctWeightKg(profileId: me, targetId: w.id, input: '81,2');
    await dev.recordDocument(
      profileId: me,
      title: marker,
      nature: DocumentType.labReport,
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  FileDataFiles filesFor(
    EncryptedLogSink sink, {
    Future<void> Function(File file, String to)? rename,
  }) => FileDataFiles(
    dataDir: vaultFile.parent,
    vault: vaultFile,
    target: RestoreTarget.encrypted(sink.open),
    rename: rename,
  );

  EncryptedVault vault() => EncryptedVault(
    raw: FileLogSink(vaultFile),
    location: vaultFile.path,
    newKdf: cheap,
    filesFor: filesFor,
  );

  Future<RestoreOutcome> bringIn(OpenedVault o, StagedImport imp) async =>
      o.files!.restore(
        await stageImportIntoVault(
          imp,
          o.sink,
          now: t0,
          appVersion: 't',
          sourceRevision: 't',
        ),
        now: t0,
      );

  /// An encrypted vault that holds the development records (brought in
  /// while it was empty, F005-S3) and one record of its own, reopened.
  Future<(OpenedVault, HealthRecord)> vaultWithRecords() async {
    final o = await vault().create(
      passphrase: pass,
      recoveryKey: newRecoveryKey(),
    );
    await HeartbeatService(o.repository).ensureSelfProfile();
    await bringIn(
      o,
      stageImport(bundleOf(devFile.readAsStringSync()), now: t0),
    );
    final again = await vault().unlock(pass);
    final own = await HeartbeatService(again.repository)
        .recordWeightKg(profileId: me, input: '80,4');
    return (again, own);
  }

  List<String> keptCopies() => [
    for (final e in vaultFile.parent.listSync())
      if (e.uri.pathSegments.last.contains('.before-restore-'))
        e.uri.pathSegments.last,
  ];

  /// The vault file and nothing staged beside it.
  void unchanged(String before) {
    expect(vaultFile.readAsStringSync(), before);
    expect(
      vaultFile.parent.listSync().map((e) => e.uri.pathSegments.last),
      isNot(contains(endsWith('.restoring'))),
    );
  }

  test('identical records are skipped, new ones appended after the stored '
      'lines (byte for byte unchanged); relaunch and unlock shows the '
      'union; no plaintext; the previous envelope kept', () async {
    final (o, own) = await vaultWithRecords();
    final devNew = await dev.recordWeightKg(profileId: me, input: '79,9');
    final before = vaultFile.readAsStringSync();
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    final plan = await planImport(imp, o.sink);
    expect(plan.intoEmptyVault, isFalse);
    expect(plan.newCount, 1);
    expect(plan.alreadyPresent, 3);
    expect(plan.conflictIds, isEmpty);
    expect(plan.recordsAfter, 5);
    unchanged(before);

    final out = await o.files!.restore(
      await stagePlannedImport(
        plan,
        o.sink,
        now: t0,
        appVersion: 't',
        sourceRevision: 't',
      ),
      now: t0,
    );
    expect(out.records, 5);
    expect(File(out.keptPrevious!).readAsStringSync(), before);
    final stored = vaultFile.readAsStringSync();
    expect(stored.startsWith(before), isTrue, reason: 'nothing rewritten');
    // Envelope header, log header, profile, 3 + 1 records, 1 new.
    expect(stored.split('\n').where((l) => l.isNotEmpty), hasLength(8));
    expect(keptCopies(), hasLength(2), reason: 'an earlier copy never lost');
    for (final s in [marker, 'PLAINTEXT-MARKER', '79,9', '80,4', '"kg"']) {
      expect(stored, isNot(contains(s)), reason: s);
    }

    final again = await vault().unlock(pass);
    expect(again.report.warnings, isEmpty);
    final profiles = await again.repository.profiles();
    expect(profiles.single.id, me, reason: 'the vault SELF profile stays');
    final got = await again.repository.records(me);
    final want = [...await devRepo.records(me), own];
    expect(
      {for (final r in got) r.id: canon(r)},
      {for (final r in want) r.id: canon(r)},
    );
    expect(want.map((r) => r.id), contains(devNew.id));
  });

  test('a file whose records are all here: nothing to bring in, nothing '
      'written', () async {
    final (o, _) = await vaultWithRecords();
    final before = vaultFile.readAsStringSync();
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    final plan = await planImport(imp, o.sink);
    expect(plan.nothingNew, isTrue);
    expect(plan.alreadyPresent, 3);
    await expectLater(
      stagePlannedImport(
        plan,
        o.sink,
        now: t0,
        appVersion: 't',
        sourceRevision: 't',
      ),
      importError('IMPORT_NOTHING_NEW'),
    );
    unchanged(before);
  });

  test('the same id with other bytes refuses the whole import, new records '
      'included; neither copy is overwritten', () async {
    final (o, _) = await vaultWithRecords();
    await dev.recordWeightKg(profileId: me, input: '79,9');
    final before = vaultFile.readAsStringSync();
    // The first record, saved a second later: same id, other bytes.
    final lines = devFile.readAsStringSync().split('\n');
    final i = lines.indexWhere((l) => l.contains('"op":"record.append"'));
    final data = ((jsonDecode(lines[i]) as Map)['data']! as Map)
        .cast<String, Object?>();
    data['recorded_at'] = DateTime.parse(data['recorded_at']! as String)
        .add(const Duration(seconds: 1))
        .toUtc()
        .toIso8601String();
    lines[i] = encodeOp('record.append', data);
    final imp = stageImport(bundleOf(lines.join('\n')), now: t0);
    final plan = await planImport(imp, o.sink);
    expect(plan.blocked, isTrue);
    expect(plan.conflictIds, [data['id']]);
    expect(plan.newCount, 1);
    expect(plan.alreadyPresent, 2);
    await expectLater(
      stagePlannedImport(
        plan,
        o.sink,
        now: t0,
        appVersion: 't',
        sourceRevision: 't',
      ),
      importError('IMPORT_CONFLICT'),
    );
    await expectLater(bringIn(o, imp), importError('IMPORT_CONFLICT'));
    unchanged(before);
    final again = await vault().unlock(pass);
    final kept = (await again.repository.records(me))
        .firstWhere((r) => r.id == data['id']);
    expect(
      kept.recordedAt,
      isNot(DateTime.parse(data['recorded_at']! as String)),
    );
  });

  test('records of another profile are refused, never re-attached (a '
      "record's profile id is part of its bytes)", () async {
    final o = await vault().create(
      passphrase: pass,
      recoveryKey: newRecoveryKey(),
    );
    final svc = HeartbeatService(o.repository);
    await svc.recordWeightKg(
      profileId: (await svc.ensureSelfProfile()).id,
      input: '70',
    );
    final before = vaultFile.readAsStringSync();
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    await expectLater(
      planImport(imp, o.sink),
      importError('IMPORT_PROFILE_DIFFERENT'),
    );
    await expectLater(bringIn(o, imp), importError('IMPORT_PROFILE_DIFFERENT'));
    unchanged(before);
  });

  test('a correction whose target is in neither set is refused (broken '
      'chain); nothing written', () async {
    final (o, _) = await vaultWithRecords();
    final before = vaultFile.readAsStringSync();
    final w = await dev.recordWeightKg(profileId: me, input: '79,0');
    final corr = await dev.correctWeightKg(
      profileId: me,
      targetId: w.id,
      input: '81,0',
    );
    final m = corr.toJson()
      ..['supersedes_id'] = 'b2f7c1c4-0000-4000-8000-00000000dead';
    final export = {
      'format': 'hhos-export',
      'format_version': 1,
      'exported_at': t0.toIso8601String(),
      'app_version': 't',
      'encryption': 'none',
      'profile': {'id': me, 'type': 'self'},
      'record_count': 1,
      'records': [m],
      'timeline': <Object?>[],
    };
    expect(
      () => stageImport(jsonEncode(export), now: t0),
      importError('IMPORT_CHAIN_BROKEN'),
    );
    unchanged(before);
    expect(o.repository.writable, isTrue);
  });

  test('order: new records follow the timeline rules, never the order in '
      'the file; corrections after what they correct', () async {
    final (o, own) = await vaultWithRecords();
    final a = await dev.recordWeightKg(profileId: me, input: '79,0');
    final b = await dev.correctWeightKg(
      profileId: me,
      targetId: a.id,
      input: '78,8',
    );
    final recs = await devRepo.records(me);
    final export = {
      'format': 'hhos-export',
      'format_version': 1,
      'exported_at': t0.toIso8601String(),
      'app_version': 't',
      'encryption': 'none',
      'profile': {'id': me, 'type': 'self'},
      'record_count': recs.length,
      // Newest first in the file: the correction before its target.
      'records': [for (final r in recs.reversed) r.toJson()],
      'timeline': <Object?>[],
    };
    final imp = stageImport(jsonEncode(export), now: t0);
    final plan = await planImport(imp, o.sink);
    expect(plan.newCount, 2);
    final ids = [
      for (final l in plan.newLines)
        ((jsonDecode(l) as Map)['data']! as Map)['id'],
    ];
    expect(ids, [a.id, b.id]);
    await o.files!.restore(
      await stagePlannedImport(
        plan,
        o.sink,
        now: t0,
        appVersion: 't',
        sourceRevision: 't',
      ),
      now: t0,
    );
    final again = await vault().unlock(pass);
    final got = await again.repository.records(me);
    expect(got, hasLength(6));
    String shape(Iterable<HealthRecord> rs) => [
      for (final e in buildTimeline(rs, includeHidden: true))
        '${e.rootId}:${e.status.name}:${e.heads.map((h) => h.id).join(',')}',
    ].join('|');
    expect(shape(got), shape(got.reversed), reason: 'order-free');
    final current = await HeartbeatService(again.repository).currentWeights(me);
    expect(current.map((r) => r.id), containsAll([b.id, own.id]));
    expect(current.map((r) => r.id), isNot(contains(a.id)));
  });

  test('a vault that changed after the preview (a record saved meanwhile) '
      'is never replaced: the record stays, nothing staged is left', () async {
    final (o, _) = await vaultWithRecords();
    await dev.recordWeightKg(profileId: me, input: '79,9');
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    final plan = await planImport(imp, o.sink);
    final staged = await stagePlannedImport(
      plan,
      o.sink,
      now: t0,
      appVersion: 't',
      sourceRevision: 't',
    );
    final saved = await HeartbeatService(o.repository)
        .recordWeightKg(profileId: me, input: '77,7');
    final after = vaultFile.readAsStringSync();
    await expectLater(
      o.files!.restore(staged, now: t0),
      backupError('IMPORT_VAULT_CHANGED'),
    );
    await expectLater(
      stagePlannedImport(
        plan,
        o.sink,
        now: t0,
        appVersion: 't',
        sourceRevision: 't',
      ),
      importError('IMPORT_VAULT_CHANGED'),
    );
    unchanged(after);
    final again = await vault().unlock(pass);
    expect(
      (await again.repository.records(me)).map((r) => r.id),
      contains(saved.id),
    );
  });

  test('a switch that fails changes nothing and keeps no stray copy; a '
      'cancelled preview (a plan never staged) writes nothing', () async {
    final (o, _) = await vaultWithRecords();
    await dev.recordWeightKg(profileId: me, input: '79,9');
    final before = vaultFile.readAsStringSync();
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    await planImport(imp, o.sink); // the preview; then Cancel
    unchanged(before);
    final failing = filesFor(
      o.sink,
      rename: (f, to) async => throw const FileSystemException('busy'),
    );
    await expectLater(
      failing.restore(
        await stageImportIntoVault(
          imp,
          o.sink,
          now: t0,
          appVersion: 't',
          sourceRevision: 't',
        ),
        now: t0,
      ),
      backupError('RESTORE_NOT_SWITCHED'),
    );
    unchanged(before);
    expect(
      keptCopies(),
      hasLength(1),
      reason:
          'the duplicate kept copy is dropped once the vault is checked; '
          'the earlier one stays',
    );
  });

  test('a vault holding an entry that cannot be read is not merged into '
      '(a duplicate could not be ruled out)', () async {
    final (o, _) = await vaultWithRecords();
    vaultFile.writeAsStringSync(
      '{"s":99,"n":"AAAAAAAAAAAAAAAA","c":"AAAA"}\n',
      mode: FileMode.append,
    );
    final before = vaultFile.readAsStringSync();
    final imp = stageImport(bundleOf(devFile.readAsStringSync()), now: t0);
    await expectLater(
      planImport(imp, o.sink),
      importError('IMPORT_TARGET_UNREADABLE'),
    );
    unchanged(before);
  });
}
