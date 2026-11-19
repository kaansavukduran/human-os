import 'dart:js_interop';

@JS('location.reload')
external void _locationReload();

// JS interop members cannot be torn off; a Dart function wraps the call.
void _reloadPage() => _locationReload();

/// Reloads this tab (`location.reload()`).
const void Function() pageReload = _reloadPage;
