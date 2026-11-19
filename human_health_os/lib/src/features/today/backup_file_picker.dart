import 'dart:convert';

import '../../data/backup/backup_bundle.dart' show BackupError;
import 'backup_file_chooser.dart';

/// A backup file the person chose; its text is read once.
class PickedBackup {
  const PickedBackup({required this.name, required this.text});

  final String name;
  final String text;
}

/// How large a chosen backup may be where it is restored. A larger file is
/// refused from its size alone, before a single byte is read.
class BackupSizeLimit {
  const BackupSizeLimit._(this.bytes, this.code);

  /// Desktop, phones, and web builds that keep a restore only in this tab's
  /// memory (G-32): nothing goes to browser storage there, so the general
  /// limit applies; the tab holds the file once, as a desktop app would.
  static const anyBackup = BackupSizeLimit._(
    maxBackupFileBytes,
    'BACKUP_TOO_LARGE',
  );

  /// Development web builds keep the restored vault in localStorage, which
  /// holds about 5 MB per site; see [maxBrowserBackupBytes].
  static const browserStorage = BackupSizeLimit._(
    maxBrowserBackupBytes,
    'BACKUP_TOO_LARGE_BROWSER',
  );

  final int bytes;

  /// The refusal's code; its detail is the file's size in bytes.
  final String code;

  BackupError refuse(int size) => BackupError(code, '$size');
}

/// Chooses a backup file to restore (G-29). Behind an interface so tests
/// need no browser dialog; the browser smoke drives the real chooser.
abstract interface class BackupFilePicker {
  /// Null when the person cancelled. Throws `BackupError` when the file is
  /// larger than [limit] (checked before it is read) or cannot be read as
  /// text.
  Future<PickedBackup?> pick({
    required String title,
    BackupSizeLimit limit = BackupSizeLimit.anyBackup,
  });
}

/// Larger than any backup this app makes today; a bigger file is refused
/// before it is read into memory.
const int maxBackupFileBytes = 64 * 1024 * 1024;

/// What a development web build can keep in localStorage. Browsers give a
/// site about 5 MB there (5 million UTF-16 code units in Chrome and
/// Firefox), shared with the app's other keys. During a restore the staged
/// copy is dropped before the vault slot is written, so the payload must
/// fit once, with room left for the preferences and the kept previous
/// content (which holds no records). A backup file is larger than its
/// payload, and a UTF-8 byte count is never below the UTF-16 unit count, so
/// a 4 MiB file always fits.
const int maxBrowserBackupBytes = 4 * 1024 * 1024;

/// A file from the system's chooser: its size comes from the file's
/// metadata (no read); its bytes are read only on request.
abstract interface class ChosenFile {
  String get name;

  /// Null when the system does not say.
  Future<int?> size();

  Future<List<int>> read();
}

/// Checks [file]'s size against [limit] before reading it, then reads it
/// once and decodes it as UTF-8.
Future<PickedBackup> readChosenBackup(
  ChosenFile file,
  BackupSizeLimit limit,
) async {
  final size = await file.size();
  if (size != null && size > limit.bytes) throw limit.refuse(size);
  final bytes = await file.read();
  // A size the system did not report (or got wrong) is checked again.
  if (bytes.length > limit.bytes) throw limit.refuse(bytes.length);
  try {
    return PickedBackup(name: file.name, text: utf8.decode(bytes));
  } on FormatException {
    throw const BackupError('BACKUP_UNREADABLE', 'Not text');
  }
}

/// The system's chooser (in the browser an `<input type=file>` that reads
/// nothing by itself, through file_picker, already a dependency). No
/// extension filter: a name is not trusted; the restore gate checks the
/// content.
class SystemBackupFilePicker implements BackupFilePicker {
  const SystemBackupFilePicker({this.choose = chooseSystemFile});

  /// Opens the chooser; tests hand in a fake file.
  final Future<ChosenFile?> Function(String title) choose;

  @override
  Future<PickedBackup?> pick({
    required String title,
    BackupSizeLimit limit = BackupSizeLimit.anyBackup,
  }) async {
    final f = await choose(title);
    if (f == null) return null;
    return readChosenBackup(f, limit);
  }
}
