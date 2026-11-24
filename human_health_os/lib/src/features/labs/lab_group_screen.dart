import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/labs/lab_groups.dart';
import '../../domain/records/health_record.dart';
import '../../domain/settings/date_style.dart';
import '../../domain/trends/trend.dart';
import '../../l10n/strings.dart';
import '../../presentation/widgets/status_chip.dart';
import '../measurements/measurement_format.dart' show labReportLines;
import '../timeline/timeline_screen.dart' show fmtValue, fmtWhen;
import '../trends/trend_screen.dart' show TrendPainter;

/// A lab sample date: a calendar day, shown without a time-zone shift.
String labDay(DateTime d) =>
    formatDay(d.year, d.month, d.day, displayDateOrder);

/// One lab test over time (F004-S4): every current result with the same
/// name, unit and specimen as typed, newest first, each exactly as printed
/// with its own flag, laboratory and range. A small chart places the plain
/// numbers by sample date; limits, text and missing values are listed, not
/// drawn. No band, no colour per value, no "within range".
class LabGroupScreen extends StatelessWidget {
  const LabGroupScreen({super.key, required this.group});

  final LabGroup group;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final points = group.chartPoints;
    final unit = group.unit;
    final muted = text.bodySmall?.copyWith(color: scheme.outline);
    final spokenValues = [
      for (final p in points) '${labDay(p.at)}: ${fmtValue(s, p.record)}',
    ].join('; ');
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.trendTitle(group.label)),
        ),
      ),
      body: ListView(
        key: const ValueKey('screen-lab-group'),
        padding: const EdgeInsets.all(16),
        children: [
          // The full name, which the app bar may cut short at 320 dp.
          Text(
            s.labGroupNameAsTyped(group.label),
            key: const ValueKey('lab-group-name'),
            style: text.bodyMedium,
          ),
          Text(s.labGroupUnit(unit), style: text.bodyMedium),
          if (group.specimen case final sp?)
            Text(s.labGroupSpecimen(sp), style: text.bodyMedium),
          const SizedBox(height: 4),
          Text(
            s.labGroupsRule,
            key: const ValueKey('lab-group-rule'),
            style: muted,
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            Text(
              s.labGroupNoChart,
              key: const ValueKey('lab-group-no-chart'),
              style: text.bodyMedium,
            )
          else ...[
            ExcludeSemantics(
              child: Text(
                unit == null ? s.labGroupAxisNoUnit : s.trendAxisUnit(unit),
                key: const ValueKey('lab-group-axis-unit'),
                style: muted,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              key: const ValueKey('lab-group-chart-summary'),
              container: true,
              label: s.labGroupChartSpoken(
                points.length,
                unit == null ? null : s.spokenUnit(unit),
                spokenValues,
              ),
              child: SizedBox(
                key: const ValueKey('lab-group-chart'),
                height: 200,
                child: LayoutBuilder(
                  builder: (context, box) => CustomPaint(
                    size: box.biggest,
                    painter: TrendPainter(
                      points: points,
                      minSpan: _minSpan(points),
                      decimal: s.lang == AppLang.tr ? ',' : '.',
                      line: scheme.primary,
                      second: scheme.onSurface,
                      grid: scheme.outlineVariant,
                      label: scheme.outline,
                      picked: null,
                      textStyle: text.labelSmall ?? const TextStyle(),
                      join: false,
                      dayLabel: labDay,
                      decimalsFromSpan: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(s.labGroupLegend, style: muted),
            if (group.sameDayDrawn)
              Text(
                s.labGroupSameDay,
                key: const ValueKey('lab-group-same-day'),
                style: muted,
              ),
          ],
          for (final MapEntry(key: reason, value: n) in group.notDrawn.entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.labGroupNotDrawn(reason, n),
                key: ValueKey('lab-group-not-drawn-$reason'),
                style: muted,
              ),
            ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            header: true,
            child: Text(s.labGroupEvery, style: text.titleSmall),
          ),
          const SizedBox(height: 4),
          for (final row in group.rows)
            _GroupResult(
              key: ValueKey('lab-group-row-${row.record.id}'),
              record: row.record,
              conflict: row.conflict,
              groupLabel: group.label,
            ),
        ],
      ),
    );
  }

  /// The smallest axis range: a fifth of the largest value, so a small
  /// change between two results does not fill the chart's height.
  static double _minSpan(List<TrendPoint> points) {
    final top = points.map((p) => p.values.first.abs()).reduce(math.max);
    return math.max(top * 0.2, 0.001);
  }
}

class _GroupResult extends StatelessWidget {
  const _GroupResult({
    super.key,
    required this.record,
    required this.conflict,
    required this.groupLabel,
  });

  final HealthRecord record;
  final bool conflict;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final lab = record.lab!;
    final name = lab.analyteLabel.trim();
    return Card(
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.labSampleDate}: ${labDay(record.observedAt)}',
              style: text.bodySmall,
            ),
            Text(fmtValue(s, record), style: text.titleMedium),
            // The same name in other letters (e.g. "hba1c") is said as
            // typed, so nothing looks renamed.
            if (name != groupLabel)
              Text(s.labGroupNameAsTyped(name), style: text.bodySmall),
            if (lab.laboratory case final l?)
              Text(s.labGroupLaboratory(l), style: text.bodySmall),
            if (lab.sourceFlag != null || conflict)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (lab.sourceFlag case final f?)
                      StatusChip(
                        label: s.labPrintedFlag(f),
                        tone: StatusTone.muted,
                      ),
                    if (conflict)
                      StatusChip(
                        label: s.entryStatus(EntryStatus.conflict),
                        tone: StatusTone.warn,
                      ),
                  ],
                ),
              ),
            Text(
              lab.referenceText == null
                  ? s.labNoRangePrinted
                  : s.labPrintedRange(lab.referenceText!),
              key: ValueKey('lab-group-range-${record.id}'),
              style: text.bodySmall,
            ),
            for (final line in labReportLines(s, lab, fmtWhen))
              Text(line, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
