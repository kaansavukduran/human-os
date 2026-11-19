import 'package:flutter/widgets.dart';

import 'destinations.dart';

/// Lets a screen inside the shell open another area (U031: "Go to Today"
/// on an empty Timeline, "Show on Timeline" after a save). Outside the
/// shell (a screen shown on its own in a test) there is none, and such
/// actions are not offered.
class DestinationSwitch extends InheritedWidget {
  const DestinationSwitch({super.key, required this.go, required super.child});

  final ValueChanged<DestinationId> go;

  static ValueChanged<DestinationId>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DestinationSwitch>()?.go;

  @override
  bool updateShouldNotify(DestinationSwitch oldWidget) => go != oldWidget.go;
}
