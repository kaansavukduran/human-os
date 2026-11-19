import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../core/capabilities.dart';
import '../../core/ids.dart' show Clock;
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../../navigation/destinations.dart';
import '../../presentation/widgets/status_chip.dart';
import '../derived/derived_screen.dart';
import '../genetics/genetics_screen.dart';
import '../guide/body_guide_screen.dart';
import '../guide/glossary_screen.dart';
import '../phyto/phyto_screen.dart';
import '../report/summary_screen.dart';
import '../help/how_to_screen.dart';
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
      if (show(TodaySection.sleep)) ...[_sleep, const SizedBox(height: 28)],
      if (show(TodaySection.feeling)) ...[_feeling, const SizedBox(height: 28)],
    ];
    return ListView(
      key: const ValueKey('screen-today'),
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(today.label(s.lang), style: text.headlineSmall),
        ),
        const SizedBox(height: 2),
        _DateLine(clock: services.heartbeat.clock),
        const SizedBox(height: 20),
        if (look.checkInsFirst) ...checkIns,
        look.measurementsFirst ? measurements : weight,
        const SizedBox(height: 28),
        look.measurementsFirst ? weight : measurements,
        const SizedBox(height: 28),
        if (!look.checkInsFirst) ...checkIns,
        if (show(TodaySection.tools)) ...[
          Semantics(
            container: true,
            header: true,
            child: Text(s.geneticsToolsTitle, style: text.titleMedium),
          ),
          const SizedBox(height: 12),
          _ToolGroup(s.toolsGroupApp),
          // Settings is not repeated here: the app bar and the rail or More
          // sheet already open it (U030, one entry less).
          _ToolTile(
            key: const ValueKey('tool-howto'),
            icon: Icons.help_outline,
            title: s.howToTitle,
            hint: s.howToTileHint,
            onTap: () {
              AppearanceScope.read(context)?.visit(DiscoveryStep.howTo);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HowToScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          _ToolTile(
            key: const ValueKey('tool-summary'),
            icon: Icons.assignment_outlined,
            title: s.summaryTitle,
            hint: s.summaryTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SummaryScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ToolTile(
            key: const ValueKey('tool-derived'),
            icon: Icons.calculate_outlined,
            title: s.derivedTitle,
            hint: s.derivedTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DerivedScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ToolGroup(s.toolsGroupLearn),
          _ToolTile(
            key: const ValueKey('tool-glossary'),
            icon: Icons.menu_book_outlined,
            title: s.glossaryTitle,
            hint: s.glossaryTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GlossaryScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _ToolTile(
            key: const ValueKey('tool-guide'),
            icon: Icons.accessibility_new_outlined,
            title: s.guideTitle,
            hint: s.guideTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BodyGuideScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _ToolGroup(s.toolsGroupFiles),
          _ToolTile(
            key: const ValueKey('tool-phyto'),
            icon: Icons.eco_outlined,
            title: s.phytoTitle,
            hint: s.phytoTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PhytoScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ToolTile(
            key: const ValueKey('tool-genetics'),
            icon: Icons.biotech_outlined,
            title: s.geneticsTitle,
            hint: s.geneticsTileHint,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GeneticsScreen(services: services),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (show(TodaySection.yourData)) ...[
          _yourData,
          const SizedBox(height: 28),
        ],
        if (look.discoveryEnabled) ...[
          const DiscoveryCard(),
          const SizedBox(height: 28),
        ],
        if (show(TodaySection.buildFacts)) ...[
          Wrap(
            key: const ValueKey('today-planned'),
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.dailyMissions,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              StatusChip(label: s.plannedLater, tone: StatusTone.muted),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: s.thisBuild,
            child: Column(
              children: [
                _KeyValue(s.profile, s.profileName(services.config.profile)),
                _KeyValue(s.version, services.config.version),
                _KeyValue(s.platform, services.registry.platform.name),
                _KeyValue(s.sourceRevision, services.config.shortRevision),
                _KeyValue(s.flutterVersion, services.config.flutterVersion),
                _KeyValue(s.dartVersion, services.config.dartVersion),
                _KeyValue(
                  s.recordSchema,
                  'v${HealthRecord.currentSchemaVersion}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: s.capabilities,
            child: Column(
              children: [
                for (final c in services.registry.capabilities)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.capText(c.label), style: text.titleMedium),
                              Text(s.capText(c.detail), style: text.bodyMedium),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // May wrap: at 320 dp with 2x text a fixed chip
                        // overflowed the row (found by the F007 layout test).
                        Flexible(
                          child: StatusChip(
                            label: switch (c.status) {
                              CapabilityStatus.available => s.available,
                              CapabilityStatus.notImplemented =>
                                s.notImplemented,
                              CapabilityStatus.notRequired => s.notRequired,
                              CapabilityStatus.off => s.savingOff,
                              CapabilityStatus.unsupportedOnPlatform =>
                                s.unsupported,
                            },
                            tone: switch (c.status) {
                              CapabilityStatus.available => StatusTone.ok,
                              CapabilityStatus.notImplemented =>
                                StatusTone.muted,
                              CapabilityStatus.notRequired => StatusTone.ok,
                              CapabilityStatus.off => StatusTone.info,
                              CapabilityStatus.unsupportedOnPlatform =>
                                StatusTone.info,
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
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

class _DateLineState extends State<_DateLine> with WidgetsBindingObserver {
  Timer? _midnight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {});
    _schedule();
  }

  @override
  void didUpdateWidget(_DateLine old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  /// Fires a second after the next local midnight (DateTime works out a
  /// daylight-saving day of 23 or 25 hours).
  void _schedule() {
    _midnight?.cancel();
    final now = widget.clock.nowUtc().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      // Keep child semantics separate so headings are not merged with body text.
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Both sides may wrap: a long value (e.g. DEVELOPMENT at 2x text on a
      // 320 dp phone) overflowed a fixed-width value cell.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: text.bodyMedium)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
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

/// A way into a tool that is not a daily number (G001).
class _ToolTile extends StatelessWidget {
  const _ToolTile({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          // A button for assistive technology and the browser, named by its
          // title and hint (an InkWell alone is only a tap target).
          child: Semantics(
            container: true,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleMedium),
                          Text(
                            hint,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
