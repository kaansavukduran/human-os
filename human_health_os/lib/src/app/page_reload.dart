/// Reloading the page, the way out of a browser session after a restore
/// ran (G-29). Null outside the browser.
library;

export 'page_reload_io.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
