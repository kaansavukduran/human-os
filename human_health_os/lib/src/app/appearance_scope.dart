import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/local/sealed_preferences.dart';
import '../domain/settings/appearance.dart';

/// The person's appearance choices, changed on the Settings page and saved
/// through [store]. A failed save keeps the change for this session.
class AppearanceController extends ValueNotifier<AppearanceSettings> {
  AppearanceController(
    this.store, [
    super.initial = const AppearanceSettings(),
  ]);

  AppearanceStore store;

  /// True when the last save failed (shown on the Settings page).
  bool saveFailed = false;

  Future<void> visit(DiscoveryStep step) => update(value.visit(step));

  /// Switches to the preferences sealed in a just-opened vault (U018): saved
  /// choices are applied; with none saved yet, the choices of this session
  /// (for example from the introduction) are saved; a file that cannot be
  /// read is left as it is (until a choice is changed) and this session's
  /// choices stay on screen.
  ///
  /// A choice changed while the file was being read wins over the file
  /// (R005).
  Future<void> adopt(SealedAppearanceStore next) async {
    store = next;
    final before = value;
    final saved = await next.load();
    final changedMeanwhile = value != before;
    switch (next.state) {
      case SealedPreferencesState.readable when !changedMeanwhile:
        value = saved.copyWith(firstRunDone: true);
      case SealedPreferencesState.none:
      case SealedPreferencesState.readable:
        await _save(value);
      case SealedPreferencesState.unusable || SealedPreferencesState.unknown:
        break;
    }
    notifyListeners();
  }

  Future<void> update(AppearanceSettings next) async {
    if (next == value) return;
    final failedBefore = saveFailed;
    // Setting the value notifies once; a second notify follows only when
    // the save outcome shown on the Settings page changed.
    value = next;
    await _save(next);
    if (saveFailed != failedBefore) notifyListeners();
  }

  /// Saves run one after another, so two quick changes never write the same
  /// file at once; the last change is the one kept (R005).
  Future<void> _saving = Future<void>.value();

  Future<void> _save(AppearanceSettings settings) {
    final target = store;
    final run = _saving.then((_) async {
      try {
        await target.save(settings);
        saveFailed = false;
      } catch (_) {
        saveFailed = true;
      }
    });
    _saving = run;
    return run;
  }
}

/// The parts of the settings a widget can depend on alone (U031-S4), so a
/// change rebuilds only what shows it. [AppearanceScope.maybeOf] still
/// depends on every part.
enum AppearanceAspect {
  /// Units, date order and clock: how values and times are written
  /// ([S.of] depends on this).
  display,

  /// What Today shows and in which order: hidden sections, check-ins or
  /// measurements first, and the discovery card.
  todayLayout,

  /// Which measurement tiles show, in which order.
  tiles,

  /// Whether the number pad starts open.
  pad,

  /// Whether Aion is shown.
  aion,

  /// Which area introductions are closed.
  explained,

  /// The discovery steps taken, and whether discovery is on.
  discovery,
}

bool _aspectChanged(
  AppearanceAspect aspect,
  AppearanceSettings a,
  AppearanceSettings b,
) => switch (aspect) {
  AppearanceAspect.display =>
    a.units != b.units || a.dateOrder != b.dateOrder || a.clock != b.clock,
  AppearanceAspect.todayLayout =>
    !setEquals(a.hiddenSections, b.hiddenSections) ||
        a.checkInsFirst != b.checkInsFirst ||
        a.measurementsFirst != b.measurementsFirst ||
        a.discoveryEnabled != b.discoveryEnabled,
  AppearanceAspect.tiles =>
    !listEquals(a.tileOrder, b.tileOrder) ||
        !setEquals(a.hiddenTiles, b.hiddenTiles),
  AppearanceAspect.pad => a.padOpen != b.padOpen,
  AppearanceAspect.aion => a.showAion != b.showAion,
  AppearanceAspect.explained => !setEquals(a.explainedAreas, b.explainedAreas),
  AppearanceAspect.discovery =>
    a.discoveryEnabled != b.discoveryEnabled ||
        !setEquals(a.discovered, b.discovered),
};

/// Provides the [AppearanceController] below it. Widgets that read one
/// part of the settings depend on that [AppearanceAspect] only.
class AppearanceScope extends StatefulWidget {
  const AppearanceScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppearanceController controller;
  final Widget child;

  /// The controller, depending on every change (including the save
  /// outcome shown on the Settings page).
  static AppearanceController? maybeOf(BuildContext context) =>
      InheritedModel.inheritFrom<_AppearanceModel>(context)?.controller;

  /// The controller without depending on it: for callbacks and one-off
  /// reads that must not rebuild the caller.
  static AppearanceController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AppearanceModel>()?.controller;

  /// The current settings, depending only on [aspect]; null without a
  /// scope.
  static AppearanceSettings? watch(
    BuildContext context,
    AppearanceAspect aspect,
  ) => InheritedModel.inheritFrom<_AppearanceModel>(
    context,
    aspect: aspect,
  )?.settings;

  @override
  State<AppearanceScope> createState() => _AppearanceScopeState();
}

class _AppearanceScopeState extends State<AppearanceScope> {
  /// Counts notifications, so a notify without a new value (the save
  /// outcome) still reaches the widgets that depend on everything.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(AppearanceScope old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) => _AppearanceModel(
    controller: widget.controller,
    settings: widget.controller.value,
    generation: _generation,
    child: widget.child,
  );
}

class _AppearanceModel extends InheritedModel<AppearanceAspect> {
  const _AppearanceModel({
    required this.controller,
    required this.settings,
    required this.generation,
    required super.child,
  });

  final AppearanceController controller;
  final AppearanceSettings settings;
  final int generation;

  @override
  bool updateShouldNotify(_AppearanceModel old) =>
      controller != old.controller ||
      generation != old.generation ||
      settings != old.settings;

  @override
  bool updateShouldNotifyDependent(
    _AppearanceModel old,
    Set<AppearanceAspect> dependencies,
  ) =>
      controller != old.controller ||
      dependencies.any((a) => _aspectChanged(a, old.settings, settings));
}
