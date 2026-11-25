/// Web adapter: a backup or export is handed to the browser as a download
/// (a local Blob; nothing leaves the device). A backup the person chooses
/// with the browser's file chooser is restored into browser storage through
/// the same gate as on desktop (G-29).
library;

import 'dart:async' show FutureOr;
import 'dart:js_interop';

import 'backup_bundle.dart';
import 'data_files.dart';

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({JSString type});
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSString> parts, _BlobOptions options);
}

@JS('URL.createObjectURL')
external JSString _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(JSString url);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(JSString value);
  external set download(JSString value);
  external void click();
}

@JS('document.createElement')
external _Anchor _createElement(JSString tag);

/// The `localStorage` calls the restore needs.
extension type BrowserStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

class _Slots implements TextSlots {
  _Slots(this._storage);

  final BrowserStorage _storage;

  @override
  String? get(String key) => _storage.getItem(key.toJS)?.toDart;

  @override
  void set(String key, String value) => _storage.setItem(key.toJS, value.toJS);

  @override
  void remove(String key) => _storage.removeItem(key.toJS);
}

class BrowserDataFiles implements DataFiles {
  BrowserDataFiles(BrowserStorage storage, this.vaultKey)
    : _slots = _Slots(storage);

  final TextSlots _slots;

  /// The browser storage key of the development vault.
  final String vaultKey;

  @override
  bool get canRestore => false;

  @override
  bool get restoresChosenFile => true;

  @override
  bool get keepsInBrowserStorage => true;

  @override
  bool get sessionOnly => false;

  /// The vault cryptography does not run under dart2js (D-016, G-32).
  @override
  bool get opensEncryptedBackups => false;

  @override
  bool get holdsEncryptedVault => false;

  @override
  Future<String> save(DataFileKind kind, String fileName, String text) async {
    final blob = _Blob(
      [text.toJS].toJS,
      _BlobOptions(type: 'application/json'.toJS),
    );
    final url = _createObjectUrl(blob);
    final a = _createElement('a'.toJS)
      ..href = url
      ..download = fileName.toJS;
    a.click();
    _revokeObjectUrl(url);
    return 'browser download ($fileName)';
  }

  @override
  Future<List<SavedFile>> backups() async => const [];

  @override
  Future<String> read(SavedFile file) =>
      throw UnsupportedError('The browser lists no backups; choose a file');

  @override
  Future<RestoreOutcome> restore(
    StagedRestore staged, {
    required DateTime now,
    FutureOr<void> Function()? beforeSwitch,
  }) => restoreIntoSlots(
    _slots,
    vaultKey,
    staged,
    now: now,
    beforeSwitch: beforeSwitch,
  );
}
