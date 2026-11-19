/// A laboratory result as the report printed it (ladder F004).
///
/// Pure Dart. Everything here is **source text**, kept verbatim: the
/// analyte label, the printed flag and the printed reference range. None of
/// it is an app interpretation; Human OS does not compare values with ranges
/// or label results (reference interval ≠ optimal target ≠ clinical decision
/// limit; outside reference ≠ critical). A field the report did not print is
/// null, never a default.
///
/// Record schema 14 (F004-S2, D-043) adds [LabPrintedResult]: a result that
/// is not a plain number, kept exactly as printed. A censored result ("< 5",
/// "≥ 90") keeps its comparator and its number as typed and is never equal
/// to its limit; a text result ("Pozitif", "1+") is kept verbatim and never
/// mapped to a meaning. Neither is ever read as a number.
library;

/// How a lab result is printed: a plain number (the record's quantity), a
/// number with a comparator ("< 5"), or text ("Pozitif").
enum LabValueKind {
  number('number'),
  censored('censored'),
  text('text');

  const LabValueKind(this.code);
  final String code;

  static LabValueKind fromCode(String code) => LabValueKind.values.firstWhere(
    (k) => k.code == code,
    orElse: () => throw FormatException('Unknown lab value kind "$code"'),
  );
}

/// The comparator of a censored result, stored as one canonical symbol.
/// What was typed ("<=", "=<", "≤") stays in the record's original text.
enum LabComparator {
  lessThan('<'),
  lessOrEqual('≤'),
  greaterThan('>'),
  greaterOrEqual('≥');

  const LabComparator(this.symbol);
  final String symbol;

  /// The typed forms read as each comparator. "=<" and "=>" are accepted
  /// because some reports print them; they have no other reading.
  static const Map<String, LabComparator> typed = {
    '<=': lessOrEqual,
    '=<': lessOrEqual,
    '≤': lessOrEqual,
    '>=': greaterOrEqual,
    '=>': greaterOrEqual,
    '≥': greaterOrEqual,
    '<': lessThan,
    '>': greaterThan,
  };

  static LabComparator fromSymbol(String symbol) =>
      LabComparator.values.firstWhere(
        (c) => c.symbol == symbol,
        orElse: () => throw FormatException('Unknown comparator "$symbol"'),
      );
}

/// A lab result that is not a plain number (record schema 14): censored or
/// text, with the unit as printed. The record carries no quantity: the value
/// is not a number the app may calculate with.
class LabPrintedResult {
  const LabPrintedResult.censored({
    required LabComparator this.comparator,
    required String this.limitText,
    this.unit,
  }) : kind = LabValueKind.censored,
       text = null;

  const LabPrintedResult.text({required String this.text, this.unit})
    : kind = LabValueKind.text,
      comparator = null,
      limitText = null;

  const LabPrintedResult._(
    this.kind,
    this.comparator,
    this.limitText,
    this.text,
    this.unit,
  );

  /// Longest text result kept, in characters (Unicode code points).
  static const int maxTextLength = 300;

  /// The digits of a limit as typed: "5", "0,1", "1000" (no sign, no
  /// thousands separator; "," or "." as the decimal mark).
  static final RegExp limitPattern = RegExp(r'^\d+([.,]\d+)?$');

  /// [LabValueKind.censored] or [LabValueKind.text], never number.
  final LabValueKind kind;

  /// Censored only.
  final LabComparator? comparator;

  /// Censored only: the number exactly as typed ("5,4"). Never parsed into
  /// a stored value: the true result is not this number.
  final String? limitText;

  /// Text only: the result exactly as printed.
  final String? text;

  /// The unit as printed; null = not given.
  final String? unit;

  /// A stable code when the stored shape is broken, else null.
  String? problem() {
    final u = unit;
    if (u != null && u.trim().isEmpty) return 'LAB_UNIT_EMPTY';
    switch (kind) {
      case LabValueKind.censored:
        final l = limitText;
        if (comparator == null || l == null || text != null) {
          return 'LAB_RESULT_SHAPE';
        }
        if (l.length > maxTextLength) return 'LAB_LIMIT_TOO_LONG';
        if (!limitPattern.hasMatch(l)) return 'LAB_LIMIT_NOT_A_NUMBER';
      case LabValueKind.text:
        final t = text;
        if (t == null || comparator != null || limitText != null) {
          return 'LAB_RESULT_SHAPE';
        }
        if (t.trim().isEmpty) return 'LAB_TEXT_EMPTY';
        if (t.runes.length > maxTextLength) return 'LAB_TEXT_TOO_LONG';
      case LabValueKind.number:
        return 'LAB_RESULT_SHAPE';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'kind': kind.code,
    if (comparator != null) 'comparator': comparator!.symbol,
    if (limitText != null) 'limit_text': limitText,
    if (text != null) 'text': text,
    'unit': unit,
  };

  static LabPrintedResult fromJson(Map<String, Object?> j) {
    final c = j['comparator'] as String?;
    return LabPrintedResult._(
      LabValueKind.fromCode(j['kind']! as String),
      c == null ? null : LabComparator.fromSymbol(c),
      j['limit_text'] as String?,
      j['text'] as String?,
      j['unit'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LabPrintedResult &&
      other.kind == kind &&
      other.comparator == comparator &&
      other.limitText == limitText &&
      other.text == text &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(kind, comparator, limitText, text, unit);
}

class LabDetails {
  const LabDetails({
    required this.analyteLabel,
    this.specimen,
    this.laboratory,
    this.sourceFlag,
    this.referenceText,
    this.result,
  });

  /// The test name exactly as printed (e.g. "HbA1c", "LDL Kolesterol").
  /// Not mapped to a code: the same display name is not the same measurand.
  final String analyteLabel;

  /// Sample type as printed (e.g. "serum"); null = not given.
  final String? specimen;

  /// Laboratory or provider as printed; null = not given.
  final String? laboratory;

  /// The flag the laboratory printed next to the value (e.g. "H", "↑", "*"),
  /// verbatim; null = no flag printed. Never computed by the app.
  final String? sourceFlag;

  /// The reference range exactly as printed (e.g. "70 - 100", "< 130");
  /// null = no range printed. Not parsed into numbers in F004.
  final String? referenceText;

  /// A censored or text result (record schema 14); null for a plain number
  /// or a value not reported. Written only when present, so a schema 3
  /// record keeps its exact bytes.
  final LabPrintedResult? result;

  /// How the value is printed. A not-reported value reads as number here;
  /// the record's value status says it is missing.
  LabValueKind get valueKind => result?.kind ?? LabValueKind.number;

  Map<String, Object?> toJson() => {
    'analyte_label': analyteLabel,
    'specimen': specimen,
    'laboratory': laboratory,
    'source_flag': sourceFlag,
    'reference_text': referenceText,
    if (result != null) 'result': result!.toJson(),
  };

  static LabDetails fromJson(Map<String, Object?> j) => LabDetails(
    analyteLabel: j['analyte_label']! as String,
    specimen: j['specimen'] as String?,
    laboratory: j['laboratory'] as String?,
    sourceFlag: j['source_flag'] as String?,
    referenceText: j['reference_text'] as String?,
    result: j['result'] == null
        ? null
        : LabPrintedResult.fromJson(
            (j['result']! as Map).cast<String, Object?>(),
          ),
  );

  @override
  bool operator ==(Object other) =>
      other is LabDetails &&
      other.analyteLabel == analyteLabel &&
      other.specimen == specimen &&
      other.laboratory == laboratory &&
      other.sourceFlag == sourceFlag &&
      other.referenceText == referenceText &&
      other.result == result;

  @override
  int get hashCode => Object.hash(
    analyteLabel,
    specimen,
    laboratory,
    sourceFlag,
    referenceText,
    result,
  );
}
