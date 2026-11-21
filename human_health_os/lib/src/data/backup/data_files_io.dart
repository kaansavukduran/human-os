/// Desktop adapter: backups and exports in folders beside the development
/// vault (`backups/`, `exports/`), and the file steps of the restore gate.
library;

import 'dart:io';

import '../local/vault_log.dart' show decodeLogBytes;
import 'backup_bundle.dart';
import 'data_files.dart';

class FileDataFiles implements DataFiles {
  FileDataFiles({
    required this.dataDir,
    required this.vault,
    this.target = const RestoreTarget.plaintext(),
    Future<void> Function(File file, String to)? rename,
    Future<void> Function(File file, String to)? copy,
  }) : _rename = rename ?? _renameFile,
       _copy = copy ?? _copyFile;

  static Future<void> _renameFile(File file, String to) => file.rename(to);

  static Future<void> _copyFile(File file, String to) => file.copy(to);

  static int _tmpCounter = 0;

  /// Moves a file, replacing what is at `to` in one step (POSIX rename(2);
  /// on Windows Dart's rename replaces an existing file). Tests replace it
  /// to make a step fail.
  final Future<void> Function(File file, String to) _rename;

  /// Copies a file (tests replace it to make a step fail).
  final Future<void> Function(File file, String to) _copy;

  final Directory dataDir;
  final File vault;

  /// The kind of vault [vault] is (development log or encrypted envelope).
  final RestoreTarget target;

  String get _sep => Platform.pathSeparator;
  Directory _dir(DataFileKind kind) => Directory(
    '${dataDir.path}$_sep${kind == DataFileKind.backup ? 'backups' : 'exports'}',
  );

  @override
  bool get canRestore => true;

  @override
  bool get restoresChosenFile => false;

  @override
  bool get keepsInBrowserStorage => false;

  @override
  bool get sessionOnly => false;

  @override
  bool get opensEncryptedBackups => true;

  @override
  bool get holdsEncryptedVault => target.encrypted;

  @override
  Future<String> save(DataFileKind kind, String fileName, String text) async {
    final dir = _dir(kind);
    await dir.create(recursive: true);
    final target = File('${dir.path}$_sep$fileName');
    // Temp file + rename: a crash never leaves half a backup behind.
    // A name of its own: two saves at once never share a temp file.
    final tmp = File('${target.path}.${_tmpCounter++}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(target.path);
    return target.path;
  }

  @override
  Future<List<SavedFile>> backups() async {
    final dir = _dir(DataFileKind.backup);
    if (!await dir.exists()) return const [];
    final files = <SavedFile>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.hhosbackup.json')) continue;
      final st = await e.stat();
      files.add(
        SavedFile(
          id: e.path,
          name: e.uri.pathSegments.last,
          bytes: st.size,
          modified: st.modified.toUtc(),
        ),
      );
    }
    return files..sort(newestBackupFirst);
  }

  @override
  Future<String> read(SavedFile file) => File(file.id).readAsString();

  @override
  Future<RestoreOutcome> restore(
    StagedRestore staged, {
    required DateTime now,
    void Function()? beforeSwitch,
  }) async {
    target.checkKind(staged);
    final liveBytes = await vault.exists() ? await vault.readAsBytes() : null;
    final live = liveBytes == null ? null : decodeLogBytes(liveBytes);
    target.refuseIfHolds(live);
    await vault.parent.create(recursive: true);
    // Staged destination: written and verified before anything is switched.
    final restoring = File('${vault.path}.restoring');
    await restoring.writeAsString(staged.payload, flush: true);
    try {
      staged.verifyWritten(await restoring.readAsString());
    } catch (_) {
      await restoring.delete();
      rethrow;
    }
    // From here the file at the vault path changes: this session's memory
    // no longer matches it, so it stops writing first (review finding).
    beforeSwitch?.call();
    // The vault's path is never empty (D-050): the previous vault is kept
    // by a copy (it stays where it is), then the restored copy replaces it
    // in one rename. A crash at any point leaves either the previous or the
    // restored vault at the path, never neither.
    String? kept;
    if (liveBytes != null) {
      final aside = '${vault.path}.before-restore-${fileStamp(now)}';
      try {
        await _copy(vault, aside);
        if (!_same(await File(aside).readAsBytes(), liveBytes)) {
          throw const FileSystemException('the kept copy differs');
        }
        kept = aside;
      } catch (_) {
        await _deleteQuietly(File(aside));
        await _deleteQuietly(restoring);
        // The previous vault never left its place.
        throw const BackupError('RESTORE_NOT_SWITCHED', '');
      }
    }
    try {
      await _rename(restoring, vault.path);
    } catch (_) {
      await _deleteQuietly(restoring);
      if (await vault.exists()) {
        // The rename changed nothing: the previous vault (if any) is still
        // in place, and its kept copy is a duplicate. Checked, never assumed.
        if (kept != null &&
            liveBytes != null &&
            _same(await vault.readAsBytes(), liveBytes)) {
          await _deleteQuietly(File(kept));
          throw const BackupError('RESTORE_NOT_SWITCHED', '');
        }
        if (kept == null) throw const BackupError('RESTORE_NOT_SWITCHED', '');
        throw BackupError('RESTORE_SWITCH_FAILED', kept);
      }
      if (kept == null) throw const BackupError('RESTORE_NOT_SWITCHED', '');
      // A rename that removed the vault and then failed: put the kept copy
      // back, so the path is not left empty.
      try {
        await _copy(File(kept), vault.path);
        throw const BackupError('RESTORE_SWITCH_FAILED', '');
      } on BackupError {
        rethrow;
      } catch (_) {
        await _deleteQuietly(vault);
        // It stays at [kept]; the message says where.
        throw BackupError('RESTORE_SWITCH_FAILED', kept);
      }
    }
    return RestoreOutcome(
      records: staged.manifest.recordCount,
      location: vault.path,
      keptPrevious: kept,
    );
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // A leftover copy stays; it is never the only copy of anything.
    }
  }
}
