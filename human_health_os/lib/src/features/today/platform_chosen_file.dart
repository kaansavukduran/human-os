import 'package:file_picker/file_picker.dart';

import 'backup_file_picker.dart' show ChosenFile;

/// A file_picker file as a [ChosenFile] (desktop, phones and the browser).
class PlatformChosenFile implements ChosenFile {
  PlatformChosenFile(this._file);

  final PlatformFile _file;

  @override
  String get name => _file.name;

  /// Where the file is on local disk; on Android and iOS this is the
  /// chooser's own copy in the app's cache or temporary folder. Null in the
  /// browser.
  String? get path => _file.path;

  @override
  Future<int?> size() async => _file.lengthSync() ?? await _file.length();

  @override
  Future<List<int>> read() => _file.readAsBytes();
}
