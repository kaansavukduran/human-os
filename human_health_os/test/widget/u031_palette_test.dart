// U031-S1: named palettes from the owner's YKSmania app (Matrix, Axolotl,
// Trans). A palette colours surfaces, text and actions only; value text stays
// onSurface; the saved theme and accent are kept for Standard. Also: one
// notify per settings change and themes that are built once per input.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/presentation/theme/human_os_theme.dart';

import 'f007_measurements_test.dart' show settle, tapKey;
import 'u005_settings_test.dart' show launchWith;

double ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

const named = [
  PaletteChoice.matrix,
  PaletteChoice.axolotl,
  PaletteChoice.trans,
];

class _FailingStore extends MemoryAppearanceStore {
  @override
  Future<void> save(AppearanceSettings settings) async =>
      throw StateError('disk full');
}

ColorScheme schemeOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).colorScheme;

Brightness brightnessOf(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

void main() {
  group('saved palette', () {
    test('round-trips; missing or unknown falls back to Standard', () {
      for (final p in PaletteChoice.values) {
        final a = AppearanceSettings(palette: p, accent: AccentChoice.blue);
        expect(AppearanceSettings.fromJson(a.toJson()), a);
        expect(a.toJson()['palette'], p.name);
      }
      final old = const AppearanceSettings(accent: AccentChoice.green).toJson()
        ..remove('palette');
      final loaded = AppearanceSettings.fromJson(old);
      expect(loaded.palette, PaletteChoice.standard);
      expect(loaded.accent, AccentChoice.green, reason: 'old file still loads');
      expect(
        AppearanceSettings.fromJson({'palette': 'neon', 'theme': 'light'}),
        const AppearanceSettings(theme: ThemeChoice.light),
      );
    });

    test('is part of equality and kept by Reset Today', () {
      const a = AppearanceSettings(
        palette: PaletteChoice.axolotl,
        measurementsFirst: true,
      );
      expect(a == const AppearanceSettings(measurementsFirst: true), isFalse);
      expect(a.copyWith(padOpen: true).palette, PaletteChoice.axolotl);
      final reset = a.resetToday();
      expect(reset.palette, PaletteChoice.axolotl);
      expect(reset.measurementsFirst, isFalse);
    });
  });

  test('every palette meets WCAG AA in normal and high contrast', () {
    final mins = <String, double>{};
    for (final p in named) {
      for (final hc in [false, true]) {
        final theme = buildHumanOsTheme(
          Brightness.light,
          palette: p,
          highContrast: hc,
        );
        final s = theme.colorScheme;
        final card = theme.cardTheme.color!;
        final edge =
            (theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
                .borderSide
                .color;
        final tokens = tokensFor(p, highContrast: hc)!;
        expect(theme.brightness, tokens.brightness, reason: '$p');
        expect(s.surfaceContainer, card, reason: 'card = surfaceContainer');
        expect(s.surface, tokens.surface);
        expect(s.onSurface, tokens.ink);
        expect(s.outline, tokens.outline);
        expect(s.outlineVariant, tokens.hairline);
        expect(s.primary, tokens.primary);
        expect(s.error, tokens.error);
        expect(
          theme.extension<HealthRoleColors>(),
          tokens.dark ? HealthRoleColors.dark : HealthRoleColors.light,
          reason: 'role colours unchanged',
        );
        final text = {
          'onSurface/surface': ratio(s.onSurface, s.surface),
          'onSurface/card': ratio(s.onSurface, card),
          'outline/surface': ratio(s.outline, s.surface),
          'outline/card': ratio(s.outline, card),
          'primary/surface': ratio(s.primary, s.surface),
          'onPrimary/primary': ratio(s.onPrimary, s.primary),
          'ink/primaryContainer': ratio(
            s.onPrimaryContainer,
            s.primaryContainer,
          ),
        };
        for (final e in text.entries) {
          expect(
            e.value,
            greaterThanOrEqualTo(4.5),
            reason: '$p hc=$hc ${e.key}',
          );
        }
        final fieldEdge = ratio(edge, card);
        expect(fieldEdge, greaterThanOrEqualTo(3), reason: '$p hc=$hc edge');
        expect(edge, tokens.fieldEdge);
        final key = '${p.name}${hc ? ' hc' : ''}';
        mins[key] = text.values.reduce((a, b) => a < b ? a : b);
        mins['$key field edge'] = fieldEdge;
      }
    }
    // Measured numbers for the report.
    // ignore: avoid_print
    print({for (final e in mins.entries) e.key: e.value.toStringAsFixed(2)});
  });

  testWidgets('Matrix makes the app dark and keeps the saved theme and '
      'accent; Standard restores them', (tester) async {
    final c = await launchWith(
      tester,
      initial: const AppearanceSettings(
        theme: ThemeChoice.light,
        accent: AccentChoice.purple,
      ),
    );
    expect(brightnessOf(tester), Brightness.light);
    await tapKey(tester, 'open-settings');
    expect(find.byKey(const ValueKey('palette-note')), findsNothing);
    await tapKey(tester, 'set-palette-matrix');
    expect(brightnessOf(tester), Brightness.dark);
    expect(schemeOf(tester).primary, const Color(0xFF88E8A2));
    expect(c.value.palette, PaletteChoice.matrix);
    expect(c.value.theme, ThemeChoice.light, reason: 'saved theme kept');
    expect(c.value.accent, AccentChoice.purple, reason: 'saved accent kept');
    expect(
      find.text(
        'Matrix has its own light or dark look; your theme and accent '
        'choices are kept for Standard.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('set-palette-matrix'))),
      matchesSemantics(
        label: 'Matrix',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('set-palette-standard'))),
      matchesSemantics(
        label: 'Standard',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );

    await tapKey(tester, 'set-palette-trans');
    expect(brightnessOf(tester), Brightness.light);
    await tapKey(tester, 'set-palette-standard');
    expect(brightnessOf(tester), Brightness.light);
    expect(schemeOf(tester).primary, accentTones[AccentChoice.purple]!.$1);
    expect(find.byKey(const ValueKey('palette-note')), findsNothing);
  });

  testWidgets('a recorded value is drawn in onSurface in every palette', (
    tester,
  ) async {
    for (final p in PaletteChoice.values) {
      for (final hc in [false, true]) {
        await launchWith(
          tester,
          initial: AppearanceSettings(palette: p, highContrast: hc),
        );
        await tester.enterText(
          find.byKey(const ValueKey('weight-input')),
          '72.4',
        );
        await tapKey(tester, 'weight-save');
        final para = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('weight-latest')),
            matching: find.byType(RichText),
          ),
        );
        expect(
          para.text.style?.color,
          schemeOf(tester).onSurface,
          reason: '$p',
        );
      }
    }
  });

  for (final lang in [LanguageChoice.en, LanguageChoice.tr]) {
    testWidgets('palette swatches at 320 dp and 2x text (${lang.name}) do '
        'not overflow', (tester) async {
      await launchWith(
        tester,
        initial: AppearanceSettings(
          language: lang,
          palette: PaletteChoice.axolotl,
        ),
      );
      tester.view.physicalSize = const Size(320, 4000);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settle(tester);
      await tapKey(tester, 'open-settings');
      for (final p in PaletteChoice.values) {
        final f = find.byKey(ValueKey('set-palette-${p.name}'));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        expect(f, findsOneWidget);
        expect(
          tester.getRect(f).right,
          lessThanOrEqualTo(320),
          reason: '${p.name} inside the screen',
        );
      }
      expect(
        find.text(lang == LanguageChoice.tr ? 'Aksolotl' : 'Axolotl'),
        findsWidgets,
      );
      expect(
        find.text(lang == LanguageChoice.tr ? 'Renk paleti' : 'Palette'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('a settings change notifies listeners once', () async {
    final c = AppearanceController(MemoryAppearanceStore());
    var n = 0;
    c.addListener(() => n++);
    await c.update(c.value.copyWith(palette: PaletteChoice.matrix));
    expect(n, 1);
    await c.update(c.value.copyWith(palette: PaletteChoice.matrix));
    expect(n, 1, reason: 'no change, no notify');
    // A failed save changes what Settings shows: one more notify then.
    c.store = _FailingStore();
    await c.update(c.value.copyWith(accent: AccentChoice.blue));
    expect(c.saveFailed, isTrue);
    expect(n, 3);
    await c.update(c.value.copyWith(accent: AccentChoice.green));
    expect(n, 4, reason: 'still failing: one notify');
  });

  testWidgets('themes are memoised across an unrelated rebuild', (
    tester,
  ) async {
    final c = await launchWith(tester);
    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    final light = app().theme, dark = app().darkTheme;
    await c.update(c.value.copyWith(startScreen: StartScreen.timeline));
    await tester.pumpAndSettle();
    expect(identical(app().theme, light), isTrue);
    expect(identical(app().darkTheme, dark), isTrue);
    await c.update(c.value.copyWith(palette: PaletteChoice.trans));
    await tester.pumpAndSettle();
    expect(identical(app().theme, light), isFalse);
    expect(app().themeMode, ThemeMode.light);
    expect(identical(app().theme, app().darkTheme), isTrue);
  });
}
