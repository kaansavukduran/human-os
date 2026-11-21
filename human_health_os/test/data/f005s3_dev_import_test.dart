// F005-S3 (G-76, D-050): records of a development build enter an empty
// encrypted vault through the staged gate: same ids, same payload bytes,
// same lineage; the vault file holds no plaintext; a relaunch and unlock
// shows them; every refusal writes nothing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/application/export.dart';
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
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';

const pass = 'Mavi-Kedi 7 Ağaç Lamba!';
const marker = 'PLAINTEXT-MARKER-QX7 Tahlil raporu';
final t0 = DateTime.utc(2026, 11, 20, 9);

KdfParams cheap() =>
    KdfParams(salt: randomBytes(16), memoryKib: 64, iterations: 1);

Matcher importError(String code) =>
    throwsA(isA<ImportError>().having((e) => e.code, 'code', code));
Matcher backupError(String code) =>
    throwsA(isA<BackupError>().having((e) => e.code, 'code', code));

String canon(HealthRecord r) => jsonEncode(r.toJson());

void main() {
  late Directory tmp;
  late File devFile;
  late File vaultFile;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hhos-import-');
    Directory('${tmp.path}/dev').createSync();
    Directory('${tmp.path}/enc').createSync();
    devFile = File('${tmp.path}/dev/vault.hhoslog.jsonl');
    vaultFile = File('${tmp.path}/enc/vault-staging.hhosvault');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A development vault with a weight, its correction and a document whose
  /// title is the plaintext marker. Returns the dev records and log text.
  Future<(List<HealthRecord>, String)> devVault() async {
    final repo = LogRepository(
      sink: FileLogSink(devFile),
      durability: StorageDurability.localFile,
      location: devFile.path,
    );
    await repo.open();
    final svc = HeartbeatService(repo);
    final me = (await svc.ensureSelfProfile()).id;
    final w = await svc.recordWeightKg(profileId: me, input: '81,5');
    await svc.correctWeightKg(profileId: me, targetId: w.id, input: '81,2');
    await svc.recordDocument(
      profileId: me,
      title: marker,
      nature: DocumentType.labReport,
    );
    return (await repo.records(me), devFile.readAsStringSync());
  }

  EncryptedVault vault() => EncryptedVault(
    raw: FileLogSink(vaultFile),
    location: vaultFile.path,
    newKdf: cheap,
    filesFor: (sink) => FileDataFiles(
      dataDir: vaultFile.parent,
      vault: vaultFile,
      target: RestoreTarget.encrypted(sink.open),
    ),
  );

  /// A new encrypted vault as the app leaves it after creation: a SELF
  /// profile and no records.
  Future<OpenedVault> freshVault() async {
    final o = await vault().create(
      passphrase: pass,
      recoveryKey: newRecoveryKey(),
    );
    await HeartbeatService(o.repository).ensureSelfProfile();
    return o;
  }

  Future<RestoreOutcome> bringIn(OpenedVault o, StagedImport imp) async {
    final staged = await stageImportIntoVault(
      imp,
      o.sink,
      now: t0,
      appVersion: 't',
      sourceRevision: 't',
    );
    return o.files!.restore(staged, now: t0);
  }

  Future<void> expectSameAfterUnlock(List<HealthRecord> dev) async {
    final again = await vault().unlock(pass);
    final profiles = await again.repository.profiles();
    expect(profiles, hasLength(1), reason: 'only the imported SELF profile');
    expect(profiles.single.id, dev.first.profileId);
    final got = await again.repository.records(profiles.single.id);
    expect(
      {for (final r in got) r.id: canon(r)},
      {for (final r in dev) r.id: canon(r)},
    );
    final correction = got.firstWhere((r) => r.supersedesId != null);
    expect(correction.supersedesId, dev.first.id, reason: 'same lineage');
    // The app shows them: the SELF profile it picks is the imported one.
    final svc = HeartbeatService(again.repository);
    expect((await svc.ensureSelfProfile()).id, dev.first.profileId);
    expect(await svc.currentWeights(dev.first.profileId), hasLength(1));
  }

  test('a development backup enters a fresh encrypted vault: same ids and '
      'payload bytes, no plaintext in the vault file, the previous envelope '
      'kept; relaunch and unlock shows them', () async {
    final (dev, log) = await devVault();
    final bundle = createBackupBundle(
      vaultLogText: log,
      appVersion: '0.1.0+1',
      sourceRevision: 'dev',
      createdAt: t0,
    );
    final imp = stageImport(bundle, now: t0);
    expect(imp.source, ImportSource.developmentBackup);
    expect(imp.recordCount, 3);
    expect(imp.profileCount, 1);
    // Each record line is the development log's line, byte for byte.
    final devLines = log.split('\n');
    for (final l in imp.lines.where((l) => l.contains('record.append'))) {
      expect(devLines, contains(l));
    }
    final o = await freshVault();
    final before = vaultFile.readAsStringSync();
    final out = await bringIn(o, imp);
    expect(out.keptPrevious, isNotNull);
    expect(File(out.keptPrevious!).readAsStringSync(), before);
    final stored = vaultFile.readAsStringSync();
    for (final s in [
      marker,
      'PLAINTEXT-MARKER',
      '81,5',
      '81,2',
      '"kg"',
      'body.weight',
    ]) {
      expect(stored, isNot(contains(s)), reason: s);
    }
    expect(devFile.readAsStringSync(), log, reason: 'source never changed');
    await expectSameAfterUnlock(dev);
  });

  test('a JSON export enters a fresh encrypted vault the same way', () async {
    final (dev, _) = await devVault();
    final repo = LogRepository(
      sink: FileLogSink(devFile),
      durability: StorageDurability.localFile,
      location: devFile.path,
    );
    await repo.open();
    final self = (await repo.profiles()).single;
    final json = exportRecordsJson(
      profile: self,
      records: dev,
      exportedAt: t0,
      appVersion: '0.1.0+1',
    );
    final imp = stageImport(json, now: t0);
    expect(imp.source, ImportSource.jsonExport);
    expect(imp.recordCount, 3);
    // The correction follows what it corrects.
    final order = imp.recordIds;
    final corr = dev.firstWhere((r) => r.supersedesId != null);
    expect(order.indexOf(corr.supersedesId!), lessThan(order.indexOf(corr.id)));
    final o = await freshVault();
    await bringIn(o, imp);
    expect(vaultFile.readAsStringSync(), isNot(contains('PLAINTEXT-MARKER')));
    await expectSameAfterUnlock(dev);
  });

  group('refusals write nothing', () {
    late String bundle;
    late OpenedVault o;
    late String before;
    setUp(() async {
      final (_, log) = await devVault();
      bundle = createBackupBundle(
        vaultLogText: log,
        appVersion: '0.1.0+1',
        sourceRevision: 'dev',
        createdAt: t0,
      );
      o = await freshVault();
      before = vaultFile.readAsStringSync();
    });

    void unchanged() {
      expect(vaultFile.readAsStringSync(), before);
      expect(
        vaultFile.parent.listSync().map((e) => e.uri.pathSegments.last),
        isNot(contains(startsWith('vault-staging.hhosvault.'))),
      );
    }

    test('a vault that holds a record', () async {
      final svc = HeartbeatService(o.repository);
      await svc.recordWeightKg(
        profileId: (await svc.ensureSelfProfile()).id,
        input: '70',
      );
      before = vaultFile.readAsStringSync();
      await expectLater(
        bringIn(o, stageImport(bundle, now: t0)),
        importError('IMPORT_TARGET_HAS_RECORDS'),
      );
      unchanged();
    });

    test('a newer record schema', () async {
      final d = (jsonDecode(bundle) as Map).cast<String, Object?>();
      final lines = (d['payload']! as String).split('\n');
      final i = lines.indexWhere((l) => l.contains('record.append'));
      lines[i] = lines[i].replaceFirst(
        RegExp(r'"schema_version":\d+'),
        '"schema_version":999',
      );
      final payload = lines.join('\n');
      final m = (d['manifest']! as Map).cast<String, Object?>()
        ..['payload_sha256'] = sha256Hex(payload)
        ..['payload_bytes'] = utf8.encode(payload).length;
      final newer = jsonEncode({'manifest': m, 'payload': payload});
      expect(
        () => stageImport(newer, now: t0),
        throwsA(
          isA<BackupError>()
              .having((e) => e.code, 'code', 'VAULT_INCOMPATIBLE')
              .having((e) => e.message, 'detail', 'RECORD_SCHEMA_NEWER'),
        ),
      );
      unchanged();
    });

    test('a bad checksum', () {
      final d = (jsonDecode(bundle) as Map).cast<String, Object?>();
      d['payload'] = (d['payload']! as String).replaceFirst('81,5', '91,5');
      expect(
        () => stageImport(jsonEncode(d), now: t0),
        backupError('DIGEST_MISMATCH'),
      );
      unchanged();
    });

    test('an encrypted backup offered as a development one', () async {
      final both = await o.sink.readBoth();
      final enc = createEncryptedBackupBundle(
        envelopeText: both.raw,
        innerLogText: both.opened.inner,
        appVersion: 't',
        sourceRevision: 't',
        createdAt: t0,
      );
      expect(
        () => stageImport(enc, now: t0),
        importError('IMPORT_ENCRYPTED_BACKUP'),
      );
      unchanged();
    });

    test('an export that does not match its own count, a non-SELF profile, '
        'a record not stored as this app writes it, a file of something '
        'else, an empty vault backup', () async {
      final d = (jsonDecode(bundle) as Map).cast<String, Object?>();
      final lines = (d['payload']! as String).split('\n');
      final records = [
        for (final l in lines)
          if (l.contains('record.append'))
            ((jsonDecode(l) as Map)['data']! as Map).cast<String, Object?>(),
      ];
      final profileId = records.first['profile_id'];
      Map<String, Object?> export(List<Object?> recs, {int? count}) => {
        'format': 'hhos-export',
        'format_version': 1,
        'exported_at': t0.toIso8601String(),
        'app_version': 't',
        'encryption': 'none',
        'profile': {'id': profileId, 'type': 'self'},
        'record_count': count ?? recs.length,
        'records': recs,
        'timeline': <Object?>[],
      };
      expect(stageImport(jsonEncode(export(records)), now: t0).recordCount, 3);
      expect(
        () => stageImport(jsonEncode(export(records, count: 4)), now: t0),
        importError('IMPORT_EXPORT_DAMAGED'),
      );
      expect(
        () => stageImport(
          jsonEncode(
            export(records)
              ..['profile'] = {'id': profileId, 'type': 'synthetic'},
          ),
          now: t0,
        ),
        importError('IMPORT_PROFILE_UNSUPPORTED'),
      );
      // Same content, keys in another order: not what this app writes.
      final reordered = [
        {
          for (final k in records.first.keys.toList().reversed)
            k: records.first[k],
        },
        ...records.skip(1),
      ];
      expect(
        () => stageImport(jsonEncode(export(reordered)), now: t0),
        importError('IMPORT_RECORD_NOT_EXACT'),
      );
      expect(
        () => stageImport(jsonEncode(export(<Object?>[])), now: t0),
        importError('IMPORT_EMPTY'),
      );
      expect(
        () => stageImport('{"hello": 1}', now: t0),
        importError('IMPORT_NOT_SUPPORTED'),
      );
      expect(
        () => stageImport('not json', now: t0),
        backupError('BACKUP_UNREADABLE'),
      );
      unchanged();
    });
  });

  test('the staged envelope is the same vault: same id and key slots; the '
      'passphrase still opens it', () async {
    final (_, log) = await devVault();
    final o = await freshVault();
    final id = o.repository.description.vaultId;
    final firstLine = vaultFile.readAsStringSync().split('\n').first;
    await bringIn(
      o,
      stageImport(
        createBackupBundle(
          vaultLogText: log,
          appVersion: 't',
          sourceRevision: 't',
          createdAt: t0,
        ),
        now: t0,
      ),
    );
    expect(vaultFile.readAsStringSync().split('\n').first, firstLine);
    final again = await vault().unlock(pass);
    expect(again.repository.description.vaultId, id);
    expect(again.report.warnings, isEmpty);
  });
}
