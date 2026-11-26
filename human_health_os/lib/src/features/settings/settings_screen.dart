import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/human_os_app.dart' show fontFamilyFor;
import '../../app/app_lock.dart';
import '../../app/app_services.dart';
import '../../app/appearance_scope.dart';
import '../../config/app_config.dart';
import '../../domain/settings/appearance.dart';
import '../../domain/records/health_record.dart';
import '../../l10n/strings.dart';
import '../today/measurements_card.dart';
import '../../presentation/theme/human_os_theme.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/record_row.dart';
import '../../presentation/widgets/whole_label_field.dart';
import '../onboarding/first_run_screen.dart';
import 'about_screen.dart';
import '../../presentation/widgets/whole_chip.dart';
import '../../presentation/widgets/whole_words.dart';

/// Language, light or dark, accent colour and text size (U005). Every choice
/// applies at once and is one click; nothing here touches health data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.config, this.services});

  /// The running build's configuration (version shown under Updates and
  /// about); the services' configuration, or the compile-time values, when
  /// not given.
  final AppConfig? config;

  /// The running app's services: they open About Human OS (U032), which
  /// shows this build's facts and what works on this device. Without them
  /// (a Settings screen built on its own) the About row is not shown.
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final controller = AppearanceScope.maybeOf(context);
    final a = controller?.value ?? const AppearanceSettings();
    final quiet = text.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    void set(AppearanceSettings next) => controller?.update(next);

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: Space.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Its own node (container): without it Flutter merges the header
          // flag and the title into the section's node, so the web shows a
          // <header> landmark labelled with the title and the section's
          // text, and no heading to navigate by (Q002).
          Semantics(
            header: true,
            container: true,
            child: Text(title, style: text.titleMedium),
          ),
          const SizedBox(height: Space.m),
          child,
        ],
      ),
    );

    Widget choices<T>(
      String keyPrefix,
      List<(T, String)> options,
      T current,
      void Function(T) onPick,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          WholeChip.choice(
            key: ValueKey('$keyPrefix-${(value as Enum).name}'),
            label: label,
            selected: value == current,
            onSelected: (_) => onPick(value),
          ),
      ],
    );

    return Scaffold(
      // Drawn smaller rather than ellipsized when the top bar is too narrow
      // for the word at the person's text size (U035).
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(s.settingsTitle),
        ),
      ),
      // One centred reading column on a wide window (U036).
      body: ReadingWidth.builder(
        // Built whole, not lazily: a short, fixed page, so Tab reaches
        // every control even where the next one is far below the window.
        builder: (context) => SingleChildScrollView(
          key: const ValueKey('screen-settings'),
          padding: readingPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.settingsDeviceScope, style: quiet),
              const SizedBox(height: Space.xs),
              Text(
                controller?.saveFailed == true
                    ? s.settingsSaveFailed
                    : (controller?.store.persistent ?? false)
                    ? s.settingsSaved
                    : s.settingsSessionOnly,
                key: const ValueKey('settings-persistence'),
                style: quiet,
              ),
              // One heading level (U035): each section's title is the only
              // heading in it; the controls' own names are plain labels.
              const SizedBox(height: 24),
              // The most used first (U038): light or dark, palette, colour,
              // text size and language; the interface scale and fonts next;
              // units, dates and the rest after; lock, updates and About
              // last.
              section(
                s.settingsTheme,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // With a palette chosen, the palette sets light or
                    // dark; the ticked chip is the choice kept for
                    // Standard. Said before the chips, so neither the eye
                    // nor a screen reader takes the tick for the page's
                    // look (U046).
                    if (a.palette != PaletteChoice.standard) ...[
                      Text(
                        s.themeUnderPalette(s.paletteName(a.palette)),
                        key: const ValueKey('theme-palette-note'),
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: Space.s),
                    ],
                    choices(
                      'set-theme',
                      [
                        (ThemeChoice.light, s.settingsLight),
                        (ThemeChoice.dark, s.settingsDark),
                        (ThemeChoice.system, s.settingsSystem),
                      ],
                      a.theme,
                      (v) => set(a.copyWith(theme: v)),
                    ),
                  ],
                ),
              ),
              section(
                s.settingsPalette,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        // Measured once per layout, shared by every card.
                        final cardWidth = _PaletteSwatch.widthFor(
                          context,
                          [
                            for (final q in PaletteChoice.values)
                              s.paletteName(q),
                          ],
                          box.maxWidth,
                          gap: 12,
                        );
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final p in PaletteChoice.values)
                              _PaletteSwatch(
                                width: cardWidth,
                                choice: p,
                                label: s.paletteName(p),
                                sample: s.paletteSample,
                                tokens:
                                    tokensFor(
                                      p,
                                      highContrast: a.highContrast,
                                    ) ??
                                    standardTokens(
                                      _standardBrightness(context, a.theme),
                                      a.accent,
                                      highContrast: a.highContrast,
                                    ),
                                selected: a.palette == p,
                                onTap: () => set(a.copyWith(palette: p)),
                              ),
                          ],
                        );
                      },
                    ),
                    if (a.palette != PaletteChoice.standard) ...[
                      const SizedBox(height: 8),
                      Text(
                        s.paletteNote(s.paletteName(a.palette)),
                        key: const ValueKey('palette-note'),
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              section(
                s.settingsAccent,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in AccentChoice.values)
                      _AccentSwatch(
                        choice: c,
                        label: s.accentName(c),
                        selected: a.accent == c,
                        onTap: () => set(a.copyWith(accent: c)),
                      ),
                  ],
                ),
              ),
              section(
                s.settingsTextSize,
                choices(
                  'set-text',
                  [
                    (TextSizeChoice.system, s.settingsSystem),
                    (TextSizeChoice.larger, s.settingsLarger),
                    (TextSizeChoice.largest, s.settingsLargest),
                  ],
                  a.textSize,
                  (v) => set(a.copyWith(textSize: v)),
                ),
              ),
              section(
                s.settingsLanguage,
                choices(
                  'set-language',
                  [
                    (LanguageChoice.tr, 'Türkçe'),
                    (LanguageChoice.en, 'English'),
                    (LanguageChoice.system, s.settingsSystem),
                  ],
                  a.language,
                  (v) => set(a.copyWith(language: v)),
                ),
              ),
              section(
                s.settingsInterfaceScale,
                _ScaleControl(
                  percent: a.interfacePercent,
                  onChange: (v) => set(a.copyWith(interfacePercent: v)),
                ),
              ),
              section(
                s.settingsFont,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    choices(
                      'set-font',
                      [
                        (FontChoice.system, s.settingsSystem),
                        (FontChoice.legible, s.fontLegible),
                        (FontChoice.dyslexic, s.fontDyslexic),
                        (FontChoice.lexend, s.fontLexend),
                      ],
                      a.font,
                      (v) => set(a.copyWith(font: v)),
                    ),
                    const SizedBox(height: Space.s),
                    // The four samples open on demand (U038), so the
                    // section stays short.
                    DetailsDisclosure(
                      id: 'font-previews',
                      about: s.settingsFont,
                      showText: s.fontPreviewShow,
                      hideText: s.fontPreviewHide,
                      children: [
                        Text(s.fontPreviewNote, style: text.bodySmall),
                        const SizedBox(height: Space.xs),
                        for (final (f, label) in [
                          (FontChoice.system, s.settingsSystem),
                          (FontChoice.legible, s.fontLegible),
                          (FontChoice.dyslexic, s.fontDyslexic),
                          (FontChoice.lexend, s.fontLexend),
                        ])
                          _FontPreview(choice: f, label: label),
                      ],
                    ),
                    SwitchListTile(
                      key: const ValueKey('set-wide-spacing'),
                      contentPadding: EdgeInsets.zero,
                      title: WholeWordText(s.settingsWideSpacing),
                      value: a.wideSpacing,
                      onChanged: (on) => set(a.copyWith(wideSpacing: on)),
                    ),
                    SwitchListTile(
                      key: const ValueKey('set-reduce-motion'),
                      contentPadding: EdgeInsets.zero,
                      title: WholeWordText(s.settingsReduceMotion),
                      value: a.reduceMotion,
                      onChanged: (on) => set(a.copyWith(reduceMotion: on)),
                    ),
                    SwitchListTile(
                      key: const ValueKey('set-show-aion'),
                      contentPadding: EdgeInsets.zero,
                      title: WholeWordText(s.settingsShowAion),
                      value: a.showAion,
                      onChanged: (on) => set(a.copyWith(showAion: on)),
                    ),
                  ],
                ),
              ),
              section(
                s.settingsUnits,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    choices(
                      'set-units',
                      [
                        (UnitSystem.metric, s.unitsMetric),
                        (UnitSystem.us, s.unitsUs),
                      ],
                      a.units,
                      (v) => set(a.copyWith(units: v)),
                    ),
                    const SizedBox(height: 4),
                    Text(s.unitsNote, style: text.bodySmall),
                  ],
                ),
              ),
              section(
                s.settingsDates,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    choices(
                      'set-date',
                      [
                        (DateOrder.iso, '2026-11-08'),
                        (DateOrder.dayMonth, '08.11.2026'),
                        (DateOrder.monthDay, '11/08/2026'),
                      ],
                      a.dateOrder,
                      (v) => set(a.copyWith(dateOrder: v)),
                    ),
                    const SizedBox(height: 8),
                    choices(
                      'set-clock',
                      [
                        (ClockStyle.h24, '20:05'),
                        (ClockStyle.h12, s.clock12Sample),
                      ],
                      a.clock,
                      (v) => set(a.copyWith(clock: v)),
                    ),
                    const SizedBox(height: 4),
                    Text(s.datesNote, style: text.bodySmall),
                  ],
                ),
              ),
              section(
                s.settingsSpacing,
                choices(
                  'set-density',
                  [
                    (Density.comfortable, s.settingsComfortable),
                    (Density.compact, s.settingsCompact),
                  ],
                  a.density,
                  (v) => set(a.copyWith(density: v)),
                ),
              ),
              section(
                s.settingsContrast,
                SwitchListTile(
                  key: const ValueKey('set-high-contrast'),
                  contentPadding: EdgeInsets.zero,
                  title: WholeWordText(s.settingsHighContrast),
                  value: a.highContrast,
                  onChanged: (on) => set(a.copyWith(highContrast: on)),
                ),
              ),
              section(
                s.settingsStart,
                choices(
                  'set-start',
                  [
                    (StartScreen.today, s.startScreenName(StartScreen.today)),
                    (
                      StartScreen.timeline,
                      s.startScreenName(StartScreen.timeline),
                    ),
                    (StartScreen.labs, s.startScreenName(StartScreen.labs)),
                  ],
                  a.startScreen,
                  (v) => set(a.copyWith(startScreen: v)),
                ),
              ),
              section(
                s.settingsToday,
                _TodayLayout(settings: a, onChange: set),
              ),
              section(
                s.discoveryTitle,
                SwitchListTile(
                  key: const ValueKey('set-discovery'),
                  contentPadding: EdgeInsets.zero,
                  title: WholeWordText(s.discoveryEnabled),
                  subtitle: WholeWordText(s.discoveryNote),
                  value: a.discoveryEnabled,
                  onChanged: (v) => set(a.copyWith(discoveryEnabled: v)),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const ValueKey('set-first-run'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (ctx) =>
                          FirstRunScreen(onDone: () => Navigator.of(ctx).pop()),
                    ),
                  ),
                  child: Text(s.firstShowAgain),
                ),
              ),
              const SizedBox(height: 24),
              section(
                s.lockTitle,
                _AppLockSettings(
                  settings: a,
                  availability: AppLockScope.of(context),
                  onChange: set,
                ),
              ),
              section(
                s.settingsUpdatesTitle,
                _UpdatesAndAbout(config: config ?? services?.config),
              ),
              if (services case final services?)
                // Near the end: the facts about this build, for support and the
                // curious, not for every day (U032).
                ListTile(
                  key: const ValueKey('settings-about'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.aboutTitle),
                  subtitle: Text(s.aboutHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AboutScreen(services: services),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lock after inactivity and lock when hidden (G-36, D-046). Off unless the
/// person turns them on; disabled, with the reason, where there is no
/// encrypted vault key to drop.
class _AppLockSettings extends StatelessWidget {
  const _AppLockSettings({
    required this.settings,
    required this.availability,
    required this.onChange,
  });

  final AppearanceSettings settings;
  final AppLockAvailability availability;
  final void Function(AppearanceSettings) onChange;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final on = availability == AppLockAvailability.available;
    final reason = switch (availability) {
      AppLockAvailability.available => null,
      AppLockAvailability.unencrypted => s.lockUnencrypted,
      AppLockAvailability.nothingSaved => s.lockNothingSaved,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reason != null) ...[
          Text(
            reason,
            key: const ValueKey('set-lock-reason'),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in AppearanceSettings.lockMinuteChoices)
              WholeChip.choice(
                key: ValueKey('set-lock-$m'),
                label: m == 0 ? s.lockOff : s.lockMinutes(m),
                tooltip: m == 0 ? null : s.lockMinutesSpoken(m),
                selected: on && settings.lockAfterMinutes == m,
                onSelected: on
                    ? (_) => onChange(settings.copyWith(lockAfterMinutes: m))
                    : null,
              ),
          ],
        ),
        SwitchListTile(
          key: const ValueKey('set-lock-hidden'),
          contentPadding: EdgeInsets.zero,
          title: WholeWordText(s.lockHidden),
          subtitle: WholeWordText(s.lockHiddenNote),
          value: on && settings.lockWhenHidden,
          onChanged: on
              ? (v) => onChange(settings.copyWith(lockWhenHidden: v))
              : null,
        ),
        if (on) Text(s.lockExplain, style: text.bodySmall),
      ],
    );
  }
}

/// The installed version and where newer ones are. The app makes no network
/// calls, so it says plainly that it cannot look for updates itself (k44
/// §10 asks for a check button; that needs an owner decision on network
/// use, G-71).
class _UpdatesAndAbout extends StatelessWidget {
  const _UpdatesAndAbout({this.config});

  final AppConfig? config;

  static const releasesPage = 'github.com/kaansavukduran/human-os/releases';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final config = this.config ?? AppConfig.fromEnvironment();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.settingsInstalledVersion(
            s.buildFact(config.version),
            s.buildFact(config.shortRevision),
          ),
          key: const ValueKey('settings-version'),
          style: text.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(s.settingsUpdatesHow, key: const ValueKey('settings-updates-how')),
        const SizedBox(height: 4),
        const SelectableText(
          releasesPage,
          key: ValueKey('settings-releases-page'),
        ),
        const SizedBox(height: 8),
        Text(s.settingsUpdatesKeepData, style: text.bodySmall),
      ],
    );
  }
}

class _ScaleControl extends StatefulWidget {
  const _ScaleControl({required this.percent, required this.onChange});

  final int percent;
  final ValueChanged<int> onChange;

  @override
  State<_ScaleControl> createState() => _ScaleControlState();
}

class _ScaleControlState extends State<_ScaleControl> {
  late final _input = TextEditingController(text: '${widget.percent}');
  final _sliderFocus = FocusNode();
  bool _invalid = false;

  @override
  void didUpdateWidget(_ScaleControl old) {
    super.didUpdateWidget(old);
    if (old.percent != widget.percent) {
      _input.text = '${widget.percent}';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _sliderFocus.dispose();
    super.dispose();
  }

  void _apply() {
    final n = AppearanceSettings.parseInterfacePercent(_input.text);
    setState(() => _invalid = n == null);
    if (n != null) widget.onChange(n);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.interfacePercent(widget.percent),
          key: const ValueKey('interface-scale-value'),
          // A value, not a heading under the section's title (U035).
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          s.interfaceScaleNote,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Slider(
          key: const ValueKey('set-interface-slider'),
          focusNode: _sliderFocus,
          min: 80,
          max: 200,
          divisions: 24,
          // The exact input may fall between the slider's five-point stops.
          value: widget.percent.toDouble(),
          label: s.interfacePercent(widget.percent),
          semanticFormatterCallback: (v) => s.interfacePercent(v.round()),
          onChanged: (v) => widget.onChange(v.round()),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in [80, 100, 125, 150, 175, 200])
              WholeChip.choice(
                key: ValueKey('set-interface-$n'),
                label: s.interfacePercent(n),
                selected: widget.percent == n,
                onSelected: (_) => widget.onChange(n),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Its own node (container): otherwise the field becomes the node the
        // section's plain texts merge into, so it is announced as "100%, the
        // note, Exact scale" and its box covers the presets above it (C001).
        // Its label is drawn above the field when it would not fit in it
        // (320 dp, 2× text: U035).
        Semantics(
          container: true,
          child: WholeLabelField(
            label: s.interfaceExact,
            reserve: 24,
            field: (labelText) => TextField(
              key: const ValueKey('set-interface-input'),
              controller: _input,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: labelText,
                suffixText: '%',
                errorText: _invalid ? s.interfaceInvalid : null,
              ),
              onSubmitted: (_) => _apply(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const ValueKey('set-interface-apply'),
              onPressed: _apply,
              child: Text(s.interfaceApply),
            ),
            OutlinedButton(
              key: const ValueKey('set-interface-reset'),
              onPressed: () {
                setState(() {
                  _input.text = '100';
                  _invalid = false;
                });
                widget.onChange(100);
              },
              child: Text(s.interfaceReset),
            ),
          ],
        ),
      ],
    );
  }
}

/// The brightness Standard would use with the saved theme choice.
Brightness _standardBrightness(BuildContext context, ThemeChoice theme) =>
    switch (theme) {
      ThemeChoice.light => Brightness.light,
      ThemeChoice.dark => Brightness.dark,
      ThemeChoice.system => MediaQuery.platformBrightnessOf(context),
    };

/// A palette as a small live preview in its own tokens: a title, a sample
/// number in ink (values are never coloured), a field edge and an accent
/// pill (the accent marks actions only).
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.width,
    required this.choice,
    required this.label,
    required this.sample,
    required this.tokens,
    required this.selected,
    required this.onTap,
  });

  /// The card's width: the same for every card ([widthFor]).
  final double width;
  final PaletteChoice choice;
  final String label;
  final String sample;

  /// The name's style on a card.
  static TextStyle? nameStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontWeight: FontWeight.w700);

  /// The width of every card (U043): 132 dp, or wider when the longest
  /// word of a palette name would not fit beside the tick at the person's
  /// text size. When two such cards no longer fit side by side, each takes
  /// the whole line, so the cards stack and the names stay whole and at
  /// the chosen size wherever the line allows.
  static double widthFor(
    BuildContext context,
    List<String> names,
    double maxWidth, {
    required double gap,
  }) {
    final style = nameStyle(context);
    var word = 0.0;
    for (final name in names) {
      for (final w in name.split(RegExp(r'\s+'))) {
        if (w.isEmpty) continue;
        word = math.max(word, oneLineWidth(context, w, style));
      }
    }
    // Border 3 + padding 10 on each side, the tick 18 and its gap 6, and
    // a hair so rounding never pushes a letter onto its own line.
    final needed = word + 2 * 13 + 18 + 6 + 2;
    if (!maxWidth.isFinite) return math.max(132, needed);
    if (needed <= 132) return math.min(132, maxWidth);
    if (2 * needed + gap <= maxWidth) return needed;
    return maxWidth;
  }

  final PaletteTokens tokens;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tokens;
    final base = theme.textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('set-palette-${choice.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: WholeWordText(
                      label,
                      style: nameStyle(context)?.copyWith(color: t.ink),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check, color: t.ink, size: 18),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.fieldEdge),
                ),
                child: Text(
                  sample,
                  style: base.titleMedium?.copyWith(color: t.ink),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                // 4 dp above and below (was 2): the ring around "Aa" lies
                // on the pill's own colour, not on its anti-aliased edge,
                // so its contrast is measured against the pill (U046).
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: t.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Aa',
                  style: base.labelSmall?.copyWith(color: t.onPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.choice,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AccentChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tones = accentTones[choice]!;
    final color = dark ? tones.$2 : tones.$1;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('set-accent-${choice.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? scheme.onSurface : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, color: scheme.onPrimary, size: 22)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which measurement tiles show and in what order, which sections show,
/// and whether the number pad starts open. Up and Down buttons keep the
/// order reachable with the mouse alone (no drag).
class _TodayLayout extends StatelessWidget {
  const _TodayLayout({required this.settings, required this.onChange});

  final AppearanceSettings settings;
  final void Function(AppearanceSettings) onChange;

  /// One kind in Today's order: its checkbox and name, and Up and Down.
  /// [stacked] puts Up and Down under the name, so the name has the row.
  Widget _orderRow(
    BuildContext context,
    int i,
    List<String> order,
    List<String> defaults,
    RecordKind Function(String) kindOf,
    bool stacked,
  ) {
    final s = S.of(context);
    final code = order[i];
    final name = s.recordKind(kindOf(code));
    // One node for the screen reader: "Blood pressure, checked".
    final shown = MergeSemantics(
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('set-tile-show-$code'),
            value: !settings.hiddenTiles.contains(code),
            onChanged: (on) {
              final hidden = {...settings.hiddenTiles};
              on == true ? hidden.remove(code) : hidden.add(code);
              onChange(settings.copyWith(hiddenTiles: hidden));
            },
          ),
          Expanded(child: WholeWordText(name)),
        ],
      ),
    );
    final buttons = [
      IconButton(
        key: ValueKey('set-tile-up-$code'),
        tooltip: s.settingsMoveUp(name),
        icon: const Icon(Icons.arrow_upward),
        onPressed: i == 0
            ? null
            : () => onChange(settings.move(defaults, code, -1)),
      ),
      IconButton(
        key: ValueKey('set-tile-down-$code'),
        tooltip: s.settingsMoveDown(name),
        icon: const Icon(Icons.arrow_downward),
        onPressed: i == order.length - 1
            ? null
            : () => onChange(settings.move(defaults, code, 1)),
      ),
    ];
    if (!stacked) {
      return Row(
        key: ValueKey('set-tile-$code'),
        children: [
          Expanded(child: shown),
          ...buttons,
        ],
      );
    }
    return Padding(
      key: ValueKey('set-tile-$code'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          shown,
          // Under the name, past the checkbox.
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48),
            child: Row(children: buttons),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final defaults = [for (final k in MeasurementsCard.kinds) k.code];
    final order = settings.ordered(defaults);
    RecordKind kindOf(String c) =>
        MeasurementsCard.kinds.firstWhere((k) => k.code == c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.settingsTiles, style: text.bodyMedium),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final style = DefaultTextStyle.of(context).style;
            var word = 0.0;
            for (final c in order) {
              for (final w in s.recordKind(kindOf(c)).split(RegExp(r'\s+'))) {
                if (w.isEmpty) continue;
                word = math.max(word, oneLineWidth(context, w, style));
              }
            }
            // The checkbox and the two buttons take 48 dp each. When the
            // longest word of a label would not fit in what they leave
            // (320 dp, 2× text), every label gets the row's width and
            // the buttons move under it, lined up from row to row (U043).
            final stacked = word + 2 > box.maxWidth - 3 * 48;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < order.length; i++)
                  _orderRow(context, i, order, defaults, kindOf, stacked),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(s.settingsSections, style: text.bodyMedium),
        for (final x in TodaySection.values)
          SwitchListTile(
            key: ValueKey('set-section-${x.name}'),
            contentPadding: EdgeInsets.zero,
            title: WholeWordText(s.todaySectionName(x)),
            value: !settings.hiddenSections.contains(x),
            onChanged: (on) {
              final hidden = {...settings.hiddenSections};
              on ? hidden.remove(x) : hidden.add(x);
              onChange(settings.copyWith(hiddenSections: hidden));
            },
          ),
        SwitchListTile(
          key: const ValueKey('set-pad-open'),
          contentPadding: EdgeInsets.zero,
          title: WholeWordText(s.settingsPadOpen),
          value: settings.padOpen,
          onChanged: (on) => onChange(settings.copyWith(padOpen: on)),
        ),
        SwitchListTile(
          key: const ValueKey('set-measurements-first'),
          contentPadding: EdgeInsets.zero,
          title: WholeWordText(s.settingsMeasurementsFirst),
          value: settings.measurementsFirst,
          onChanged: (on) => onChange(settings.copyWith(measurementsFirst: on)),
        ),
        SwitchListTile(
          key: const ValueKey('set-checkins-first'),
          contentPadding: EdgeInsets.zero,
          title: WholeWordText(s.settingsCheckInsFirst),
          value: settings.checkInsFirst,
          onChanged: (on) => onChange(settings.copyWith(checkInsFirst: on)),
        ),
        const SizedBox(height: 4),
        OutlinedButton(
          key: const ValueKey('set-reset-today'),
          onPressed: () => onChange(settings.resetToday()),
          child: Text(s.settingsResetToday),
        ),
      ],
    );
  }
}

/// One line of Turkish letters in one font, so the choice is seen before it
/// is made. The device font is named from the platform's own type scale, so
/// its line does not take on the font chosen now.
class _FontPreview extends StatelessWidget {
  const _FontPreview({required this.choice, required this.label});

  static const sample = 'Çok güzel şiir: ğ ı İ ö ş ü';

  final FontChoice choice;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final family =
        fontFamilyFor(choice) ??
        Typography.material2021(platform: theme.platform)
            .black
            .bodyLarge
            ?.fontFamily;
    return Padding(
      key: ValueKey('font-preview-${choice.name}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: label,
        child: Text(
          sample,
          style: theme.textTheme.bodyLarge?.copyWith(fontFamily: family),
        ),
      ),
    );
  }
}
