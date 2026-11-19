/// How measurements are shown and spoken (ladder F007). A number is shown
/// with the decimals it was typed with, never more ("57" stays 57, "84,25"
/// is 84.25); blood pressure is one reading, "118/76 mmHg"; a value that
/// does not exist is named, never drawn as 0.
library;

import 'package:flutter/services.dart';

import '../../domain/records/health_record.dart';
import '../../l10n/casing.dart';
import '../../l10n/strings.dart';

/// [v] with exactly the decimals of [typed] when [typed] is that number,
/// otherwise its shortest form.
String fmtMeasured(double v, String? typed) {
  final t = typed?.trim().replaceAll(' ', '');
  if (t != null) {
    final m = RegExp(r'^\d+(?:[.,](\d+))?$').firstMatch(t);
    if (m != null && double.parse(t.replaceAll(',', '.')) == v) {
      final decimals = m[1]?.length ?? 0;
      // toStringAsFixed takes 0..20 decimals and switches to exponent form
      // from 1e21; any such text is shown as typed (dot as decimal point).
      if (decimals <= 20 && v.abs() < 1e21) return v.toStringAsFixed(decimals);
      return t.replaceAll(',', '.');
    }
  }
  if (v.abs() >= 1e21) return typed?.trim() ?? v.toString();
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// [fmtMeasured] in the decimal mark of the shown language (Turkish
/// "72,4"); the stored value and the typed text are unchanged.
String fmtShown(S s, double v, String? typed) =>
    decimalIn(s.lang, fmtMeasured(v, typed));

/// The value of a measurement record with its unit, or its value status.
String measurementValue(S s, HealthRecord r) {
  if (r.valueStatus != ValueStatus.present) return s.valueStatus(r.valueStatus);
  final d = r.details;
  if (d is BloodPressureDetails) {
    return '${fmtShown(s, d.systolic, d.systolicText)}/'
        '${fmtShown(s, d.diastolic, d.diastolicText)} ${s.unit(d.unit)}';
  }
  final q = r.quantity;
  if (q == null) return s.valueStatus(r.valueStatus);
  return '${fmtShown(s, q.value, r.originalText)} ${s.unit(q.unit ?? '')}'
      '${s.converted(q.value, q.unit)}';
}

/// The value as a screen reader should say it.
String spokenMeasurement(S s, HealthRecord r) {
  if (r.valueStatus != ValueStatus.present) return s.valueStatus(r.valueStatus);
  final d = r.details;
  if (d is BloodPressureDetails) {
    return '${s.spokenBloodPressure(fmtShown(s, d.systolic, d.systolicText), fmtShown(s, d.diastolic, d.diastolicText))} '
        '${s.spokenUnit(d.unit)}';
  }
  final q = r.quantity;
  if (q == null) return s.valueStatus(r.valueStatus);
  return '${fmtShown(s, q.value, r.originalText)} ${s.spokenUnit(q.unit ?? '')}'
      '${s.convertedSpoken(q.value, q.unit)}';
}

/// What was typed, when it differs from what is shown ('entered as "…"').
String? typedWhenDifferent(HealthRecord r) {
  final d = r.details;
  if (d is BloodPressureDetails) {
    final typed = '${d.systolicText ?? ''}/${d.diastolicText ?? ''}';
    final shown =
        '${fmtMeasured(d.systolic, d.systolicText)}/'
        '${fmtMeasured(d.diastolic, d.diastolicText)}';
    return (d.systolicText == null && d.diastolicText == null) || typed == shown
        ? null
        : typed;
  }
  final original = r.originalText;
  final q = r.quantity;
  if (original == null || q == null) return null;
  return original == fmtMeasured(q.value, original) ? null : original;
}

/// The newest live entry of a measurement that has a value: a newer "not
/// measured" entry is history, never shown as the latest value.
TimelineEntry? latestWithValue(List<TimelineEntry> entries) =>
    entries.where((e) => e.heads.any(hasMeasuredValue)).firstOrNull;

bool hasMeasuredValue(HealthRecord r) =>
    r.valueStatus == ValueStatus.present &&
    (r.kind.isStructured ? r.details != null : r.quantity != null);

/// Limits a note to [HealthRecord.maxContextLength] Unicode code points, the
/// unit the record rule counts: the field stops where Save would refuse
/// (the stock length limiter counts differently for emoji).
class ContextLengthFormatter extends TextInputFormatter {
  const ContextLengthFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final runes = newValue.text.runes;
    if (runes.length <= HealthRecord.maxContextLength) return newValue;
    // Keep the old value: a paste that is too long is refused whole.
    return oldValue;
  }
}

/// When the record was saved, as text, if that differs from the measured
/// time by more than a minute (either way); null when they agree.
String? savedWhenDifferent(HealthRecord r, String Function(DateTime) fmt) =>
    r.recordedAt.difference(r.observedAt).abs() > const Duration(seconds: 60)
    ? fmt(r.recordedAt)
    : null;

/// "measured time · source", plus "saved <time>" when it differs.
String whenCaption(S s, HealthRecord r, String Function(DateTime) fmt) {
  final saved = savedWhenDifferent(r, fmt);
  final base = '${fmt(r.observedAt)} · ${s.provenanceKind(r.provenance.kind)}';
  return saved == null ? base : '$base · ${s.savedAtLabel(saved)}';
}

/// Notes the person typed on earlier measurements, newest first, each once
/// (trimmed, compared without case), at most [max]. Their own words: no
/// fixed vocabulary is added.
List<String> previousNotes(List<HealthRecord> records, {int max = 8}) {
  // Only the current version of entries still in use: a withdrawn, deleted
  // or corrected-away note is not offered again.
  final sorted = [
    for (final e in buildTimeline(records))
      if (e.isLive && (e.shown.context ?? '').trim().isNotEmpty) e.shown,
  ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  final seen = <String>{};
  final out = <String>[];
  for (final r in sorted) {
    final n = r.context!.trim();
    if (seen.add(n.toLowerCase())) out.add(n);
    if (out.length == max) break;
  }
  return out;
}

/// A lab value that is not a plain number (F004-S2, D-043), exactly as
/// printed: a censored value says the printed sign in words and repeats
/// what was typed; a text value is the text with its unit. No judgement.
String labPrintedValue(S s, HealthRecord r, LabPrintedResult p) =>
    switch (p.kind) {
      LabValueKind.censored => s.labCensoredValue(
        p.comparator!,
        p.limitText!,
        p.unit,
        r.originalText ?? '${p.comparator!.symbol} ${p.limitText}',
      ),
      _ => s.labTextValue(p.text ?? r.originalText ?? '', p.unit),
    };

/// What else the report printed (F004-S3, D-045), one line each, only for
/// what is present: report time, method and the reference interval as
/// printed. Plain restatement; nothing here relates the value to the
/// interval. [when] formats the report time for its surface.
List<String> labReportLines(
  S s,
  LabDetails lab,
  String Function(DateTime utc) when,
) => [
  if (lab.reportedAt case final t?) s.labReportTimeLine(when(t)),
  if (lab.method case final m?) s.labMethodLine(m),
  if (lab.referenceInterval case final iv?) s.labIntervalLine(iv),
];
