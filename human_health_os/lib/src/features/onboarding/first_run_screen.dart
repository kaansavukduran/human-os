import 'package:flutter/material.dart';

import '../../presentation/widgets/aion.dart';
import '../../app/appearance_scope.dart';
import '../../domain/settings/appearance.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme/spacing.dart';
import '../../presentation/widgets/whole_words.dart';

/// A calm first run (U014, shortened by U037): two short steps, each
/// skippable, then Today, where the first value is typed. Step 1 says what
/// Human OS does and that it stays on this device; step 2 sets language
/// and look. It asks for nothing else. In a build with an encrypted vault
/// the vault is created after it, unchanged (F006).
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final controller = AppearanceScope.maybeOf(context);
    final a = controller?.value ?? const AppearanceSettings();
    void set(AppearanceSettings next) => controller?.update(next);

    Widget chips<T extends Enum>(
      String prefix,
      List<(T, String)> options,
      T current,
      void Function(T) pick,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            key: ValueKey('first-$prefix-${v.name}'),
            label: Text(label),
            selected: v == current,
            onSelected: (_) => pick(v),
          ),
      ],
    );

    const steps = 2;
    final (title, body) = switch (_step) {
      0 => (s.firstWelcomeTitle, s.firstWelcomeBody),
      _ => (s.firstLookTitle, s.firstLookBody),
    };
    final last = _step == steps - 1;
    return Scaffold(
      body: SafeArea(
        // One centred reading column on a wide window (U041): the text and
        // the Start button no longer run from one edge of the window to the
        // other.
        child: ReadingWidth.builder(
          builder: (context) => ListView(
            key: const ValueKey('screen-first-run'),
            padding: readingPadding(context, const EdgeInsets.all(24)),
            children: [
              if (_step == 0) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: AionFigure(height: 140),
                ),
                const SizedBox(height: 8),
                const AionLine(),
                const SizedBox(height: 12),
              ],
              // Step and title are announced together when the step changes.
              Semantics(
                liveRegion: true,
                container: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.firstStep(_step + 1, steps),
                      key: const ValueKey('first-step'),
                      style: text.labelLarge?.copyWith(color: scheme.outline),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: WholeWordText(title, style: text.headlineSmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(body, style: text.bodyLarge),
              if (_step == 0) ...[
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(s.firstPrivateTitle, style: text.titleMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  s.firstPrivateBody,
                  key: const ValueKey('first-private'),
                  style: text.bodyLarge,
                ),
              ],
              if (last) ...[
                const SizedBox(height: 20),
                Text(s.settingsLanguage, style: text.titleSmall),
                const SizedBox(height: 8),
                chips(
                  'language',
                  [
                    (LanguageChoice.tr, 'Türkçe'),
                    (LanguageChoice.en, 'English'),
                    (LanguageChoice.system, s.settingsSystem),
                  ],
                  a.language,
                  (v) => set(a.copyWith(language: v)),
                ),
                const SizedBox(height: 16),
                Text(s.settingsTheme, style: text.titleSmall),
                const SizedBox(height: 8),
                chips(
                  'theme',
                  [
                    (ThemeChoice.light, s.settingsLight),
                    (ThemeChoice.dark, s.settingsDark),
                    (ThemeChoice.system, s.settingsSystem),
                  ],
                  a.theme,
                  (v) => set(a.copyWith(theme: v)),
                ),
                const SizedBox(height: 16),
                Text(s.settingsFont, style: text.titleSmall),
                const SizedBox(height: 8),
                chips(
                  'font',
                  [
                    (FontChoice.system, s.settingsSystem),
                    (FontChoice.legible, s.fontLegible),
                    (FontChoice.dyslexic, s.fontDyslexic),
                  ],
                  a.font,
                  (v) => set(a.copyWith(font: v)),
                ),
                const SizedBox(height: 8),
                Text(
                  s.firstMoreInSettings,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.firstThen,
                  key: const ValueKey('first-then'),
                  style: text.bodyLarge,
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                key: const ValueKey('first-next'),
                onPressed: last ? widget.onDone : () => setState(() => _step++),
                child: Text(last ? s.firstStart : s.firstNext),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      key: const ValueKey('first-back'),
                      onPressed: () => setState(() => _step--),
                      child: Text(s.firstBack),
                    ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      key: const ValueKey('first-skip'),
                      onPressed: widget.onDone,
                      child: Text(s.firstSkip),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
