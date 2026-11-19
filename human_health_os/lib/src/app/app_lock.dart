/// The optional app lock of an encrypted vault (G-36, D-046): after the
/// chosen minutes without use, or when the app is hidden if the person
/// asked for that, the vault is closed and the gate asks for the
/// passphrase or the recovery key again. Off by default.
///
/// Thirty seconds before an inactivity lock a banner says so. Use is any
/// tap, click, scroll or key press, a screen reader's action or move
/// (TalkBack, VoiceOver, Narrator: these arrive as semantics actions, not
/// as touches), a change of keyboard focus, and typing in the focused text
/// field (an on-screen keyboard included). The lock itself writes nothing:
/// saved records are already on disk, unsaved typing is dropped.
///
/// While a system file chooser or save dialog is open ([holdAppLock]) the
/// app being hidden does not lock it: on Android such a chooser covers the
/// app and hides it, and a lock then would make the import fail.
library;

import 'dart:async';
import 'dart:ui' show SemanticsActionEvent, SemanticsActionEventCallback;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';

/// Whether this session can lock, and if not, why (shown in Settings).
enum AppLockAvailability {
  /// An opened encrypted vault: there is a key to drop.
  available,

  /// A development build that saves without encryption.
  unencrypted,

  /// Nothing is kept in a vault (a memory-only session).
  nothingSaved,
}

/// What made the app lock.
enum AppLockCause { idle, hidden }

/// How long the banner shows before an inactivity lock.
const Duration appLockWarning = Duration(seconds: 30);

/// How long the app may stay hidden before lock-when-hidden locks it: a
/// brief system overlay (a permission prompt, a share sheet that hides the
/// app for a moment) does not lock.
const Duration appLockHiddenGrace = Duration(seconds: 2);

/// System dialogs open right now (file choosers, save dialogs); see
/// [holdAppLock].
class AppLockHolds extends ChangeNotifier {
  AppLockHolds._();

  /// The one register; the system dialogs it counts are app-wide too.
  static final AppLockHolds instance = AppLockHolds._();

  int _count = 0;

  /// True while at least one hold is not released.
  bool get held => _count > 0;

  void _release() {
    _count--;
    notifyListeners();
  }
}

/// Keeps lock-when-hidden from firing while a system file chooser or save
/// dialog is open; call the returned function when it closes (in a
/// `finally`). Calling it again does nothing. Inactivity still counts
/// before the hold and after its release, and a lock already due is not
/// held back.
VoidCallback holdAppLock() {
  final holds = AppLockHolds.instance;
  holds._count++;
  var released = false;
  return () {
    if (released) return;
    released = true;
    holds._release();
  };
}

/// Runs [dialog] (a system chooser) with the app lock held; see
/// [holdAppLock].
Future<T> withAppLockHeld<T>(Future<T> Function() dialog) async {
  final release = holdAppLock();
  try {
    return await dialog();
  } finally {
    release();
  }
}

/// Tells Settings whether the lock can be used in this session.
class AppLockScope extends InheritedWidget {
  const AppLockScope({
    super.key,
    required this.availability,
    required super.child,
  });

  final AppLockAvailability availability;

  /// Without a scope (a screen shown alone in a test) nothing can lock.
  static AppLockAvailability of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppLockScope>()
          ?.availability ??
      AppLockAvailability.nothingSaved;

  @override
  bool updateShouldNotify(AppLockScope old) => old.availability != availability;
}

/// Watches for use and for the app being hidden, and calls [onLock].
/// Always in the tree (with [idle] null and [lockWhenHidden] false when no
/// lock applies), so turning the lock on or off never rebuilds the pages
/// below it or discards what is typed there.
class AppLockGuard extends StatefulWidget {
  const AppLockGuard({
    super.key,
    required this.idle,
    required this.lockWhenHidden,
    required this.onLock,
    required this.child,
  });

  /// Time without use before the lock; null for no inactivity lock.
  final Duration? idle;
  final bool lockWhenHidden;
  final void Function(AppLockCause cause) onLock;
  final Widget child;

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard> {
  Timer? _idleTimer;
  Timer? _tick;

  /// Runs while the app is hidden, until [appLockHiddenGrace] has passed.
  Timer? _hiddenTimer;

  /// The app is hidden (or paused) right now.
  bool _hidden = false;

  /// The text being typed in the focused field, watched for typing.
  TextEditingController? _typing;

  /// The semantics handler this guard wrapped, and its wrapper.
  SemanticsActionEventCallback? _semanticsBefore;
  SemanticsActionEventCallback? _semanticsHook;

  /// Seconds left while the banner shows; null otherwise.
  int? _secondsLeft;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: _lifecycle);
    HardwareKeyboard.instance.addHandler(_onKey);
    FocusManager.instance.addListener(_onFocus);
    AppLockHolds.instance.addListener(_onHoldsChanged);
    // A screen reader's taps, swipes and moves reach the app as semantics
    // actions from the platform, never as pointer events: the handler the
    // framework installed is wrapped, and still receives every action.
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    _semanticsBefore = dispatcher.onSemanticsActionEvent;
    _semanticsHook = (SemanticsActionEvent e) {
      if (mounted) _activity();
      _semanticsBefore?.call(e);
    };
    dispatcher.onSemanticsActionEvent = _semanticsHook;
    _restart();
  }

  @override
  void didUpdateWidget(AppLockGuard old) {
    super.didUpdateWidget(old);
    if (old.idle != widget.idle) _restart();
  }

  @override
  void dispose() {
    _cancel();
    _hiddenTimer?.cancel();
    _life.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    FocusManager.instance.removeListener(_onFocus);
    AppLockHolds.instance.removeListener(_onHoldsChanged);
    _watchTyping(null);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    if (identical(dispatcher.onSemanticsActionEvent, _semanticsHook)) {
      dispatcher.onSemanticsActionEvent = _semanticsBefore;
    }
    super.dispose();
  }

  void _cancel() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _tick?.cancel();
    _tick = null;
  }

  /// Starts the wait again from now; hides the banner.
  void _restart() {
    _cancel();
    if (_secondsLeft != null) {
      _secondsLeft = null;
      if (mounted) {
        // A text change made while building is still use; the banner then
        // goes away after this frame.
        if (SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          setState(() {});
        }
      }
    }
    final idle = widget.idle;
    if (idle == null) return;
    final quiet = idle - appLockWarning;
    _idleTimer = Timer(quiet.isNegative ? Duration.zero : quiet, _warn);
  }

  void _warn() {
    if (!mounted) return;
    setState(() => _secondsLeft = appLockWarning.inSeconds);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = (_secondsLeft ?? 1) - 1;
      if (left <= 0) {
        _cancel();
        setState(() => _secondsLeft = null);
        widget.onLock(AppLockCause.idle);
      } else {
        setState(() => _secondsLeft = left);
      }
    });
  }

  void _activity([Object? _]) {
    if (widget.idle != null) _restart();
  }

  bool _onKey(KeyEvent event) {
    _activity();
    return false; // never consumes the key
  }

  /// Focus moved (Tab, a screen reader's focus, a field tapped): use. The
  /// newly focused text field is watched so that typing in it, from any
  /// keyboard, counts as well.
  void _onFocus() {
    _activity();
    final ctx = FocusManager.instance.primaryFocus?.context;
    _watchTyping(
      ctx?.findAncestorStateOfType<EditableTextState>()?.widget.controller,
    );
  }

  void _watchTyping(TextEditingController? next) {
    if (identical(next, _typing)) return;
    final previous = _typing;
    _typing = null;
    if (previous != null) {
      try {
        previous.removeListener(_activity);
      } catch (_) {
        // Already disposed with its page: nothing to remove.
      }
    }
    next?.addListener(_activity);
    _typing = next;
  }

  void _lifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _hidden = true;
        _armHidden();
      case AppLifecycleState.inactive || AppLifecycleState.resumed:
        _hidden = false;
        _hiddenTimer?.cancel();
        _hiddenTimer = null;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Starts the grace period of a hidden app, unless a system dialog holds
  /// the lock or it already runs.
  void _armHidden() {
    if (!widget.lockWhenHidden || AppLockHolds.instance.held) return;
    _hiddenTimer ??= Timer(appLockHiddenGrace, _hiddenLock);
  }

  void _hiddenLock() {
    _hiddenTimer = null;
    if (!mounted || !_hidden || !widget.lockWhenHidden) return;
    if (AppLockHolds.instance.held) return;
    _cancel();
    if (_secondsLeft != null) setState(() => _secondsLeft = null);
    widget.onLock(AppLockCause.hidden);
  }

  /// A dialog closed: if the app is still hidden, the grace period starts.
  void _onHoldsChanged() {
    if (_hidden && mounted) _armHidden();
  }

  @override
  Widget build(BuildContext context) {
    final left = _secondsLeft;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _activity,
      onPointerMove: _activity,
      onPointerHover: _activity,
      onPointerSignal: _activity,
      onPointerPanZoomStart: _activity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (left != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _LockBanner(secondsLeft: left, onStay: _restart),
            ),
        ],
      ),
    );
  }
}

class _LockBanner extends StatelessWidget {
  const _LockBanner({required this.secondsLeft, required this.onStay});

  final int secondsLeft;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          key: const ValueKey('app-lock-banner'),
          elevation: 6,
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Announced once; the visible countdown is not read out
                // every second.
                Semantics(
                  liveRegion: true,
                  container: true,
                  label: s.lockWarningSpoken,
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          color: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.lockWarning(secondsLeft),
                            key: const ValueKey('app-lock-banner-text'),
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const ValueKey('app-lock-stay'),
                    onPressed: onStay,
                    child: Text(s.lockStayOpen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
