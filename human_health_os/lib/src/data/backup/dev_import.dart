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
/// - into a vault that holds no records (F005-S3, D-050): the envelope is
///   rebuilt with the file's profile and records after the log header;
/// - into a vault that holds records (F005-S4, D-053): records are matched
///   by id; one stored byte for byte already → skipped; the same id with
///   other bytes → the whole import is refused (a conflict the person
///   resolves; neither is ever overwritten); new ids → appended as new
///   sealed lines after the vault's existing lines, which stay exactly as
///   stored. The file's SELF profile must be the vault's SELF profile (same
///   id): a record's profile id is part of its bytes, so records of another
///   profile are refused, never re-attached. A correction whose target is
///   not in the file is refused (broken chain; a development file is a
///   whole log). Order on screen follows the timeline rules, never the
///   import order;
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
  /// match its own counts or timeline) · `IMPORT_TARGET_HAS_RECORDS` ·
  /// F005-S4 (D-053): `IMPORT_CHAIN_BROKEN` (a correction whose target is
  /// missing; [detail] its id) · `IMPORT_PROFILE_DIFFERENT` (the file's
  /// SELF profile is not this vault's) · `IMPORT_CONFLICT` (an id stored
  /// here with other bytes; [detail] how many) · `IMPORT_NOTHING_NEW`
  /// (every record is already here) · `IMPORT_TARGET_UNREADABLE` (the
  /// vault holds entries that cannot be read, so duplicates cannot be
  /// ruled out) · `IMPORT_TARGET_READ_ONLY` (the vault needs an upgrade
  /// first) · `IMPORT_VAULT_CHANGED` (the vault changed after the preview)
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
    required this.profile,
    required this.lines,
    required this.recordCount,
    required this.profileCount,
    required this.skippedEntries,
    required this.recordIds,
    this.madeAt,
    this.sourceAppVersion,
  });

  final ImportSource source;

  /// The file's one SELF profile.
  final Profile profile;

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
      // A development file is a whole log: a correction whose target it
      // does not hold is a broken chain, whatever the vault holds (D-053).
      if (e.code == 'AMEND_TARGET_MISSING') {
        throw ImportError(
          'IMPORT_CHAIN_BROKEN',
          '${(m['data']! as Map)['id']}',
        );
      }
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
    profile: self,
    lines: List.unmodifiable(lines),
    recordCount: recordLines.length,
    profileCount: 1,
    skippedEntries: skipped,
    recordIds: List.unmodifiable(ids),
    madeAt: madeAt,
    sourceAppVersion: version,
  );
}

/// What bringing a checked file into the unlocked vault would do, worked
/// out against the vault as it is now (F005-S4, D-053). Nothing has been
/// written; [stagePlannedImport] writes only this plan, and only while the
/// vault file is still exactly [liveRaw].
class ImportPlan {
  const ImportPlan({
    required this.source,
    required this.liveRaw,
    required this.intoEmptyVault,
    required this.newLines,
    required this.alreadyPresent,
    required this.conflictIds,
    required this.recordsAfter,
    this.competingIds = const [],
  });

  final StagedImport source;

  /// The stored vault file the plan was made against.
  final String liveRaw;

  /// True when the vault holds no records: the F005-S3 path (D-050), the
  /// file's profile and records after the vault's log header.
  final bool intoEmptyVault;

  /// The `record.append` lines to add (ids not stored here), with every
  /// correction after what it corrects.
  final List<String> newLines;

  /// Records stored here already, byte for byte: skipped.
  final int alreadyPresent;

  /// Ids stored here with other bytes: they block the whole import.
  final List<String> conflictIds;

  /// New corrections of a record this vault already corrected with another
  /// record (R026): two corrections would compete, and an import never
  /// chooses between them, so they block the whole import too.
  final List<String> competingIds;

  /// Records in the vault once the plan is written.
  final int recordsAfter;

  int get newCount => newLines.length;
  bool get blocked => conflictIds.isNotEmpty || competingIds.isNotEmpty;
  bool get nothingNew => newLines.isEmpty;
}

/// Reads the vault behind [sink] once and compares it with [imp]. Throws
/// [ImportError] when the file cannot be merged at all (another profile, a
/// broken chain, an unreadable or read-only vault); conflicts are returned
/// in the plan, for the preview to show. Writes nothing.
Future<ImportPlan> planImport(StagedImport imp, EncryptedLogSink sink) async {
  final both = await sink.readBoth();
  final opened = both.opened;
  if (opened.unknown > 0) {
    throw ImportError('IMPORT_TARGET_UNREADABLE', '${opened.unknown}');
  }
  var empty = true;
  try {
    refuseIfHasRecords(opened.inner);
  } on BackupError catch (e) {
    if (e.code != 'RESTORE_TARGET_HAS_RECORDS') {
      throw ImportError('IMPORT_TARGET_UNREADABLE', e.code);
    }
    empty = false;
  }
  if (empty) {
    return ImportPlan(
      source: imp,
      liveRaw: both.raw,
      intoEmptyVault: true,
      newLines: [
        for (final l in imp.lines)
          if (l.startsWith('{"op":"record.append"')) l,
      ],
      alreadyPresent: 0,
      conflictIds: const [],
      recordsAfter: imp.recordCount,
    );
  }
  final VaultState live;
  try {
    live = parseVaultLog(opened.inner);
  } on VaultFormatError catch (e) {
    throw ImportError('IMPORT_TARGET_UNREADABLE', e.code);
  }
  // An entry the vault skipped may be a record: a duplicate could not be
  // ruled out, so nothing is merged.
  if (live.warnings.isNotEmpty) {
    throw ImportError('IMPORT_TARGET_UNREADABLE', '${live.warnings.length}');
  }
  if (live.migrations.isNotEmpty) {
    throw const ImportError('IMPORT_TARGET_READ_ONLY');
  }
  // Records keep the profile they were saved under (its id is part of
  // their bytes): only the vault's own SELF profile can receive them.
  final vaultSelf = live.profiles[imp.profile.id];
  if (vaultSelf == null || vaultSelf.type != ProfileType.self) {
    throw const ImportError('IMPORT_PROFILE_DIFFERENT');
  }
  // The stored text of each record of the vault.
  final stored = <String, String>{};
  for (final line in const LineSplitter().convert(opened.inner).skip(1)) {
    final m = (jsonDecode(line) as Map).cast<String, Object?>();
    if (m['op'] != 'record.append') continue;
    final data = (m['data']! as Map).cast<String, Object?>();
    stored.putIfAbsent(data['id']! as String, () => jsonEncode(data));
  }
  // What each stored correction corrects: target id -> correction ids.
  final correctedHere = <String, Set<String>>{};
  for (final e in stored.entries) {
    final target = (jsonDecode(e.value) as Map)['supersedes_id'];
    if (target is String) {
      (correctedHere[target] ??= <String>{}).add(e.key);
    }
  }
  // Every record id the file holds: a stored correction the file also
  // holds is shared, never a competitor.
  final fileIds = <String>{
    for (final l in imp.lines)
      if (l.startsWith('{"op":"record.append"'))
        ((jsonDecode(l) as Map)['data']! as Map)['id']! as String,
  };
  final newLines = <String>[];
  final conflicts = <String>[];
  final competing = <String>[];
  var present = 0;
  for (final l in imp.lines) {
    final m = (jsonDecode(l) as Map).cast<String, Object?>();
    if (m['op'] != 'record.append') continue;
    final data = (m['data']! as Map).cast<String, Object?>();
    final id = data['id']! as String;
    final here = stored[id];
    if (here == null) {
      newLines.add(l);
      // A new correction of a record this vault already corrected (or,
      // seen from the vault, a stored correction of a record the file also
      // corrects): two corrections would compete. Neither wins by import.
      // A stored correction the file holds too is shared, not competing.
      final target = data['supersedes_id'];
      if (target is String &&
          (correctedHere[target]?.any((c) => c != id && !fileIds.contains(c)) ??
              false)) {
        competing.add(id);
      }
    } else if (here == jsonEncode(data)) {
      present++;
    } else {
      conflicts.add(id);
    }
  }
  // Every rule replayed on the union, in memory: a correction must find
  // its target in the file or in the vault.
  final union = parseVaultLog(opened.inner);
  for (final l in newLines) {
    final m = (jsonDecode(l) as Map).cast<String, Object?>();
    final data = (m['data']! as Map).cast<String, Object?>();
    try {
      union.apply('record.append', data);
    } on RecordValidationError catch (e) {
      if (e.code == 'AMEND_TARGET_MISSING') {
        throw ImportError('IMPORT_CHAIN_BROKEN', '${data['id']}');
      }
      throw ImportError('IMPORT_RECORD_INVALID', e.code);
    } on VaultFormatError catch (e) {
      throw ImportError('IMPORT_RECORD_INVALID', e.code);
    }
  }
  return ImportPlan(
    source: imp,
    liveRaw: both.raw,
    intoEmptyVault: false,
    newLines: List.unmodifiable(newLines),
    alreadyPresent: present,
    conflictIds: List.unmodifiable(conflicts),
    competingIds: List.unmodifiable(competing),
    recordsAfter: union.records.length,
  );
}

/// [planImport] then [stagePlannedImport]: refuses a conflict
/// (`IMPORT_CONFLICT`), competing corrections (`IMPORT_CORRECTIONS_COMPETE`)
/// or a file with nothing new (`IMPORT_NOTHING_NEW`).
Future<StagedRestore> stageImportIntoVault(
  StagedImport imp,
  EncryptedLogSink sink, {
  required DateTime now,
  required String appVersion,
  required String sourceRevision,
}) async => stagePlannedImport(
  await planImport(imp, sink),
  sink,
  now: now,
  appVersion: appVersion,
  sourceRevision: sourceRevision,
);

/// Builds, in memory, the new envelope of the unlocked vault behind [sink]
/// for [plan] and hands it back as a staged restore for the adapter's
/// staged write (written, read back, opened again, the previous envelope
/// kept, then switched). Into an empty vault: the vault's own log header,
/// then the file's profile and records, all sealed again (F005-S3). Into a
/// vault with records: the stored file exactly as it is, then the new
/// records sealed with the next sequence numbers; the adapter writes it
/// only while the vault file is unchanged ([StagedRestore.extendsLive]).
/// Refuses a plan with conflicts (`IMPORT_CONFLICT`), with competing
/// corrections (`IMPORT_CORRECTIONS_COMPETE`, R026), with nothing new
/// (`IMPORT_NOTHING_NEW`), or made against a vault that changed since
/// (`IMPORT_VAULT_CHANGED`). Writes nothing.
Future<StagedRestore> stagePlannedImport(
  ImportPlan plan,
  EncryptedLogSink sink, {
  required DateTime now,
  required String appVersion,
  required String sourceRevision,
}) async {
  if (plan.conflictIds.isNotEmpty) {
    throw ImportError('IMPORT_CONFLICT', '${plan.conflictIds.length}');
  }
  if (plan.competingIds.isNotEmpty) {
    throw ImportError(
      'IMPORT_CORRECTIONS_COMPETE',
      '${plan.competingIds.length}',
    );
  }
  if (plan.nothingNew) throw const ImportError('IMPORT_NOTHING_NEW');
  final both = await sink.readBoth();
  if (both.raw != plan.liveRaw) {
    throw const ImportError('IMPORT_VAULT_CHANGED');
  }
  if (plan.intoEmptyVault) {
    return _stageIntoEmpty(
      plan.source,
      sink,
      both,
      now: now,
      appVersion: appVersion,
      sourceRevision: sourceRevision,
    );
  }
  final opened = both.opened;
  if (opened.unknown > 0) {
    throw ImportError('IMPORT_TARGET_UNREADABLE', '${opened.unknown}');
  }
  // The stored file stays byte for byte; the new records follow it.
  final base = both.raw.endsWith('\n') ? both.raw : '${both.raw}\n';
  final envelope = base + sink.sealContinuation(opened.nextSeq, plan.newLines);
  final liveInner = opened.inner.endsWith('\n')
      ? opened.inner
      : '${opened.inner}\n';
  final innerText = '$liveInner${plan.newLines.map((l) => '$l\n').join()}';
  final state = parseVaultLog(innerText);
  if (state.header.vaultId != sink.vaultId ||
      state.warnings.isNotEmpty ||
      state.records.length != plan.recordsAfter ||
      !envelope.startsWith(both.raw) ||
      sink.open(envelope).inner != innerText) {
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
    extendsLive: both.raw,
  );
}

Future<StagedRestore> _stageIntoEmpty(
  StagedImport imp,
  EncryptedLogSink sink,
  ({String raw, OpenedEnvelope opened}) both, {
  required DateTime now,
  required String appVersion,
  required String sourceRevision,
}) async {
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
