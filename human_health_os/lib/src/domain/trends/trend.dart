/// The person's own values over time, as points (U008). Pure arithmetic on
/// what was saved: nothing is interpolated, averaged, smoothed or judged.
library;

import 'dart:math' as math;

import '../records/health_record.dart';

/// One saved reading: its time and its value(s) (blood pressure has two).
class TrendPoint {
  const TrendPoint({
    required this.at,
    required this.values,
    required this.record,
  });

  final DateTime at;
  final List<double> values;
  final HealthRecord record;
}

/// Two readings further apart than this are not joined by a line: the
/// chart shows a gap, because nothing is known in between.
const Duration trendGap = Duration(days: 7);

/// The current version of every live entry with a value, oldest first.
/// Withdrawn, deleted and "not recorded" entries are left out (missing is
/// not zero).
List<TrendPoint> trendPoints(List<TimelineEntry> entries) {
  final out = <TrendPoint>[];
  for (final e in entries) {
    if (!e.isLive) continue;
    final r = e.shown;
    if (r.valueStatus != ValueStatus.present) continue;
    final d = r.details;
    if (d is BloodPressureDetails) {
      out.add(
        TrendPoint(
          at: r.observedAt,
          values: [d.systolic, d.diastolic],
          record: r,
        ),
      );
      continue;
    }
    final q = r.quantity;
    if (q == null) continue;
    out.add(TrendPoint(at: r.observedAt, values: [q.value], record: r));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// The same for records that are already current (weight).
List<TrendPoint> trendPointsFromRecords(List<HealthRecord> records) {
  final out = <TrendPoint>[
    for (final r in records)
      if (r.valueStatus == ValueStatus.present && r.quantity != null)
        TrendPoint(at: r.observedAt, values: [r.quantity!.value], record: r),
  ];
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// The unit of a point's value.
String? unitOf(TrendPoint p) => switch (p.record.details) {
  BloodPressureDetails(:final unit) => unit,
  _ => p.record.quantity?.unit,
};

/// The points a chart may draw on one axis: those in the newest point's
/// unit. A kind kept in the unit it was typed in (capillary glucose, mg/dL
/// or mmol/L; D-048) never has two units on one axis and is never
/// converted; the other points are still listed as text.
List<TrendPoint> sameUnitAsNewest(List<TrendPoint> points) {
  if (points.isEmpty) return points;
  final u = unitOf(points.last);
  return [
    for (final p in points)
      if (unitOf(p) == u) p,
  ];
}

/// Points at or after [from] (null keeps all).
List<TrendPoint> inRange(List<TrendPoint> points, DateTime? from) => [
  for (final p in points)
    if (from == null || !p.at.isBefore(from)) p,
];

/// Runs of points joined by lines; a new run starts after a gap longer than
/// [gap].
List<List<TrendPoint>> segments(
  List<TrendPoint> points, {
  Duration gap = trendGap,
}) {
  final out = <List<TrendPoint>>[];
  for (final p in points) {
    if (out.isEmpty || p.at.difference(out.last.last.at) > gap) {
      out.add([p]);
    } else {
      out.last.add(p);
    }
  }
  return out;
}

/// The value range a chart shows for [values]: at least [minSpan] wide
/// (centred on the data), then 10% padding above and below. A tiny change
/// therefore never fills the whole height.
({double lo, double hi, double pad}) axisRange(
  List<double> values,
  double minSpan,
) {
  var lo = values.reduce((a, b) => a < b ? a : b);
  var hi = values.reduce((a, b) => a > b ? a : b);
  if (hi - lo < minSpan) {
    final mid = (hi + lo) / 2;
    hi = mid + minSpan / 2;
    lo = mid - minSpan / 2;
  }
  final pad = (hi - lo) * 0.1;
  return (lo: lo - pad, hi: hi + pad, pad: pad);
}

/// The three reading lines a chart labels: just inside the bottom, the
/// middle and just inside the top of [axisRange].
List<double> readingLines(({double lo, double hi, double pad}) r) => [
  r.lo + r.pad,
  (r.lo + r.hi) / 2,
  r.hi - r.pad,
];

/// A reading-line label with the person's decimal separator. Without
/// [decimals]: none from 100 up, else one (the measurement charts).
String axisLabel(double v, String decimal, [int? decimals]) => v
    .toStringAsFixed(decimals ?? (v.abs() >= 100 ? 0 : 1))
    .replaceAll('.', decimal);

/// Decimals enough for the reading lines of [r] to read differently: the
/// step between two lines sets the last digit shown (F004-S4: troponin
/// 0.01 to 0.03 ng/mL is not labelled "0.0" three times). At most 6.
int axisDecimals(({double lo, double hi, double pad}) r) {
  final step = (r.hi - r.lo - 2 * r.pad) / 2;
  if (!(step > 0) || !step.isFinite) return 1;
  final d = -(math.log(step) / math.ln10).floor();
  return d.clamp(0, 6);
}

/// Horizontal positions of [points] between [left] and [right], by time;
/// a single point sits in the middle.
List<double> timePositions(List<TrendPoint> points, double left, double right) {
  final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
  final t1 = points.last.at.millisecondsSinceEpoch.toDouble();
  final w = right - left;
  return [
    for (final p in points)
      t1 == t0
          ? left + w / 2
          : left + (p.at.millisecondsSinceEpoch - t0) / (t1 - t0) * w,
  ];
}

/// Date labels under the horizontal axis: the first and last days, or one
/// centred label when all plotted points fall on the same day (Q003: avoids
/// painting two touching copies of the same date).
///
/// Each entry gives its anchor [x], its [text] and its horizontal [align]
/// (`0.0` left-aligned, `0.5` centred, `1.0` right-aligned).
List<({double x, String text, double align})> axisDateLabels(
  List<double> xs,
  List<String> days,
) {
  if (xs.isEmpty || days.isEmpty) return const [];
  if (days.length == 1 || days.first == days.last) {
    return [(x: (xs.first + xs.last) / 2, text: days.first, align: 0.5)];
  }
  return [
    (x: xs.first, text: days.first, align: 0.0),
    (x: xs.last, text: days.last, align: 1.0),
  ];
}

/// The earliest time a range shows, counted back from [now]; null shows all.
DateTime? rangeStart(int? days, DateTime now) =>
    days == null ? null : now.subtract(Duration(days: days));
