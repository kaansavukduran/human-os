/// The optional app lock of an encrypted vault (G-36, D-046): after the
/// chosen minutes without use, or when the app is hidden if the person
/// asked for that, the vault is closed and the gate asks for the
/// passphrase or the recovery key again. Off by default.
///
/// Thirty seconds before an inactivity lock a banner says so; any tap,
/// click, scroll or key press keeps the app open. The lock itself writes
/// nothing: saved records are already on disk, unsaved typing is dropped.
library;

import 'dart:async';

import 'package:flutter/material.dart';
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

  /// Seconds left while the banner shows; null otherwise.
  int? _secondsLeft;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onStateChange: _lifecycle);
    HardwareKeyboard.instance.addHandler(_onKey);
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
    _life.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
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
      if (mounted) setState(() {});
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

  void _lifecycle(AppLifecycleState state) {
    if (!widget.lockWhenHidden) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _cancel();
      if (_secondsLeft != null) setState(() => _secondsLeft = null);
      widget.onLock(AppLockCause.hidden);
    }
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
