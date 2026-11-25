// U043 review: a WholeChip shows a visible ring while it holds keyboard
// focus, activates with Enter and Space, and has no ring after a tap.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/presentation/widgets/whole_chip.dart';

Finder _ring() => find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.position == DecorationPosition.foreground &&
      w.decoration is ShapeDecoration,
);

void main() {
  testWidgets('keyboard focus draws a ring; Enter and Space toggle', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: WholeChip.choice(
                label: 'Same as this device',
                selected: selected,
                onSelected: (v) => setState(() => selected = v),
              ),
            ),
          ),
        ),
      ),
    );
    expect(_ring(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selected, isFalse);
    expect(_ring(), findsOneWidget);
  });

  testWidgets('no ring after a tap (touch highlight mode)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: WholeChip.action(
              label: 'Read a file',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Read a file'));
    await tester.pump();
    expect(taps, 1);
    expect(_ring(), findsNothing);
  });
}
