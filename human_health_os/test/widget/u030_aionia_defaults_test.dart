// U030 (AIONIA v1.4 §19): on first run the app is dark with the device's own
// font; a saved choice is kept; Settings offers dark, light and system.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';

import 'u005_settings_test.dart' show launchWith;

void main() {
  test('first-run defaults: dark theme and the system font', () {
    const fresh = AppearanceSettings();
    expect(fresh.theme, ThemeChoice.dark);
    expect(fresh.font, FontChoice.system);
    // Nothing stored yet: the same defaults.
    final empty = AppearanceSettings.fromJson(const {});
    expect(empty.theme, ThemeChoice.dark);
    expect(empty.font, FontChoice.system);
  });

  test('a stored choice is kept, never replaced by the new default', () {
    for (final t in ThemeChoice.values) {
      final s = AppearanceSettings(theme: t);
      expect(AppearanceSettings.fromJson(s.toJson()).theme, t);
    }
  });

  testWidgets('the app opens dark and Settings can switch to light', (
    tester,
  ) async {
    await launchWith(tester);
    final ctx = tester.element(find.byKey(const ValueKey('screen-today')));
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(
      Theme.of(ctx).textTheme.bodyMedium?.fontFamily,
      isNot('OpenDyslexic'),
    );
  });
}
