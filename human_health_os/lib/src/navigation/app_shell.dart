/// Responsive shell (v0.32 F001): primary navigation is exactly Today,
/// Timeline and Labs — a navigation rail at ≥ 840 dp (extended labels at
/// ≥ 1200 dp) and a compact bottom bar below that. The other areas, each a
/// working screen (U034), are a secondary group: a labelled section under
/// the rail, and the "More" sheet on the bar (conflict C-8).
library;

import 'package:flutter/material.dart';

import '../app/appearance_scope.dart';
import '../domain/settings/appearance.dart';
import '../features/settings/settings_screen.dart';

import '../app/app_services.dart';
import '../features/labs/labs_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/conditions/conditions_screen.dart';
import '../features/preventive/preventive_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/medications/medications_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/today/today_screen.dart';
import '../l10n/strings.dart';
import '../presentation/theme/spacing.dart';
import '../presentation/widgets/build_profile_banner.dart';
import 'destination_switch.dart';
import 'destinations.dart';
import '../presentation/widgets/whole_words.dart';

const double kRailBreakpoint = 840;
const double kExtendedRailBreakpoint = 1200;

/// Rail widths shared by the primary destinations and the planned group.
const double kRailMinWidth = 80;
const double kRailMinExtendedWidth = 256;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.services});

  final AppServices services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late DestinationId _current = switch ((AppearanceScope.read(context)
          ?.value
          .startScreen) ??
      StartScreen.today) {
    StartScreen.today => DestinationId.today,
    StartScreen.timeline => DestinationId.timeline,
    StartScreen.labs => DestinationId.labs,
  };

  void _go(DestinationId id) => setState(() => _current = id);

  Widget _screenFor(DestinationId id) {
    return switch (id) {
      DestinationId.today => TodayScreen(services: widget.services),
      DestinationId.timeline => TimelineScreen(services: widget.services),
      DestinationId.labs => LabsScreen(services: widget.services),
      DestinationId.medications => MedicationsScreen(services: widget.services),
      DestinationId.nutrition => NutritionScreen(services: widget.services),
      DestinationId.activity => ActivityScreen(services: widget.services),
      DestinationId.conditions => ConditionsScreen(services: widget.services),
      DestinationId.preventive => PreventiveScreen(services: widget.services),
      DestinationId.documents => DocumentsScreen(services: widget.services),
      DestinationId.learn => const LearnScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final body = DestinationSwitch(
      go: _go,
      child: KeyedSubtree(key: ValueKey(_current), child: _screenFor(_current)),
    );
    final wide = width >= kRailBreakpoint;
    // Read above the Scaffold, which removes the inset from its body.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.appTitle),
        centerTitle: false,
        actions: [
          // Always one click away, whatever language the device uses.
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: s.settingsTitle,
            icon: const Icon(Icons.tune),
            onPressed: () => openSettings(context, widget.services),
          ),
        ],
      ),
      // The profile banner sits above the content on one line; its whole
      // sentence is its spoken label, and a tap shows it (audit UX-1, U035).
      // When it is expanded with the on-screen keyboard open, the body can be
      // shorter than the banner needs (320x640, 2x text, Turkish: Q002): the
      // banner then takes at most 40% of it and scrolls, its full text still
      // read out by its label, instead of the column overflowing.
      body: LayoutBuilder(
        builder: (context, box) {
          final banner = BuildProfileBanner(config: widget.services.config);
          return Column(
            children: [
              if (keyboard && box.maxHeight.isFinite)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * 0.4),
                  child: SingleChildScrollView(primary: false, child: banner),
                )
              else
                banner,
              Expanded(child: _content(wide, width, body)),
            ],
          );
        },
      ),
      bottomNavigationBar: wide
          ? null
          : _CompactBar(
              current: _current,
              onSelect: _go,
              services: widget.services,
            ),
    );
  }

  Widget _content(bool wide, double width, Widget body) {
    return SafeArea(
      top: false,
      child: wide
          ? Row(
              children: [
                _ScrollableRail(
                  extended: width >= kExtendedRailBreakpoint,
                  current: _current,
                  onSelect: _go,
                  services: widget.services,
                ),
                const VerticalDivider(width: 1),
                // One centred reading column (U036), not text from edge
                // to edge.
                Expanded(child: ReadingWidth(child: body)),
              ],
            )
          : ReadingWidth(child: body),
    );
  }
}

class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({
    required this.extended,
    required this.current,
    required this.onSelect,
    required this.services,
  });

  final bool extended;
  final DestinationId current;
  final ValueChanged<DestinationId> onSelect;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    final primary = kPrimaryDestinations.map(destinationById).toList();
    final selected = kPrimaryDestinations.indexOf(current);
    // Selected and unselected labels share one style (U045): the theme's
    // labelMedium as Material localizes it, so the chosen font, its size
    // and its spacing, with the rail theme's colour and weight on top. The
    // rail theme's own selected style carries only those two, and Material
    // used it in place of labelMedium, so the selected label alone lost
    // the font and was drawn at 14 instead of 12.
    final theme = Theme.of(context);
    final label = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final railTheme = theme.navigationRailTheme;
    // `scrollable` lets the framework scroll destinations + the planned group
    // on short windows (an IntrinsicHeight wrapper under-measured the
    // trailing group and overflowed at 1024×700).
    final rail = NavigationRail(
      key: const ValueKey('nav-rail'),
      scrollable: true,
      minWidth: kRailMinWidth,
      minExtendedWidth: kRailMinExtendedWidth,
      extended: extended,
      unselectedLabelTextStyle: label.merge(railTheme.unselectedLabelTextStyle),
      selectedLabelTextStyle: label.merge(railTheme.selectedLabelTextStyle),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      // A planned area is open: no primary item is selected.
      selectedIndex: selected >= 0 ? selected : null,
      onDestinationSelected: (i) => onSelect(primary[i].id),
      destinations: [
        for (final d in primary)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            // Compact: the label wraps between words in the rail's width
            // instead of widening the rail (U044, railLabelScaler).
            label: extended
                ? Text(d.label(lang))
                : SizedBox(
                    width: kRailLabelWidth,
                    child: WholeWordText(
                      d.label(lang),
                      textAlign: TextAlign.center,
                      maxLines: kRailLabelMaxLines,
                    ),
                  ),
          ),
      ],
      trailing: _PlannedRailGroup(
        extended: extended,
        current: current,
        onSelect: onSelect,
        services: services,
      ),
    );
    if (extended) return rail;
    // The compact rail's labels (U044): at most Material's 1.3× for
    // navigation labels, so the rail cannot grow without bound at large
    // text; see kRailLabelMaxLines.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: kNavLabelMaxScale),
      ),
      child: rail,
    );
  }
}

/// The most lines a label of the compact (80 dp) rail takes (U044).
///
/// Every label of the compact rail (the three areas, the planned group,
/// its heading and Settings) is drawn at the person's text size capped at
/// [kNavLabelMaxScale], as the bottom bar's labels are. It wraps between
/// words; it is drawn smaller only as much as needed for its longest word
/// to fit on one line of the rail and for the whole label to fit in this
/// many lines ([WholeWordText]). It is never cut or broken inside a word,
/// the rail stays [kRailMinWidth] wide, and the screen-reader names are
/// unchanged.
const int kRailLabelMaxLines = 3;

/// The width a primary label of the compact rail has: the rail less the
/// 8 dp a side Material keeps around a destination's label.
const double kRailLabelWidth = kRailMinWidth - 16;

/// Secondary, clearly labelled group of planned areas under the rail.
class _PlannedRailGroup extends StatelessWidget {
  const _PlannedRailGroup({
    required this.extended,
    required this.current,
    required this.onSelect,
    required this.services,
  });

  final bool extended;
  final DestinationId current;
  final ValueChanged<DestinationId> onSelect;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final width = extended ? kRailMinExtendedWidth : kRailMinWidth;
    return SizedBox(
      key: const ValueKey('rail-planned-group'),
      width: width,
      child: Column(
        crossAxisAlignment: extended
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          const Divider(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: extended ? 30 : 4),
            child: Semantics(
              header: true,
              child: extended
                  ? Text(
                      s.plannedGroup,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : WholeWordText(
                      s.plannedGroup,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: kRailLabelMaxLines,
                    ),
            ),
          ),
          const SizedBox(height: 4),
          for (final d in plannedDestinations)
            _PlannedRailItem(
              destination: d,
              extended: extended,
              selected: d.id == current,
              onTap: () => onSelect(d.id),
            ),
          const Divider(height: 24),
          // Settings: always the last item of the rail, with its label.
          _RailSettingsItem(extended: extended, services: services),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Opens Settings (from the top bar, the end of the rail or the end of the
/// "More" sheet: the same place on every screen).
void openSettings(BuildContext context, AppServices? services) =>
    openSettingsOn(
      Navigator.of(context),
      AppearanceScope.read(context),
      services,
    );

/// The one way Settings opens (top bar, rail, More sheet), so the routes
/// cannot drift apart.
void openSettingsOn(
  NavigatorState nav,
  AppearanceController? scope,
  AppServices? services,
) {
  scope?.visit(DiscoveryStep.settings);
  nav.push(
    MaterialPageRoute<void>(builder: (_) => SettingsScreen(services: services)),
  );
}

class _RailSettingsItem extends StatelessWidget {
  const _RailSettingsItem({required this.extended, required this.services});

  final bool extended;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final label = S.of(context).settingsTitle;
    final icon = Icon(Icons.tune, size: 20, color: color);
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('rail-settings'),
        onTap: () => openSettings(context, services),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          // At least 48 wide too: a short label ("Learn") in the compact
          // rail made a 38 dp wide target (Q001 screen matrix).
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: extended
                ? const EdgeInsets.fromLTRB(30, 10, 16, 10)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: extended
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      icon,
                      const SizedBox(height: 2),
                      // Wraps between words and is never cut (U043).
                      WholeWordText(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: kRailLabelMaxLines,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlannedRailItem extends StatelessWidget {
  const _PlannedRailItem({
    required this.destination,
    required this.extended,
    required this.selected,
    required this.onTap,
  });

  final Destination destination;
  final bool extended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final label = destination.label(langOf(context));
    final icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 20,
      color: color,
    );
    final style = theme.textTheme.labelMedium?.copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('rail-planned-${destination.id.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // At least 48 dp tall: the touch-target guideline (audit UX-4).
        child: ConstrainedBox(
          // And at least 48 wide: a short label ("Learn") in the compact
          // rail made a 38 dp wide target (Q001 screen matrix).
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            // Left inset 30 centres the 20 dp icon on the primary icons' axis.
            padding: extended
                ? const EdgeInsets.fromLTRB(30, 10, 16, 10)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: extended
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: Text(label, style: style)),
                    ],
                  )
                : Column(
                    children: [
                      icon,
                      const SizedBox(height: 2),
                      // Wraps between words and is never cut (U043).
                      WholeWordText(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: kRailLabelMaxLines,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CompactBar extends StatelessWidget {
  const _CompactBar({
    required this.current,
    required this.onSelect,
    required this.services,
  });

  final AppServices services;

  final DestinationId current;
  final ValueChanged<DestinationId> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final primary = kPrimaryDestinations.map(destinationById).toList();
    final inPrimary = kPrimaryDestinations.indexOf(current);
    final labels = [for (final d in primary) d.label(s.lang), s.more];
    final bar = NavigationBar(
      key: const ValueKey('nav-bar'),
      selectedIndex: inPrimary >= 0 ? inPrimary : primary.length,
      onDestinationSelected: (i) async {
        if (i < primary.length) {
          onSelect(primary[i].id);
          return;
        }
        final picked = await showModalBottomSheet<DestinationId>(
          context: context,
          showDragHandle: true,
          // Sized by its entries, not capped at 9/16 of the screen, so a
          // short list never scrolls inside the sheet (AIONIA v1.7 §22); it
          // scrolls only when the window is too short for every entry.
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => SafeArea(
            child: ListView(
              key: const ValueKey('more-sheet'),
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Semantics(
                    header: true,
                    child: Text(
                      s.plannedGroup,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                for (final d in plannedDestinations)
                  ListTile(
                    // The open area is marked by icon shape and a check, not
                    // by colour alone (audit UX-5).
                    leading: Icon(d.id == current ? d.selectedIcon : d.icon),
                    trailing: d.id == current ? const Icon(Icons.check) : null,
                    title: Text(d.label(s.lang)),
                    selected: d.id == current,
                    onTap: () => Navigator.of(context).pop(d.id),
                  ),
                const Divider(height: 16),
                // Settings: always the last entry, with a visible label.
                ListTile(
                  key: const ValueKey('more-settings'),
                  leading: const Icon(Icons.tune),
                  title: Text(s.settingsTitle),
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    openSettingsOn(
                      nav,
                      AppearanceScope.read(context),
                      services,
                    );
                  },
                ),
              ],
            ),
          ),
        );
        if (picked != null) onSelect(picked);
      },
      destinations: [
        for (final d in primary)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label(s.lang),
          ),
        NavigationDestination(
          icon: const Icon(Icons.more_horiz),
          label: s.more,
        ),
      ],
    );
    // A label may wrap between its words ("Zaman / çizelgesi") but never
    // inside one ("Medicati / ons" at 2× text on 320 dp, Q001). Each item
    // gets an equal share of the width; when the longest word of any label
    // does not fit in its share at the person's text size, the labels are
    // scaled down just enough for it to fit. Every label stays whole and
    // visible (no ellipsis, no hidden unselected labels), and the screen
    // reader name is unchanged (R016). Labels are not shrunk further only
    // to keep a two-word label on one line: on a 390 dp phone "Zaman
    // çizelgesi" would need every label drawn below the person's text size
    // although each word fits, so it wraps between its words (U035).
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final width =
            constraints.maxWidth - media.padding.left - media.padding.right;
        final scaler = navLabelScaler(
          context,
          labels: labels,
          share: width / labels.length,
        );
        if (scaler == null) return bar;
        return MediaQuery(
          data: media.copyWith(textScaler: scaler),
          child: bar,
        );
      },
    );
  }
}

/// The bottom bar's label size cap (Material's own, 1.3×).
const double kNavLabelMaxScale = 1.3;

/// The text scaler that lets the longest word of every label fit on one line
/// in [share] logical pixels, or null when the current text size already
/// does. Measured with the bar's selected (bold, widest) label style.
TextScaler? navLabelScaler(
  BuildContext context, {
  required List<String> labels,
  required double share,
}) {
  final theme = Theme.of(context);
  final style = (theme.textTheme.bodyMedium ?? const TextStyle()).merge(
    theme.navigationBarTheme.labelTextStyle?.resolve({WidgetState.selected}) ??
        theme.textTheme.labelMedium,
  );
  final current = MediaQuery.textScalerOf(context)
      .clamp(maxScaleFactor: kNavLabelMaxScale);
  final direction = Directionality.of(context);
  // A hair of room so rounding never pushes a word onto a second line.
  final room = share - 2;
  double widest(TextScaler scaler) {
    var max = 0.0;
    for (final label in labels) {
      for (final word in label.split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > max) max = painter.width;
        painter.dispose();
      }
    }
    return max;
  }

  if (room <= 0 || widest(current) <= room) return null;
  final size = style.fontSize ?? 14;
  var factor = current.scale(size) / size;
  // Text width is close to linear in the scale; a few steps settle rounding.
  for (var i = 0; i < 8; i++) {
    final w = widest(TextScaler.linear(factor));
    if (w <= room) break;
    factor *= room / w * 0.99;
  }
  return TextScaler.linear(factor);
}
