import 'package:file_picker/file_picker.dart';

import 'backup_file_picker.dart' show ChosenFile;

/// Desktop and phones: file_picker hands back a path; nothing is read
/// until [ChosenFile.read].
Future<ChosenFile?> chooseSystemFile(String title) async {
  final f = await FilePicker.pickFile(dialogTitle: title);
  return f == null ? null : PlatformChosenFile(f);
}

/// A file_picker file as a [ChosenFile].
class PlatformChosenFile implements ChosenFile {
  PlatformChosenFile(this._file);

  final PlatformFile _file;

  @override
  String get name => _file.name;

  @override
  Future<int?> size() async => _file.lengthSync() ?? await _file.length();

  @override
  Future<List<int>> read() => _file.readAsBytes();
}
