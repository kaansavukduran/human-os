/// Language-aware casing and number display for shown text (L001).
///
/// Dart's [String.toUpperCase] and [String.toLowerCase] follow the
/// language-neutral Unicode mapping: "i" becomes "I" and "İ" becomes
/// "i̇" (i plus a combining dot). Turkish pairs i/İ and ı/I, so any shown
/// Turkish text that is case-transformed goes through these helpers.
library;

import 'strings.dart' show AppLang;

/// [text] in capitals, with the Turkish i/İ and ı/I pairs in Turkish.
String upperIn(AppLang lang, String text) => lang == AppLang.tr
    ? text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
    : text.toUpperCase();

/// [text] in small letters, with the Turkish İ/i and I/ı pairs in Turkish.
String lowerIn(AppLang lang, String text) => lang == AppLang.tr
    ? text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase()
    : text.toLowerCase();

/// A number the app formatted with a decimal point (e.g. "72.4"), shown
/// with the decimal mark of [lang]: Turkish writes a decimal comma
/// ("72,4"). Values shown "as printed" (lab text) never pass through here.
String decimalIn(AppLang lang, String number) =>
    lang == AppLang.tr ? number.replaceAll('.', ',') : number;
