/// The system's file chooser for a backup to restore; the browser version
/// tells file_picker not to read the file at pick time.
library;

export 'backup_file_chooser_io.dart'
    if (dart.library.js_interop) 'backup_file_chooser_web.dart';
