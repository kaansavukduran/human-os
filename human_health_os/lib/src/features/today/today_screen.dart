import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../core/ids.dart' show Clock;
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/midnight_refresh.dart';
import '../../presentation/widgets/tool_row.dart';
import '../derived/derived_screen.dart';
import '../genetics/genetics_screen.dart';
import '../phyto/phyto_screen.dart';
import '../report/summary_screen.dart';
import 'measurements_card.dart';
import 'feeling_card.dart';
import 'sleep_card.dart';
import 'weight_card.dart';
import 'your_data_card.dart';
import 'discovery_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // The cards are made once per services: when the screen builds again
  // (another section shown, the shell rebuilt), Flutter keeps a card that
  // is the same widget as before and does not build it again (U031-S4).
  late WeightCard _weight;
  late MeasurementsCard _measurements;
  late SleepCard _sleep;
  late FeelingCard _feeling;
  late YourDataCard _yourData;

  @override
  void initState() {
    super.initState();
    _makeCards();
  }

  @override
  void didUpdateWidget(TodayScreen old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) _makeCards();
  }

  void _makeCards() {
    final services = widget.services;
    // Keyed, so a card moved by the order settings keeps its element and
    // what was typed in it.
    _weight = WeightCard(
      key: const ValueKey('today-card-weight'),
      services: services,
    );
    _measurements = MeasurementsCard(
      key: const ValueKey('today-card-measurements'),
      services: services,
    );
    _sleep = SleepCard(
      key: const ValueKey('today-card-sleep'),
      services: services,
    );
    _feeling = FeelingCard(
      key: const ValueKey('today-card-feeling'),
      services: services,
    );
    _yourData = YourDataCard(
      key: const ValueKey('today-card-your-data'),
      services: services,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final today = destinationById(DestinationId.today);
    // Only what Today shows: a change to anything else does not build
    // Today again.
    final look =
        AppearanceScope.watch(context, AppearanceAspect.todayLayout) ??
        const AppearanceSettings();
    final hidden = look.hiddenSections;
    final weight = _weight;
    final measurements = _measurements;
    bool show(TodaySection x) => !hidden.contains(x);
    // Sleep and How you feel, together; placed first when chosen.
    final checkIns = [
      if (show(TodaySection.sleep)) ...[
        _sleep,
        const SizedBox(height: Space.section),
      ],
      if (show(TodaySection.feeling)) ...[
        _feeling,
        const SizedBox(height: Space.section),
      ],
    ];
    return ListView(
      key: const ValueKey('screen-today'),
      padding: kPagePadding,
      children: [
        Semantics(
          header: true,
          child: Text(today.label(s.lang), style: text.headlineSmall),
        ),
        const SizedBox(height: Space.xs),
        _DateLine(clock: services.heartbeat.clock),
        const SizedBox(height: Space.xl),
        if (look.checkInsFirst) ...checkIns,
        look.measurementsFirst ? measurements : weight,
        const SizedBox(height: Space.section),
        look.measurementsFirst ? weight : measurements,
        const SizedBox(height: Space.section),
        if (!look.checkInsFirst) ...checkIns,
        if (show(TodaySection.tools)) ...[
          Semantics(
            container: true,
            header: true,
            child: Text(s.geneticsToolsTitle, style: text.titleMedium),
          ),
          const SizedBox(height: Space.m),
          _ToolGroup(s.toolsGroupApp),
          // Settings is not repeated here: the app bar and the rail or More
          // sheet already open it (U030, one entry less). The glossary, the
          // body guide and the how-to live in Learn (U034), not here.
          ToolRow(
            key: const ValueKey('tool-summary'),
            title: s.summaryTitle,
            hint: s.summaryTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SummaryScreen(services: services),
              ),
            ),
          ),
          ToolRow(
            key: const ValueKey('tool-derived'),
            title: s.derivedTitle,
            hint: s.derivedTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DerivedScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ToolGroup(s.toolsGroupFiles),
          ToolRow(
            key: const ValueKey('tool-phyto'),
            title: s.phytoTitle,
            hint: s.phytoTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhytoScreen(services: services),
              ),
            ),
          ),
          ToolRow(
            key: const ValueKey('tool-genetics'),
            title: s.geneticsTitle,
            hint: s.geneticsTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GeneticsScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: Space.section),
        ],
        if (show(TodaySection.yourData)) ...[
          _yourData,
          const SizedBox(height: Space.section),
        ],
        if (look.discoveryEnabled) ...[
          DiscoveryCard(services: services),
          const SizedBox(height: Space.section),
        ],
      ],
    );
  }
}

/// Today's date, written again just after each local midnight, so a screen
/// left open overnight never shows yesterday (U031-S4). Timers do not run
/// while the device sleeps and miss a clock or time-zone change, so the line
/// is also written again whenever the app comes back to the foreground.
class _DateLine extends StatefulWidget {
  const _DateLine({required this.clock});

  final Clock clock;

  @override
  State<_DateLine> createState() => _DateLineState();
}

class _DateLineState extends State<_DateLine>
    with WidgetsBindingObserver, MidnightRefresh {
  @override
  Clock get midnightClock => widget.clock;

  @override
  void didUpdateWidget(_DateLine old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) scheduleMidnight();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      S.of(context).dateLine(widget.clock.nowUtc().toLocal()),
      key: const ValueKey('today-date'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

/// A small heading over a group of tools (G-65), announced as a heading.
class _ToolGroup extends StatelessWidget {
  const _ToolGroup(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
