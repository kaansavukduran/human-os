import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../data/backup/backup_bundle.dart' show BackupError;

/// A backup file the person chose; its text is read once.
class PickedBackup {
  const PickedBackup({required this.name, required this.text});

  final String name;
  final String text;
}

/// Chooses a backup file to restore (G-29). Behind an interface so tests
/// need no browser dialog; the browser smoke drives the real chooser.
abstract interface class BackupFilePicker {
  /// Null when the person cancelled. Throws `BackupError` when the file
  /// cannot be read as text.
  Future<PickedBackup?> pick({required String title});
}

/// Larger than any backup this app makes today; a bigger file is refused
/// before it is read into memory.
const int maxBackupFileBytes = 64 * 1024 * 1024;

/// The system's chooser (in the browser an `<input type=file>`, through
/// file_picker, already a dependency). No extension filter: a name is not
/// trusted; the restore gate checks the content.
class SystemBackupFilePicker implements BackupFilePicker {
  const SystemBackupFilePicker();

  @override
  Future<PickedBackup?> pick({required String title}) async {
    final f = await FilePicker.pickFile(dialogTitle: title);
    if (f == null) return null;
    final size = f.lengthSync() ?? await f.length();
    if (size != null && size > maxBackupFileBytes) {
      throw const BackupError('BACKUP_TOO_LARGE', 'Larger than any backup');
    }
    final bytes = await f.readAsBytes();
    try {
      return PickedBackup(name: f.name, text: utf8.decode(bytes));
    } on FormatException {
      throw const BackupError('BACKUP_UNREADABLE', 'Not text');
    }
  }
}
