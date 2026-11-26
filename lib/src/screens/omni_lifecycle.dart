import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Lifecycle hooks for OmniRoute screens — no `WidgetsBindingObserver`
/// boilerplate, no `addObserver` / `removeObserver`.
///
/// Opt in by mixing it into a stateless screen or an `OmniState`; override
/// only the hooks you need. Registration and cleanup are automatic.
///
/// ```dart
/// class HomeScreen extends OmniStatelessWidget with OmniLifecycle {
///   @override
///   void onAppResumed(BuildContext context) =>
///       context.read<FeedBloc>().add(FeedRefreshed());
///   ...
/// }
///
/// class _PlayerState extends OmniState<PlayerScreen> with OmniLifecycle {
///   @override
///   void onScreenHidden(BuildContext context) => player.pause();
///   @override
///   void onAppPaused(BuildContext context) => player.pause();
///   ...
/// }
/// ```
///
/// Hooks run outside `build`, so calling `setState` or adding Bloc events
/// in them is safe. They never run after the screen is disposed.
mixin OmniLifecycle {
  // ── App lifecycle ────────────────────────────────────────────────────

  /// Any app lifecycle change. Runs before the specific hook below.
  void onAppLifecycleChanged(BuildContext context, AppLifecycleState state) {}

  /// The app is visible and has focus again (e.g. returned from background).
  void onAppResumed(BuildContext context) {}

  /// The app lost focus but may be visible (incoming call, app switcher,
  /// another window on desktop).
  void onAppInactive(BuildContext context) {}

  /// The app is not visible (all views hidden).
  void onAppHidden(BuildContext context) {}

  /// The app is in the background (mobile). Save drafts, pause media.
  void onAppPaused(BuildContext context) {}

  /// The engine is about to detach; there may be no further callbacks.
  void onAppDetached(BuildContext context) {}

  // ── Screen visibility ────────────────────────────────────────────────

  /// This screen became the visible one: first shown, a page above it was
  /// popped, or its tab was selected again.
  void onScreenVisible(BuildContext context) {}

  /// This screen stopped being the visible one: a page was pushed over it,
  /// another tab was selected, or it is being popped. Each
  /// [onScreenVisible] is followed by exactly one [onScreenHidden], also
  /// when the screen is removed outright (e.g. `go` replaces the stack or
  /// the app is torn down). In that last case it runs while the screen is
  /// being disposed: don't look up inherited widgets (`context.read`) there;
  /// keep what you need in a field.
  void onScreenHidden(BuildContext context) {}

  // ── System changes ───────────────────────────────────────────────────

  /// The system is low on memory. Drop caches you can rebuild.
  void onMemoryPressure(BuildContext context) {}

  /// Window size, orientation, insets or keyboard changed. `MediaQuery`
  /// has the new values from the next frame on.
  void onMetricsChanged(BuildContext context) {}

  /// The platform switched between light and dark mode.
  void onBrightnessChanged(BuildContext context, Brightness brightness) {}

  /// The user's preferred locales changed.
  void onLocalesChanged(BuildContext context, List<Locale>? locales) {}

  /// The system text scale changed.
  void onTextScaleChanged(BuildContext context) {}
}

/// Connects an [OmniLifecycle] target to the binding for one screen
/// element. Created on mount, disposed on unmount.
@internal
class OmniLifecycleHub with WidgetsBindingObserver {
  /// Starts observing for [element]; [target] returns the current hooks
  /// object (the widget for stateless screens, the State for stateful).
  OmniLifecycleHub(this.element, this.target) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// The screen element; also the context passed to hooks.
  final Element element;

  /// The hooks object, read fresh on every call.
  final OmniLifecycle? Function() target;

  /// Optional inner context below an auto-hosted [OmniBlocScope].
  BuildContext? hookContext;

  bool? _visible;
  bool _disposed = false;

  void _call(void Function(OmniLifecycle hooks, BuildContext context) hook) {
    if (_disposed || !element.mounted) return;
    final hooks = target();
    if (hooks == null) return;
    final ctx = (hookContext?.mounted ?? false) ? hookContext! : element;
    hook(hooks, ctx);
  }

  /// Wraps the screen's built child in a tiny widget that tracks
  /// visibility. Only that widget depends on the route and TickerMode, so a
  /// push/pop above the screen does not rebuild the screen itself.
  Widget wrap(Widget child) => _OmniVisibilityProbe(hub: this, child: child);

  /// Registers the dependencies that change visibility on [dependent] and
  /// reports a change after the frame.
  void trackVisibility(BuildContext dependent) {
    final visible =
        (ModalRoute.isCurrentOf(dependent) ?? true) &&
        TickerMode.valuesOf(dependent).enabled;
    if (visible == _visible) return;
    _visible = visible;
    _pending.add(this);
    if (_pending.length == 1) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _flush());
    }
  }

  // Visibility changes of one frame are reported together, every
  // "hidden" before any "visible" (old page leaves, then new page enters).
  static final List<OmniLifecycleHub> _pending = [];

  static void _flush() {
    final hubs = List.of(_pending);
    _pending.clear();
    for (final visible in [false, true]) {
      for (final hub in hubs) {
        if (hub._visible != visible || hub._reported == visible) continue;
        hub._reported = visible;
        hub._call(
          (h, c) => visible ? h.onScreenVisible(c) : h.onScreenHidden(c),
        );
      }
    }
  }

  // Last state reported to the hooks (null = nothing reported yet).
  bool? _reported;

  /// Stops observing; no hook runs afterwards. A screen that was last
  /// reported visible gets `onScreenHidden` now, so every visible is paired
  /// with a hidden even when the screen is removed in one frame.
  void dispose() {
    if (_reported ?? false) {
      _reported = false;
      _call((h, c) => h.onScreenHidden(c));
    }
    _disposed = true;
    _pending.remove(this);
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _call((h, c) {
    h.onAppLifecycleChanged(c, state);
    if (_disposed || !element.mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        h.onAppResumed(c);
      case AppLifecycleState.inactive:
        h.onAppInactive(c);
      case AppLifecycleState.hidden:
        h.onAppHidden(c);
      case AppLifecycleState.paused:
        h.onAppPaused(c);
      case AppLifecycleState.detached:
        h.onAppDetached(c);
    }
  });

  @override
  void didHaveMemoryPressure() => _call((h, c) => h.onMemoryPressure(c));

  @override
  void didChangeMetrics() => _call((h, c) => h.onMetricsChanged(c));

  @override
  void didChangePlatformBrightness() => _call(
    (h, c) => h.onBrightnessChanged(
      c,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    ),
  );

  @override
  void didChangeLocales(List<Locale>? locales) =>
      _call((h, c) => h.onLocalesChanged(c, locales));

  @override
  void didChangeTextScaleFactor() => _call((h, c) => h.onTextScaleChanged(c));
}

class _OmniVisibilityProbe extends StatelessWidget {
  const _OmniVisibilityProbe({required this.hub, required this.child});

  final OmniLifecycleHub hub;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    hub.trackVisibility(context);
    return child;
  }
}
