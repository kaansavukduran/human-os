import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/ids.dart' show Clock;

/// Builds the state again just after each local midnight of
/// [midnightClock], and whenever the app comes back to the foreground
/// (U031-S4, R015): timers do not run while the device sleeps and miss a
/// clock or time-zone change. For anything that says "today" (Today's date
/// line, the Timeline's day headers). Apply after [WidgetsBindingObserver].
mixin MidnightRefresh<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  Timer? _midnight;

  /// The app's clock (the services' heartbeat clock), never DateTime.now().
  Clock get midnightClock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMidnight();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {});
    scheduleMidnight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.dispose();
  }

  /// Fires a second after the next local midnight (DateTime works out a
  /// daylight-saving day of 23 or 25 hours). Call again when the clock
  /// changes.
  void scheduleMidnight() {
    _midnight?.cancel();
    final now = midnightClock.nowUtc().toLocal();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      scheduleMidnight();
    });
  }
}
