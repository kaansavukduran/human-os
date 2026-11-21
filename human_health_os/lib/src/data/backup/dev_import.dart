/// Bringing the records of a development build into an encrypted vault
/// (F005-S3, G-76, D-050).
///
/// The source is a development backup (`hhos-backup`, `none-dev-only`) or a
/// JSON export (`hhos-export` v1). It goes through the same gate as a
/// restore: the backup's manifest and checksum (an export has none; its
/// counts and every record are checked), format and record-schema
/// compatibility, every record rule, then a preview. Only then is a new
/// envelope of the *same* vault (same id, same key slots, sealed with the
/// vault's own data key) built in memory and handed to the restore
/// adapter's staged write: written beside the vault, read back, opened
/// again, the previous envelope kept (never deleted), then switched.
///
/// Rules:
/// - only into a vault that holds no records (the adapter refuses
///   otherwise, as for a restore): nothing is merged, so no record of the
///   vault can be hidden, duplicated or reordered by an import;
/// - record payloads are byte-identical to the source (same ids, same
///   lineage): a record whose stored text is not exactly what this app
///   writes for it is refused, never rewritten;
/// - one SELF profile per file: what the app writes; synthetic or scenario
///   profiles never enter a real vault;
/// - nothing is written before the person confirms; a failure changes
///   nothing; the source file is never changed or deleted.
///
/// Pure Dart (no IO).
library;

import 'dart:convert';

import '../../domain/errors.dart';
import '../../domain/profile/profile.dart';
import '../../domain/records/health_record.dart';
import '../local/vault_envelope.dart';
import '../local/vault_log.dart';
import '../../application/export.dart' show exportFormat, exportFormatVersion;
import 'backup_bundle.dart';
import 'data_files.dart' show refuseIfHasRecords;

/// What a file to bring in is.
enum ImportSource { developmentBackup, jsonExport }

/// Why a file cannot be brought in (also every [BackupError] of the gate).
/// Nothing is written when this is thrown.
class ImportError implements Exception, CodedError {
  const ImportError(this.code, [this.detail = '']);

  /// `IMPORT_ENCRYPTED_BACKUP` (an encrypted backup: restore it instead) ·
  /// `IMPORT_NOT_SUPPORTED` (neither a backup nor an export) ·
  /// `IMPORT_EMPTY` (no records) · `IMPORT_PROFILE_UNSUPPORTED` (not
  /// exactly one SELF profile) · `IMPORT_RECORD_INVALID` ([detail] the
  /// rule) · `IMPORT_RECORD_NOT_EXACT` (stored text differs from what this
  /// app writes for it) · `IMPORT_EXPORT_DAMAGED` (an export that does not
  /// match its own counts or timeline) · `IMPORT_TARGET_HAS_RECORDS`
  @override
  final String code;
  final String detail;

  @override
  String toString() => 'ImportError($code): $detail';
}

/// A file that passed every check up to the preview. Holds the log lines
/// to write, in order; nothing has been written.
class StagedImport {
  const StagedImport({
    required this.source,
    required this.lines,
    required this.recordCount,
    required this.profileCount,
    required this.skippedEntries,
    required this.recordIds,
    this.madeAt,
    this.sourceAppVersion,
  });

  final ImportSource source;

  /// `profile.put` lines first, then `record.append` lines in an order in
  /// which every correction follows what it corrects.
  final List<String> lines;
  final int recordCount;
  final int profileCount;

  /// Entries a development build had skipped (damaged, torn): they are not
  /// brought in, and stay in the source file.
  final int skippedEntries;
  final List<String> recordIds;
  final DateTime? madeAt;
  final String? sourceAppVersion;
}

/// The checks before the preview. [now] dates the profile of an export,
/// which does not carry its creation time. Throws [ImportError] or
/// [BackupError]; writes nothing.
StagedImport stageImport(String text, {required DateTime now}) {
  final Object? doc;
  try {
    doc = jsonDecode(text);
  } catch (_) {
    throw const BackupError('BACKUP_UNREADABLE', 'Not readable');
  }
  if (doc is! Map) throw const ImportError('IMPORT_NOT_SUPPORTED');
  final manifest = doc['manifest'];
  if (manifest is Map && manifest['format'] == backupFormat) {
    return _fromBackup(text);
  }
  if (doc['format'] == exportFormat) {
    return _fromExport(doc.cast<String, Object?>(), now);
  }
  throw const ImportError('IMPORT_NOT_SUPPORTED');
}

StagedImport _fromBackup(String text) {
  final staged = stageRestore(text);
  if (staged.encrypted) throw const ImportError('IMPORT_ENCRYPTED_BACKUP');
  final state = staged.state!;
  if (state.migrations.isNotEmpty) {
    throw const BackupError('VAULT_INCOMPATIBLE', 'NEEDS_MIGRATION');
  }
  final self = _onlySelf(state.profiles.values);
  // The stored text of each record, as the development build wrote it.
  final raw = <String, Map<String, Object?>>{};
  for (final line in const LineSplitter().convert(staged.payload).skip(1)) {
    try {
      final m = (jsonDecode(line) as Map).cast<String, Object?>();
      if (m['op'] != 'record.append') continue;
      final data = (m['data']! as Map).cast<String, Object?>();
      raw.putIfAbsent(data['id']! as String, () => data);
    } catch (_) {
      // A skipped entry: counted by the parse, not brought in.
    }
  }
  final records = [for (final id in state.order) state.records[id]!];
  return _staged(
    ImportSource.developmentBackup,
    self,
    [for (final r in records) _exact(raw[r.id]!, r)],
    skipped: state.warnings.length,
    madeAt: staged.manifest.createdAt,
    version: staged.manifest.sourceAppVersion,
  );
}

StagedImport _fromExport(Map<String, Object?> doc, DateTime now) {
  final version = doc['format_version'];
  if (version is! int || version > exportFormatVersion) {
    throw BackupError('BACKUP_NEWER', '$version');
  }
  if (doc['encryption'] != 'none') {
    throw BackupError('BACKUP_ENCRYPTED_UNSUPPORTED', '${doc['encryption']}');
  }
  final Profile self;
  final List<Map<String, Object?>> maps;
  final int declared;
  DateTime? madeAt;
  try {
    final p = (doc['profile']! as Map).cast<String, Object?>();
    final type = ProfileType.values.byName(p['type']! as String);
    if (type != ProfileType.self) {
      throw const ImportError('IMPORT_PROFILE_UNSUPPORTED');
    }
    // An export does not carry when the profile was created: it is dated
    // when it enters this vault (D-050).
    self = Profile(id: p['id']! as String, type: type, createdAt: now.toUtc());
    maps = [
      for (final r in doc['records']! as List)
        (r as Map).cast<String, Object?>(),
    ];
    declared = doc['record_count']! as int;
    final at = doc['exported_at'];
    if (at is String) madeAt = DateTime.parse(at).toUtc();
  } on ImportError {
    rethrow;
  } catch (_) {
    throw const ImportError('IMPORT_EXPORT_DAMAGED', 'shape');
  }
  if (declared != maps.length) {
    throw const ImportError('IMPORT_EXPORT_DAMAGED', 'record_count');
  }
  final records = <HealthRecord>[];
  final byId = <String, Map<String, Object?>>{};
  for (final m in maps) {
    final HealthRecord r;
    try {
      r = HealthRecord.fromJson(m);
    } on SchemaTooNewError {
      throw const BackupError('VAULT_INCOMPATIBLE', 'RECORD_SCHEMA_NEWER');
    } on RecordValidationError catch (e) {
      throw ImportError('IMPORT_RECORD_INVALID', e.code);
    } catch (_) {
      throw const ImportError('IMPORT_RECORD_INVALID', 'UNREADABLE');
    }
    if (byId.containsKey(r.id)) {
      throw ImportError('IMPORT_RECORD_INVALID', 'DUPLICATE_ID');
    }
    byId[r.id] = m;
    records.add(r);
  }
  // The export's own timeline names only records it holds.
  try {
    for (final e in (doc['timeline'] as List?) ?? const []) {
      final entry = (e as Map).cast<String, Object?>();
      for (final key in ['current_ids', 'version_ids', 'withdrawn_ids']) {
        for (final id in (entry[key] as List?) ?? const []) {
          if (!byId.containsKey(id)) throw const FormatException();
        }
      }
      final del = entry['deletion_id'];
      if (del != null && !byId.containsKey(del)) {
        throw const FormatException();
      }
    }
  } catch (_) {
    throw const ImportError('IMPORT_EXPORT_DAMAGED', 'timeline');
  }
  return _staged(
    ImportSource.jsonExport,
    self,
    [for (final r in _lineageOrder(records)) _exact(byId[r.id]!, r)],
    skipped: 0,
    madeAt: madeAt,
    version: doc['app_version'] is String
        ? doc['app_version']! as String
        : null,
  );
}

Profile _onlySelf(Iterable<Profile> profiles) {
  final all = profiles.toList();
  if (all.length != 1 || all.single.type != ProfileType.self) {
    throw const ImportError('IMPORT_PROFILE_UNSUPPORTED');
  }
  return all.single;
}

/// The record line exactly as stored in the source; refused when that text
/// is not what this app writes for the record (it would change on the way).
String _exact(Map<String, Object?> raw, HealthRecord r) {
  final stored = jsonEncode(raw);
  if (stored != jsonEncode(r.toJson())) {
    throw ImportError('IMPORT_RECORD_NOT_EXACT', r.id);
  }
  return encodeOp('record.append', raw);
}

/// By time of recording (then id), with every correction after the record
/// it corrects.
List<HealthRecord> _lineageOrder(List<HealthRecord> records) {
  final pending = [...records]
    ..sort((a, b) {
      final c = a.recordedAt.compareTo(b.recordedAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final ids = {for (final r in records) r.id};
  final placed = <String>{};
  final out = <HealthRecord>[];
  while (pending.isNotEmpty) {
    final i = pending.indexWhere(
      (r) =>
          r.supersedesId == null ||
          placed.contains(r.supersedesId) ||
          !ids.contains(r.supersedesId),
    );
    // A missing target or a cycle is refused by the rule check below.
    final next = pending.removeAt(i < 0 ? 0 : i);
    out.add(next);
    placed.add(next.id);
  }
  return out;
}

StagedImport _staged(
  ImportSource source,
  Profile self,
  List<String> recordLines, {
  required int skipped,
  DateTime? madeAt,
  String? version,
}) {
  if (recordLines.isEmpty) throw const ImportError('IMPORT_EMPTY');
  final lines = [encodeOp('profile.put', self.toJson()), ...recordLines];
  // Every rule a vault applies, checked on a scratch vault in memory.
  final scratch = VaultState(
    VaultHeader(vaultId: 'import-check', createdAt: DateTime.utc(2000)),
  );
  final ids = <String>[];
  for (final l in lines) {
    final m = (jsonDecode(l) as Map).cast<String, Object?>();
    try {
      scratch.apply(
        m['op']! as String,
        (m['data']! as Map).cast<String, Object?>(),
      );
    } on RecordValidationError catch (e) {
      throw ImportError('IMPORT_RECORD_INVALID', e.code);
    } on VaultFormatError catch (e) {
      throw ImportError('IMPORT_RECORD_INVALID', e.code);
    }
    if (m['op'] == 'record.append') {
      ids.add((m['data']! as Map)['id']! as String);
    }
  }
  return StagedImport(
    source: source,
    lines: List.unmodifiable(lines),
    recordCount: recordLines.length,
    profileCount: 1,
    skippedEntries: skipped,
    recordIds: List.unmodifiable(ids),
    madeAt: madeAt,
    sourceAppVersion: version,
  );
}

/// Builds, in memory, the new envelope of the unlocked vault behind [sink]
/// holding [imp] after the vault's own log header, and hands it back as a
/// staged restore for the adapter's staged write (written, read back,
/// opened again, the previous envelope kept, then switched). Refuses a
/// vault that holds any record, or entries that cannot be read
/// (`IMPORT_TARGET_HAS_RECORDS`). Writes nothing.
Future<StagedRestore> stageImportIntoVault(
  StagedImport imp,
  EncryptedLogSink sink, {
  required DateTime now,
  required String appVersion,
  required String sourceRevision,
}) async {
  final both = await sink.readBoth();
  final opened = both.opened;
  if (opened.unknown > 0) {
    throw ImportError('IMPORT_TARGET_HAS_RECORDS', '${opened.unknown}');
  }
  try {
    refuseIfHasRecords(opened.inner);
  } on BackupError catch (e) {
    throw ImportError('IMPORT_TARGET_HAS_RECORDS', e.code);
  }
  final innerHeader = opened.inner
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty);
  final innerLines = [innerHeader, ...imp.lines];
  final innerText = '${innerLines.join('\n')}\n';
  final state = parseVaultLog(innerText);
  if (state.header.vaultId != sink.vaultId ||
      state.warnings.isNotEmpty ||
      state.records.length != imp.recordCount) {
    throw const BackupError('RESTORE_VERIFY_FAILED', 'import');
  }
  final envelope = sink.sealEnvelope(
    both.raw.split('\n').firstWhere((l) => l.trim().isNotEmpty),
    innerLines,
  );
  // The new envelope opens with this vault's key to exactly the lines.
  if (sink.open(envelope).inner != innerText) {
    throw const BackupError('RESTORE_VERIFY_FAILED', 'import');
  }
  final staged = stageRestore(
    createEncryptedBackupBundle(
      envelopeText: envelope,
      innerLogText: innerText,
      appVersion: appVersion,
      sourceRevision: sourceRevision,
      createdAt: now,
    ),
  );
  return StagedRestore(
    staged.manifest,
    staged.payload,
    state,
    envelope: staged.envelope,
    opener: sink.open,
  );
}
