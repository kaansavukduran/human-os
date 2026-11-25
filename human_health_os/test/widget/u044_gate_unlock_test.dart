// U044 review: at 320 dp with 2x text the gate draws its field names above
// the fields (WholeLabelField). Unlocking by typing and pressing Enter, and
// keeping focus when the layout switches, must still work there.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'f006_vault_gate_test.dart'
    show Disk, createThroughGate, launch, pass, saveWeight, settle, slowDerive;

Future<void> relaunchSmall(WidgetTester tester, Disk disk, Locale l) async {
  await launch(tester, disk, locale: l, derive: slowDerive);
  tester.view.physicalSize = const Size(320, 640);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await settle(tester);
}

final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  for (final l in const [Locale('en'), Locale('tr')]) {
    testWidgets('${l.languageCode}: 320 dp, 2x text: Enter unlocks the vault', (
      tester,
    ) async {
      final disk = Disk();
      await launch(tester, disk);
      await createThroughGate(tester);
      await saveWeight(tester, '73,6');
      await relaunchSmall(tester, disk, l);
      final field = find.byKey(const ValueKey('gate-passphrase'));
      // At this size the gate is a long list; the field may not be built
      // until it is scrolled to.
      await tester.scrollUntilVisible(field, 120, scrollable: _vertical);
      expect(field, findsOneWidget);
      final decoration = tester.widget<TextField>(field).decoration;
      expect(
        decoration?.labelText,
        isNull,
        reason: 'the name is drawn above the field at this size',
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.enterText(field, pass);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byKey(const ValueKey('screen-today')), findsOneWidget);
    });
  }

  testWidgets('the field keeps focus and text when its name moves above it', (
    tester,
  ) async {
    final disk = Disk();
    await launch(tester, disk);
    await createThroughGate(tester);
    await saveWeight(tester, '73,6');
    await launch(tester, disk, derive: slowDerive);
    final field = find.byKey(const ValueKey('gate-passphrase'));
    expect(tester.widget<TextField>(field).decoration?.labelText, isNotNull);
    await tester.tap(field);
    await tester.enterText(field, 'abc');
    await tester.pump();
    // The window narrows and the text grows while the person types.
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(field, 120, scrollable: _vertical);
    expect(tester.widget<TextField>(field).decoration?.labelText, isNull);
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, 'abc');
  });
}
