// Opens Settings → About Human OS the way a person does (U032): the build
// facts and the capability list live there, not on Today.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _scrollOf(String screen) => find
    .descendant(
      of: find.byKey(ValueKey(screen)),
      matching: find.byType(Scrollable),
    )
    .first;

/// From the app shell: the top-bar Settings button, then the About row
/// near the end of Settings.
Future<void> openAbout(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-settings')));
  await _frames(tester);
  final row = find.byKey(const ValueKey('settings-about'));
  await tester.scrollUntilVisible(
    row,
    400,
    maxScrolls: 200,
    scrollable: _scrollOf('screen-settings'),
  );
  // A "Saved" message left from an earlier step may cover the end of the
  // list (the row is the last one); it closes on its own, sooner here.
  for (final m in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    m.removeCurrentSnackBar();
  }
  await tester.ensureVisible(row);
  await _frames(tester);
  await tester.tap(row);
  await _frames(tester);
  expect(find.byKey(const ValueKey('screen-about')), findsOneWidget);
}

/// Scrolls About until [finder] is built, then brings its first match
/// into view (a text may appear more than once, e.g. "unknown").
Future<void> scrollAboutTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.drag(_scrollOf('screen-about'), const Offset(0, -300));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

Future<void> _frames(WidgetTester tester) => tester.pumpAndSettle();
