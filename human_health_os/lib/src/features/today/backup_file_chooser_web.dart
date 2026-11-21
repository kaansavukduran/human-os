import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart' show FilePickerWebOptions;

import 'backup_file_picker.dart' show ChosenFile;
import 'platform_chosen_file.dart';

export 'platform_chosen_file.dart';

/// The browser. file_picker's `withData` defaults to true, which reads the
/// whole file into memory at pick time, before any size check could refuse
/// it. With it off the file is only a handle carrying the browser's
/// `File.size` until [ChosenFile.read].
Future<ChosenFile?> chooseSystemFile(String title) async {
  final f = await FilePicker.pickFile(
    dialogTitle: title,
    webOptions: const FilePickerWebOptions(
      // Deprecated, but its default (true) still preloads the whole file
      // before our size check in file_picker 13; false turns that off.
      // ignore: deprecated_member_use
      withData: false,
    ),
  );
  return f == null ? null : PlatformChosenFile(f);
}

/// The browser keeps no copy of a chosen file on disk: nothing to drop.
Future<void> releaseChosenFile(ChosenFile file) async {}
