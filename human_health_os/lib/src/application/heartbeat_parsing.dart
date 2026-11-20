part of 'heartbeat_service.dart';

// Parsing helpers for typed text: decimals, lab values as printed, text
// results, the method, the sample date and the report time. Every error
// is an [InputError] naming its field. (The reference interval parsers
// stay in heartbeat_service.dart.)

/// Parses user text such as `78.4`, `78,4` or ` 78 `. Blank input is an error,
/// never zero (missing ≠ zero).
double parseDecimal(String raw) {
  final t = raw.trim().replaceAll(' ', '');
  if (t.isEmpty) throw const InputError('EMPTY');
  if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(t)) {
    throw const InputError('NOT_A_NUMBER');
  }
  return double.parse(t.replaceAll(',', '.'));
}

/// Parses `YYYY-MM-DD` into that calendar day (UTC midnight, a date without
/// a time of day). Anything else is `DATE_INVALID`.
DateTime parseSampleDate(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) throw const InputError('DATE_INVALID');
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime.utc(y, mo, d);
  if (date.year != y || date.month != mo || date.day != d) {
    throw const InputError('DATE_INVALID');
  }
  return date;
}

/// Like [parseDecimal], but refuses a value whose separator could be a
/// thousands separator ("150,000", "7.500", "250.000"): guessing would store
/// a number 1000 times off while the screen shows the printed text.
double parseLabDecimal(String raw) {
  final t = raw.trim().replaceAll(' ', '');
  if (RegExp(r'^[1-9]\d{0,2}[.,]\d{3}$').hasMatch(t)) {
    throw const InputError('AMBIGUOUS_SEPARATOR');
  }
  return parseDecimal(raw);
}

/// A number with a unit typed after it ("5 mg/dL", "37mmol/mol", "6 %").
final RegExp _unitAfterNumber = RegExp(
  r'^\d+([.,]\d+)?\s*[\p{L}%/µ°]',
  unicode: true,
);

/// A comparator typed first: "<", ">", "≤", "≥" or "=".
final RegExp _comparatorFirst = RegExp(r'^[<>≤≥=]');

/// A sign typed before a lab number: "-" or the minus sign "\u2212" (U+2212).
final RegExp _labMinus = RegExp(r'^[\-\u2212]');

/// A ratio or titre as printed ("1/160", "1:80"): text, not a unit.
final RegExp _titre = RegExp(r'^\d+\s*[/:]\s*\d+');

/// The number of a plain lab value. Besides [parseLabDecimal]'s rules, a
/// comparator first ("<5") is `VALUE_HAS_COMPARATOR` and a unit after the
/// number ("5 mg/dL") is `UNIT_IN_VALUE`, so the message says what to do.
/// A leading "-" or "\u2212" makes it negative (base excess -2): labs print
/// negative results, while weight and the other measurements never take
/// one. Spaces after the sign are ignored, as inside the number ("- 2" is
/// -2); the record keeps what was typed as its original text.
double parseLabNumber(String raw) {
  var t = raw.trim();
  if (_comparatorFirst.hasMatch(t)) {
    throw const InputError('VALUE_HAS_COMPARATOR', 'value');
  }
  final negative = _labMinus.hasMatch(t);
  if (negative) t = t.substring(1).trim();
  if (_unitAfterNumber.hasMatch(t)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  try {
    final v = parseLabDecimal(t);
    if (!v.isFinite) throw const InputError('NOT_A_NUMBER');
    // "-0" is 0: a sign on zero is not a different result.
    return negative && v != 0 ? -v : v;
  } on InputError catch (e) {
    // A sign alone ("-") is a number without digits, not a blank field.
    if (negative && e.code == 'EMPTY') {
      throw const InputError('NOT_A_NUMBER', 'value');
    }
    throw InputError(e.code, 'value');
  }
}

/// A censored lab value ("< 5", "<=0,1", "> 1000", "≥ 90"): one comparator
/// and one number, the number kept exactly as typed. Refused: blank
/// (`EMPTY`), no comparator (`CENSORED_NEEDS_COMPARATOR`), a comparator
/// alone (`CENSORED_NEEDS_NUMBER`), two comparators or a stray "="
/// (`COMPARATOR_UNCLEAR`), a unit in the value (`UNIT_IN_VALUE`), and a
/// number [parseLabDecimal] refuses. The limit is stored exactly as typed,
/// so a limit that is not plain digits as typed ("1 000", "5 ,4") is
/// `LIMIT_HAS_SPACE` rather than kept in a form the record refuses, and a
/// value longer than a text result is `TEXT_TOO_LONG`. Every error is about
/// the value field.
({LabComparator comparator, String limitText}) parseCensoredLab(String raw) {
  final t = raw.trim();
  if (t.isEmpty) throw const InputError('EMPTY', 'value');
  if (t.runes.length > LabPrintedResult.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'value');
  }
  LabComparator? comparator;
  var rest = '';
  // Longest typed form first, so "<=" is never read as "<" then "=".
  for (final e in LabComparator.typed.entries) {
    if (t.startsWith(e.key)) {
      comparator = e.value;
      rest = t.substring(e.key.length).trim();
      break;
    }
  }
  if (comparator == null) {
    throw InputError(
      _comparatorFirst.hasMatch(t)
          ? 'COMPARATOR_UNCLEAR'
          : 'CENSORED_NEEDS_COMPARATOR',
      'value',
    );
  }
  if (rest.isEmpty) throw const InputError('CENSORED_NEEDS_NUMBER', 'value');
  if (_comparatorFirst.hasMatch(rest)) {
    throw const InputError('COMPARATOR_UNCLEAR', 'value');
  }
  if (_unitAfterNumber.hasMatch(rest)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  try {
    parseLabDecimal(rest);
  } on InputError catch (e) {
    throw InputError(e.code, 'value');
  }
  // parseLabDecimal drops inner spaces; the limit is kept as typed, so it
  // must already be plain digits (review R017).
  if (!LabPrintedResult.limitPattern.hasMatch(rest)) {
    throw const InputError('LIMIT_HAS_SPACE', 'value');
  }
  return (comparator: comparator, limitText: rest);
}

/// Invisible characters that change the direction of the text around them
/// (U+202A–U+202E, U+2066–U+2069) and the direction marks U+200E, U+200F
/// and U+061C. Kept, one of them could reorder a summary line.
final RegExp _directionMarks = RegExp(
  r'[\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C]',
);

/// Control characters (Unicode Cc: tabs, line breaks and the rest).
final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F]');

/// A plain number, signed or not, once spaces are removed.
final RegExp _signedNumber = RegExp(r'^[+\-\u2212]?\d+([.,]\d+)?$');

/// A leading sign and the spaces after it.
final RegExp _leadingSign = RegExp(r'^[+\-\u2212]\s*');

/// The text of a lab result as it is stored: direction marks removed and
/// each control character (a pasted line break or tab) made a space, then
/// surrounding spaces trimmed. Nothing visible changes.
String labTextAsStored(String raw) =>
    raw.replaceAll(_directionMarks, '').replaceAll(_controlChars, ' ').trim();

/// A lab result printed as text ("Pozitif", "Reaktif değil", "1+", a titre
/// such as "1/160"), kept verbatim apart from surrounding spaces and the
/// invisible characters [labTextAsStored] removes. Refused, because each
/// has its own kind and must not hide from what a number can do: a plain
/// number, signed or not (`TEXT_IS_A_NUMBER`); a number with a unit after
/// it, "5 mg/dL" or "6 %" (`UNIT_IN_VALUE`); a sign and a number, with or
/// without a unit, "<5 mg/dL" (`TEXT_IS_CENSORED`).
String parseLabText(String raw) {
  final t = labTextAsStored(raw);
  if (t.isEmpty) throw const InputError('EMPTY', 'value');
  if (t.runes.length > LabPrintedResult.maxTextLength) {
    throw const InputError('TEXT_TOO_LONG', 'value');
  }
  if (_signedNumber.hasMatch(t.replaceAll(' ', ''))) {
    throw const InputError('TEXT_IS_A_NUMBER', 'value');
  }
  if (_comparatorFirst.hasMatch(t)) {
    final rest = t.replaceFirst(RegExp(r'^[<>≤≥=\s]+'), '');
    if (RegExp(r'^\d').hasMatch(rest) && !_titre.hasMatch(rest)) {
      throw const InputError('TEXT_IS_CENSORED', 'value');
    }
  }
  final unsigned = t.replaceFirst(_leadingSign, '');
  if (_unitAfterNumber.hasMatch(unsigned) && !_titre.hasMatch(unsigned)) {
    throw const InputError('UNIT_IN_VALUE', 'value');
  }
  return t;
}

/// The method as printed, or null when blank (field `method`).
String? parseLabMethod(String raw) {
  final m = labTextAsStored(raw);
  if (m.isEmpty) return null;
  if (m.runes.length > LabDetails.maxMethodLength) {
    throw const InputError('TEXT_TOO_LONG', 'method');
  }
  return m;
}

/// A report time starts with the date the laboratory printed.
final RegExp _reportDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) ');

/// A clock time alone, as the "When" fields accept it.
final RegExp _bareTime = RegExp(r'^\d{1,2}:\d{2}$');

/// When the laboratory reported the result, or null when blank. The "When"
/// rules of [parseMeasuredAt], every error on the field `reportTime`, except
/// that a bare time ("14:30") is refused with `REPORT_TIME_NEEDS_DATE`: a
/// report is often entered days after it was printed, so a time alone is
/// never read as today. A report dated before the sample day, compared by
/// the date as typed (also when an offset is typed), is
/// `REPORT_BEFORE_SAMPLE`.
DateTime? parseReportTime(
  String raw, {
  required DateTime nowUtc,
  required DateTime sampleDay,
  LocalZone zone = const SystemLocalZone(),
}) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  // Checked before the time itself, so "14:30" later today is not
  // reported as a future time either.
  if (_bareTime.hasMatch(text)) {
    throw const InputError('REPORT_TIME_NEEDS_DATE', 'reportTime');
  }
  final DateTime? t;
  try {
    t = parseMeasuredAt(text, nowUtc: nowUtc, zone: zone);
  } on InputError catch (e) {
    throw InputError(e.code, 'reportTime');
  }
  final typed = _reportDate.firstMatch(text);
  if (t == null || typed == null) {
    throw const InputError('REPORT_TIME_NEEDS_DATE', 'reportTime');
  }
  final day = DateTime.utc(
    int.parse(typed[1]!),
    int.parse(typed[2]!),
    int.parse(typed[3]!),
  );
  if (day.isBefore(sampleDay)) {
    throw const InputError('REPORT_BEFORE_SAMPLE', 'reportTime');
  }
  return t;
}
