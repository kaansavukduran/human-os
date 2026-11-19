import '../domain/errors.dart';

class InputError implements Exception, CodedError {
  const InputError(this.code, [this.field]);

  /// Stable code; the UI maps it to localized text.
  /// `EMPTY` · `NOT_A_NUMBER` · `OUT_OF_RANGE` · `FUTURE_TIME` ·
  /// `TARGET_NOT_FOUND` · `TARGET_NOT_CURRENT` · `TARGET_WRONG_KIND` ·
  /// `LAB_ANALYTE_EMPTY` · `DATE_INVALID` · `AMBIGUOUS_SEPARATOR` ·
  /// `NOT_POSITIVE` · `BP_ORDER` · `CONTEXT_TOO_LONG` ·
  /// `OUT_OF_DEFINITION` · `TIME_FORMAT` · `TIME_TOO_OLD` ·
  /// `TIME_DOES_NOT_EXIST` · `TIME_AMBIGUOUS` · lab values (D-043):
  /// `VALUE_HAS_COMPARATOR` · `UNIT_IN_VALUE` · `CENSORED_NEEDS_COMPARATOR` ·
  /// `CENSORED_NEEDS_NUMBER` · `COMPARATOR_UNCLEAR` · `LIMIT_HAS_SPACE` ·
  /// `TEXT_IS_A_NUMBER` · `TEXT_IS_CENSORED` · `TEXT_TOO_LONG` · lab report
  /// details (D-045): `REPORT_BEFORE_SAMPLE` · `INTERVAL_NEEDS_BOUND` ·
  /// `INTERVAL_UNIT_REQUIRED` · `INTERVAL_LOW_ABOVE_HIGH` ·
  /// `INTERVAL_BOUND_HAS_SIGN` · `INTERVAL_BOUND_HAS_UNIT` ·
  /// `INTERVAL_BOUND_HAS_SPACE`
  @override
  final String code;

  /// Which input the error belongs to, when a form has several
  /// (`value`, `systolic`, `diastolic`, `context`, and on Labs
  /// `reportTime`, `method`, `refLow`, `refHigh`, `refUnit`,
  /// `refPartition`); null otherwise.
  final String? field;

  @override
  String toString() => 'InputError($code)';
}
