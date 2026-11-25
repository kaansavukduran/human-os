import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/settings/date_style.dart';
import '../../app/app_services.dart';
import '../../domain/records/health_record.dart';
import '../../domain/trends/trend.dart';
import '../../l10n/strings.dart';
import '../measurements/measurement_format.dart';
import '../timeline/timeline_screen.dart' show fmtWhen;
import '../../presentation/widgets/whole_chip.dart';

enum TrendRange { days30, days90, year, all }

/// Days a range chip shows; null for all.
int? rangeDays(TrendRange r) => switch (r) {
  TrendRange.days30 => 30,
  TrendRange.days90 => 90,
  TrendRange.year => 365,
  TrendRange.all => null,
};

/// One measurement over time (U008): the saved points, joined only when
/// they are close in time, a range to choose, and every point as text.
/// No target band, no colour that judges, no smoothing.
class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key, required this.services, required this.kind});

  final AppServices services;
  final RecordKind kind;

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  List<TrendPoint> _all = const [];
  bool _loaded = false;
  TrendRange _range = TrendRange.all;
  TrendPoint? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = widget.services.heartbeat;
    final me = widget.services.self.id;
    final points = widget.kind == RecordKind.bodyWeight
        ? trendPointsFromRecords(await svc.currentWeights(me))
        : trendPoints(await svc.measurementTimeline(me, widget.kind));
    if (mounted) {
      setState(() {
        _all = points;
        _loaded = true;
      });
    }
  }

  DateTime? _from() {
    return rangeStart(rangeDays(_range), DateTime.now().toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final listed = inRange(_all, _from());
    // One unit per axis (D-048): readings in another unit are listed below
    // the chart, never drawn beside these and never converted.
    final points = sameUnitAsNewest(listed);
    final otherUnits = listed.length - points.length;
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.trendTitle(s.recordKind(widget.kind))),
        ),
      ),
      body: ListView(
        key: const ValueKey('screen-trend'),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in TrendRange.values)
                WholeChip.choice(
                  key: ValueKey('trend-range-${r.name}'),
                  label: s.trendRange(r.name),
                  selected: _range == r,
                  onSelected: (_) => setState(() {
                    _range = r;
                    _picked = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_loaded)
            const SizedBox.shrink()
          else if (points.isEmpty)
            Text(s.trendNone, key: const ValueKey('trend-none'))
          else ...[
            // The one unit drawn is named over the chart and in its
            // spoken summary (D-048).
            if (unitOf(points.last) case final u? when u.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ExcludeSemantics(
                  child: Text(
                    s.trendAxisUnit(s.unit(u)),
                    key: const ValueKey('trend-axis-unit'),
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
              ),
            Semantics(
              key: const ValueKey('trend-chart-summary'),
              label: s.trendChartSpoken(
                points.length,
                unit: switch (unitOf(points.last)) {
                  final u? when u.isNotEmpty => s.spokenUnit(u),
                  _ => null,
                },
              ),
              child: SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    key: const ValueKey('trend-chart'),
                    onTapDown: (d) => setState(
                      () => _picked = _nearest(
                        points,
                        d.localPosition,
                        box.biggest,
                      ),
                    ),
                    child: CustomPaint(
                      size: box.biggest,
                      painter: TrendPainter(
                        points: points,
                        minSpan: minSpanFor(widget.kind, unitOf(points.last)),
                        decimal: s.lang == AppLang.tr ? ',' : '.',
                        line: scheme.primary,
                        second: scheme.onSurface,
                        grid: scheme.outlineVariant,
                        label: scheme.outline,
                        picked: picked,
                        textStyle: text.labelSmall ?? const TextStyle(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.kind == RecordKind.bloodPressure
                  ? s.trendLegendBp
                  : s.trendLegend,
              style: text.bodySmall?.copyWith(color: scheme.outline),
            ),
            if (otherUnits > 0) ...[
              const SizedBox(height: 4),
              Text(
                s.trendOtherUnits(
                  s.unit(unitOf(points.last) ?? ''),
                  otherUnits,
                ),
                key: const ValueKey('trend-other-units'),
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
            if (picked != null) ...[
              const SizedBox(height: 8),
              Text(
                '${measurementValue(s, picked.record)} · ${fmtWhen(picked.at)}',
                key: const ValueKey('trend-picked'),
                style: text.titleSmall,
              ),
            ],
            const SizedBox(height: 16),
            Text(s.trendAllPoints, style: text.titleSmall),
            for (final p in listed.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${fmtWhen(p.at)} — ${measurementValue(s, p.record)}',
                  style: text.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  TrendPoint? _nearest(List<TrendPoint> points, Offset at, Size size) {
    final xs = _xs(points, size);
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      if ((xs[i] - at.dx).abs() < (xs[best] - at.dx).abs()) best = i;
    }
    return points[best];
  }
}

const double _left = 56, _right = 12, _top = 8, _bottom = 22;

/// The smallest axis range per measure (in its stored unit).
double minSpanFor(RecordKind k, [String? unit]) => switch (k) {
  RecordKind.bodyWeight => 5,
  RecordKind.bloodPressure => 20,
  RecordKind.restingHeartRate => 20,
  RecordKind.bodyTemperature => 2,
  RecordKind.oxygenSaturation => 10,
  RecordKind.respiratoryRate => 10,
  RecordKind.waistCircumference => 10,
  RecordKind.height => 10,
  RecordKind.bodyFatPercentage => 5,
  // In the unit of the drawn readings (only one is drawn; D-048).
  RecordKind.capillaryGlucose => unit == 'mmol/L' ? 1 : 20,
  _ => 1,
};

List<double> _xs(List<TrendPoint> points, Size size) =>
    timePositions(points, _left, size.width - _right);

/// The trend chart (U008), also drawn by one lab test over time (F004-S4):
/// dots by time, three plain reading lines, the first and last dates. No
/// band, no colour per value.
class TrendPainter extends CustomPainter {
  TrendPainter({
    required this.points,
    required this.minSpan,
    required this.decimal,
    required this.line,
    required this.second,
    required this.grid,
    required this.label,
    required this.picked,
    required this.textStyle,
    this.join = true,
    this.dayLabel,
    this.decimalsFromSpan = false,
  });

  /// Whether the reading-line labels take as many decimals as the axis
  /// span needs ([axisDecimals]; labs). Off: the measurement charts' own
  /// labels, unchanged.
  final bool decimalsFromSpan;

  final List<TrendPoint> points;

  /// Whether close readings are joined by a line (labs: never; nothing is
  /// known between two samples).
  final bool join;

  /// The date under the axis; by default the local day of the instant. A
  /// lab sample date is a calendar day and is shown without a zone shift.
  final String Function(DateTime at)? dayLabel;

  /// The smallest value range the axis shows, so a tiny change does not
  /// fill the chart and look like a steep rise.
  final double minSpan;
  final String decimal;
  final Color line, second, grid, label;
  final TrendPoint? picked;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final range = axisRange([for (final p in points) ...p.values], minSpan);
    final lo = range.lo, hi = range.hi;
    final h = size.height - _top - _bottom;
    double y(double v) => _top + (hi - v) / (hi - lo) * h;
    final xs = _xs(points, size);

    // Three plain value lines for reading, not bands.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final decimals = decimalsFromSpan ? axisDecimals(range) : null;
    for (final v in readingLines(range)) {
      canvas.drawLine(
        Offset(_left, y(v)),
        Offset(size.width - _right, y(v)),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: axisLabel(v, decimal, decimals),
          style: textStyle.copyWith(color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(v) - tp.height / 2));
    }
    // First and last dates under the axis (one centred date when every point
    // falls on the same day; Q003).
    String day(DateTime t) {
      if (dayLabel case final f?) return f(t);
      final l = t.toLocal();
      return formatDay(l.year, l.month, l.day, displayDateOrder);
    }

    final dates = axisDateLabels(xs, [for (final p in points) day(p.at)]);
    double? rightEdge;
    for (final d in dates) {
      final tp = TextPainter(
        text: TextSpan(
          text: d.text,
          style: textStyle.copyWith(color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final maxX = math.max(0.0, size.width - tp.width);
      final x = (d.x - tp.width * d.align).clamp(0.0, maxX);
      if (rightEdge != null && x < rightEdge + 6) continue;
      tp.paint(canvas, Offset(x, size.height - tp.height));
      rightEdge = x + tp.width;
    }

    final series = points.first.values.length;
    final index = {for (var i = 0; i < points.length; i++) points[i]: i};
    for (var sIdx = 0; sIdx < series; sIdx++) {
      final color = sIdx == 0 ? line : second;
      final stroke = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (final seg in join ? segments(points) : const <List<TrendPoint>>[]) {
        final path = Path();
        for (var i = 0; i < seg.length; i++) {
          final o = Offset(xs[index[seg[i]]!], y(seg[i].values[sIdx]));
          i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, stroke);
      }
      final dot = Paint()..color = color;
      for (var i = 0; i < points.length; i++) {
        final o = Offset(xs[i], y(points[i].values[sIdx]));
        // The second series uses squares, so the two differ without colour.
        if (sIdx == 0) {
          canvas.drawCircle(o, points[i] == picked ? 6 : 4, dot);
        } else {
          final r = points[i] == picked ? 6.0 : 4.0;
          canvas.drawRect(
            Rect.fromCenter(center: o, width: r * 2, height: r * 2),
            dot,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(TrendPainter old) =>
      old.points != points || old.picked != picked || old.line != line;
}
