// A001: Flutter's accessibility guidelines (tap-target size on Android and
// iOS, a label on every tappable target, text contrast) on every area, the
// open add sheets of Labs and a measurement, at phone size in English and
// Turkish; and Today and Settings in every palette and in high contrast.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:human_health_os/src/app/appearance_scope.dart';
import 'package:human_health_os/src/app/bootstrap.dart';
import 'package:human_health_os/src/app/human_os_app.dart';
import 'package:human_health_os/src/core/capabilities.dart';
import 'package:human_health_os/src/data/local/log_repository.dart';
import 'package:human_health_os/src/domain/ports/health_repository.dart';
import 'package:human_health_os/src/domain/records/health_record.dart';
import 'package:human_health_os/src/domain/settings/appearance.dart';
import 'package:human_health_os/src/navigation/destination_switch.dart';
import 'package:human_health_os/src/navigation/destinations.dart';

import 'f007_measurements_test.dart' show dev, settle, tapKey;

const phone = Size(390, 844);

Future<void> launchAt(
  WidgetTester tester, {
  required Locale locale,
  AppearanceSettings appearance = const AppearanceSettings(),
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final s = await tester.runAsync(() async {
    final repo = LogRepository(
      sink: MemoryLogSink(),
      durability: StorageDurability.localFile,
      location: 'test',
    );
    final report = await repo.open();
    return servicesFor(dev, HostPlatform.linux, repo, report: report);
  });
  final c = AppearanceController(MemoryAppearanceStore(), appearance);
  await tester.pumpWidget(HumanOsApp(services: s!, appearance: c));
  await settle(tester);
}

/// Opens [id] through the shell's own switch (the bar or the More sheet
/// call the same function).
Future<void> open(WidgetTester tester, DestinationId id) async {
  expect(find.byKey(const ValueKey('nav-bar')), findsOneWidget);
  tester.widget<DestinationSwitch>(find.byType(DestinationSwitch).first).go(id);
  await settle(tester);
  expect(find.byKey(ValueKey('screen-${id.name}')), findsOneWidget);
}

/// Every guideline on what is on screen now.
Future<void> meetsAll(WidgetTester tester, {bool scrolled = false}) async {
  await expectLater(
    tester,
    meetsGuideline(scrolled ? androidUncut : androidTapTargetGuideline),
  );
  await expectLater(
    tester,
    meetsGuideline(scrolled ? iOSUncut : iOSTapTargetGuideline),
  );
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(everyLineContrast));
}

/// Known false positive of Flutter's tap-target guideline, documented here
/// rather than switched off: after a list has been scrolled, a target cut
/// by the list's clip is measured at its visible sliver. The guideline
/// skips a node "touching the edge of a scrollable", but in the entry
/// sheets it does not recognise the cut: at 390x844 the Labs sheet's
/// "Value" field (lab-value) was reported at 358x5 and "The report gives no
/// value" (lab-not-reported, a 56 dp CheckboxListTile) at 358x43, both only
/// because the list's clip ran through them. These variants skip only a
/// node whose visible rect ends exactly on an ancestor's clip on the short
/// side; every other node is measured as usual. The first screenful of
/// every screen and sheet is checked with the unmodified guidelines.
class _UncutTapTargetGuideline extends MinimumTapTargetGuideline {
  const _UncutTapTargetGuideline({required super.size, required super.link});

  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) return true;
    final clip = node.parentPaintClipRect ?? node.parentSemanticsClipRect;
    if (clip == null) return false;
    final r = node.rect;
    bool on(double a, double b) => (a - b).abs() < 0.5;
    final cutVertically =
        r.height < size.height &&
        (on(r.top, clip.top) || on(r.bottom, clip.bottom));
    final cutHorizontally =
        r.width < size.width &&
        (on(r.left, clip.left) || on(r.right, clip.right));
    return cutVertically || cutHorizontally;
  }
}

const androidUncut = _UncutTapTargetGuideline(
  size: Size(48, 48),
  link: 'https://support.google.com/accessibility/android/answer/7101858',
);
const iOSUncut = _UncutTapTargetGuideline(
  size: Size(44, 44),
  link: 'https://developer.apple.com/design/human-interface-guidelines/',
);

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

/// textContrastGuideline measures a semantics node only when its label is
/// exactly the string of one Text widget; a node that merges several lines
/// (an area introduction's heading and body, a card, a list tile) finds no
/// Text with that string and is skipped (flutter_test's
/// MinimumTextContrastGuideline._evaluateNode). This check covers every
/// line on screen: each painted, hit-testable paragraph's own text colour
/// (laid over what is around it) against the colour most painted in a 1 px
/// ring just around the paragraph (inside even the 2 px padding of a pill),
/// leaving out pixels of other lines and lines cut by their list's edge.
/// Text of a disabled control (drawn below half opacity) is exempt (WCAG
/// 1.4.3). Icons are glyphs too; at 24 px they are held to 3:1, the
/// non-text contrast of WCAG 1.4.11.
class _EveryLineContrast extends AccessibilityGuideline {
  const _EveryLineContrast();

  @override
  String get description => 'Every painted line meets WCAG AA contrast';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    late int width, height;
    final bytes = await tester.binding.runAsync<ByteData?>(() async {
      final image = await layer.toImage(view.paintBounds);
      width = image.width;
      height = image.height;
      final data = await image.toByteData();
      image.dispose();
      return data;
    });
    Color pixel(int x, int y) {
      final i = (y * width + x) * 4;
      return Color.fromARGB(
        bytes!.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    }

    final shown = find.byType(RichText).hitTestable().evaluate().toList();
    Rect boxOf(RenderBox r) {
      return MatrixUtils.transformRect(
        r.getTransformTo(null),
        Offset.zero & r.size,
      );
    }

    final boxes = [for (final e in shown) boxOf(e.renderObject! as RenderBox)];
    for (final element in shown) {
      final paragraph = element.renderObject! as RenderParagraph;
      final words = paragraph.text.toPlainText().trim();
      final style = paragraph.text.style;
      final color = style?.color;
      if (words.isEmpty || color == null || color.a < 0.5) continue;
      final box = MatrixUtils.transformRect(
        paragraph.getTransformTo(null),
        Offset.zero & paragraph.size,
      );
      if (box.isEmpty) continue;
      final outer = box.inflate(2);
      if (outer.left < 0 ||
          outer.top < 0 ||
          outer.right > width ||
          outer.bottom > height) {
        continue; // cut by the window edge
      }
      if (RenderAbstractViewport.maybeOf(paragraph) case final RenderBox v) {
        final list = boxOf(v);
        if (!list.contains(outer.topLeft) ||
            !list.contains(outer.bottomRight)) {
          continue; // cut by its list's edge, measured on another screenful
        }
      }
      final ring = <Color, int>{};
      for (var y = outer.top.floor(); y < outer.bottom.floor(); y++) {
        for (var x = outer.left.floor(); x < outer.right.floor(); x++) {
          final inside =
              x >= box.left.floor() - 1 &&
              x < box.right.ceil() + 1 &&
              y >= box.top.floor() - 1 &&
              y < box.bottom.ceil() + 1;
          if (inside) continue;
          // A pixel of a neighbouring line (lines can touch) is not the
          // background.
          final p = Offset(x + 0.5, y + 0.5);
          if (boxes.any((b) => b != box && b.contains(p))) continue;
          final c = pixel(x, y);
          ring[c] = (ring[c] ?? 0) + 1;
        }
      }
      if (ring.isEmpty) continue;
      final back = ring.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      final fore = Color.alphaBlend(color, back);
      final size = style?.fontSize ?? 14;
      final bold = (style?.fontWeight?.value ?? 400) >= 700;
      final large = size >= 18 || (bold && size >= 14);
      final need = large ? 3.0 : 4.5;
      final got = _ratio(fore, back);
      if (got < need - 0.01) {
        final icon =
            words.runes.length == 1 &&
            words.runes.first >= 0xE000 &&
            words.runes.first <= 0xF8FF;
        result += Evaluation.fail(
          '${icon ? 'an icon' : '"$words"'} (${element.widget.key ?? element.widget.runtimeType}, '
          '${size}px): ${got.toStringAsFixed(2)}:1, needs $need:1 '
          '(text $fore on $back)',
        );
      }
    }
    return result;
  }
}

const everyLineContrast = _EveryLineContrast();

/// The guidelines on each screenful of the area's list, top to bottom.
Future<void> meetsAllScrolled(WidgetTester tester, Finder screen) async {
  await meetsAll(tester);
  final scrollables = find.descendant(
    of: screen,
    matching: find.byType(Scrollable),
  );
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.first;
  final position = tester.state<ScrollableState>(scrollable).position;
  var guard = 0;
  while (position.pixels < position.maxScrollExtent && guard++ < 20) {
    position.jumpTo(
      (position.pixels + position.viewportDimension * 0.8).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
    await meetsAll(tester, scrolled: true);
  }
  position.jumpTo(0);
  await tester.pumpAndSettle();
}

const areas = [
  DestinationId.today,
  DestinationId.timeline,
  DestinationId.labs,
  DestinationId.medications,
  DestinationId.nutrition,
  DestinationId.activity,
  DestinationId.conditions,
  DestinationId.preventive,
  DestinationId.documents,
];

void main() {
  for (final locale in [const Locale('en', 'US'), const Locale('tr', 'TR')]) {
    final lang = locale.languageCode;
    for (final id in areas) {
      testWidgets('$lang: ${id.name} at 390x844 meets the tap-target, label '
          'and text-contrast guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await launchAt(tester, locale: locale);
        if (id != DestinationId.today) await open(tester, id);
        await meetsAllScrolled(
          tester,
          find.byKey(ValueKey('screen-${id.name}')),
        );
        handle.dispose();
      });
    }

    testWidgets('$lang: Settings at 390x844 meets the guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launchAt(tester, locale: locale);
      await tapKey(tester, 'open-settings');
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-settings')),
      );
      handle.dispose();
    });

    testWidgets('$lang: the open Labs add sheet meets the guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launchAt(tester, locale: locale);
      await open(tester, DestinationId.labs);
      // With no results the add button sits in the first step, below the
      // area's introduction.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('lab-add')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('screen-labs')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tapKey(tester, 'lab-add');
      await meetsAllScrolled(tester, find.byType(BottomSheet));
      handle.dispose();
    });

    testWidgets('$lang: the open blood-pressure sheet meets the guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launchAt(tester, locale: locale);
      await tapKey(tester, 'measure-tile-${RecordKind.bloodPressure.code}');
      expect(
        find.byKey(ValueKey('measure-sheet-${RecordKind.bloodPressure.code}')),
        findsOneWidget,
      );
      await meetsAllScrolled(tester, find.byType(BottomSheet));
      handle.dispose();
    });
  }

  final looks = <String, AppearanceSettings>{
    for (final p in PaletteChoice.values)
      for (final hc in [false, true])
        for (final theme
            in p == PaletteChoice.standard
                ? [ThemeChoice.light, ThemeChoice.dark]
                : [ThemeChoice.light])
          '${p.name}${p == PaletteChoice.standard ? ' ${theme.name}' : ''}'
              '${hc ? ' high contrast' : ''}': AppearanceSettings(
            palette: p,
            theme: theme,
            highContrast: hc,
          ),
  };
  for (final look in looks.entries) {
    testWidgets('${look.key}: Today and Settings meet the guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await launchAt(
        tester,
        locale: const Locale('en', 'US'),
        appearance: look.value,
      );
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-today')),
      );
      await tapKey(tester, 'open-settings');
      await meetsAllScrolled(
        tester,
        find.byKey(const ValueKey('screen-settings')),
      );
      handle.dispose();
    });
  }
}
