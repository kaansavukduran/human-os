import 'package:file_picker/file_picker.dart';

import '../../data/local/storage_io.dart' show dropChooserCopy;
import 'backup_file_picker.dart' show ChosenFile;
import 'platform_chosen_file.dart';

export 'platform_chosen_file.dart';

/// Desktop and phones: file_picker hands back a path; nothing is read
/// until [ChosenFile.read].
Future<ChosenFile?> chooseSystemFile(String title) async {
  final f = await FilePicker.pickFile(dialogTitle: title);
  return f == null ? null : PlatformChosenFile(f);
}

/// Drops the copy the chooser made of [file] (D-050): on Android and iOS
/// file_picker's own clean-up, then the returned path when it lies inside
/// the app's cache or temporary folder; see [dropChooserCopy].
Future<void> releaseChosenFile(ChosenFile file) => dropChooserCopy(
  file is PlatformChosenFile ? file.path : null,
  clearChooser: FilePicker.clearTemporaryFiles,
);
