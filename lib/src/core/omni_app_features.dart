import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../screens/omni_lifecycle.dart';
import 'omni_router.dart';

/// Runs app-wide [OmniLifecycle] hooks (`OmniApp(lifecycle:)`). The context
/// passed to hooks is below the global Blocs.
@internal
class OmniAppLifecycleScope extends StatefulWidget {
  /// Observes the app for [lifecycle].
  const OmniAppLifecycleScope({
    super.key,
    required this.lifecycle,
    required this.child,
  });

  /// The hooks object.
  final OmniLifecycle lifecycle;

  /// The app below.
  final Widget child;

  @override
  State<OmniAppLifecycleScope> createState() => _OmniAppLifecycleScopeState();
}

class _OmniAppLifecycleScopeState extends State<OmniAppLifecycleScope> {
  late final OmniLifecycleHub _hub = OmniLifecycleHub(
    context as Element,
    () => widget.lifecycle,
  );

  @override
  void initState() {
    super.initState();
    _hub; // start observing
  }

  @override
  void dispose() {
    _hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Error builder rendered by [OmniInitGate] when `OmniApp(onInit:)` fails and
/// `onInitError` is provided; invoking [retry] restarts startup initialization.
typedef OmniInitErrorBuilder =
    Widget Function(
      BuildContext context,
      Object error,
      StackTrace stack,
      VoidCallback retry,
    );

/// Asynchronous callback executed after `OmniApp(onInit:)` finishes to pick a
/// starting route (e.g. `'/onboarding'` vs `'/dashboard'`).
typedef OmniInitialRouteResolver = FutureOr<String?> Function(BuildContext context);

/// Shows [splash] until [onInit] and optional [resolveInitialRoute] complete,
/// then renders [child] (or [onInitError] with retry when initialization fails).
@internal
class OmniInitGate extends StatefulWidget {
  /// Runs [onInit] once.
  const OmniInitGate({
    super.key,
    required this.child,
    this.onInit,
    this.initTimeout,
    this.splash,
    this.onInitError,
    this.resolveInitialRoute,
    this.router,
  });

  /// Startup work; the context can read global repositories & Blocs.
  final Future<void> Function(BuildContext context)? onInit;

  /// Optional timeout applied to [onInit].
  final Duration? initTimeout;

  /// Shown while startup runs.
  final WidgetBuilder? splash;

  /// Optional recovery view when [onInit] or [resolveInitialRoute] fails.
  final OmniInitErrorBuilder? onInitError;

  /// Optional destination resolver invoked after [onInit] completes.
  final OmniInitialRouteResolver? resolveInitialRoute;

  /// Router updated if [resolveInitialRoute] returns a non-empty location.
  final OmniRouter? router;

  /// The app, shown afterwards.
  final Widget child;

  @override
  State<OmniInitGate> createState() => _OmniInitGateState();
}

class _OmniInitGateState extends State<OmniInitGate> {
  bool _ready = false;
  Object? _error;
  StackTrace? _stack;
  int _runEpoch = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final epoch = ++_runEpoch;
    if (mounted && (_error != null || _ready)) {
      setState(() {
        _error = null;
        _stack = null;
        _ready = false;
      });
    }
    try {
      if (widget.onInit != null) {
        final fut = Future<void>.sync(() => widget.onInit!(context));
        await (widget.initTimeout == null
            ? fut
            : fut.timeout(widget.initTimeout!));
      }
      if (!mounted || epoch != _runEpoch) return;
      if (widget.resolveInitialRoute != null) {
        final dest = await Future<String?>.sync(
          () => widget.resolveInitialRoute!(context),
        );
        if (!mounted || epoch != _runEpoch) return;
        if (dest != null && dest.isNotEmpty) {
          widget.router?.go(dest, animated: false);
        }
      }
      if (mounted && epoch == _runEpoch) {
        setState(() => _ready = true);
      }
    } catch (e, s) {
      if (!mounted || epoch != _runEpoch) return;
      if (widget.onInitError != null) {
        setState(() {
          _error = e;
          _stack = s;
        });
      } else {
        // Reported, then the app opens anyway so existing fallback behavior
        // never leaves the user stuck on the splash screen without a custom UI.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'omni_route',
            context: ErrorDescription('in OmniApp.onInit'),
          ),
        );
        setState(() => _ready = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && widget.onInitError != null) {
      return widget.onInitError!(
        context,
        _error!,
        _stack ?? StackTrace.empty,
        _run,
      );
    }
    return _ready
        ? widget.child
        : (widget.splash?.call(context) ?? const SizedBox.shrink());
  }
}

/// Closes the keyboard when the user taps outside a text field.
///
/// Uses the text field's own tap-outside detection (`TapRegion`): every
/// `EditableText` invokes [EditableTextTapOutsideIntent] /
/// [EditableTextTapUpOutsideIntent], and this widget handles them for the
/// whole app. Nothing joins the gesture arena, taps on the field's toolbar
/// and handles count as inside, and a pointer that moved further than a tap
/// (a scroll or drag) leaves the keyboard open.
@internal
class OmniKeyboardDismiss extends StatefulWidget {
  /// Wraps [child].
  const OmniKeyboardDismiss({super.key, required this.child});

  /// The app below.
  final Widget child;

  @override
  State<OmniKeyboardDismiss> createState() => _OmniKeyboardDismissState();
}

class _OmniKeyboardDismissState extends State<OmniKeyboardDismiss> {
  // Where each pointer went down outside a focused field.
  final Map<int, Offset> _downs = {};

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: (i) {
        final e = i.pointerDownEvent;
        _downs[e.pointer] = e.position;
        return null;
      },
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(
          onInvoke: (i) {
            final e = i.pointerUpEvent;
            final down = _downs.remove(e.pointer);
            if (down != null &&
                (e.position - down).distance <= computeHitSlop(e.kind, null)) {
              i.focusNode.unfocus();
            }
            return null;
          },
        ),
  };

  @override
  Widget build(BuildContext context) =>
      Actions(actions: _actions, child: widget.child);
}

/// "Press back again to exit" on the first page (Android only).
@internal
class OmniExitGuard extends StatefulWidget {
  /// Guards [child].
  const OmniExitGuard({
    super.key,
    required this.window,
    required this.onWarning,
    required this.child,
  });

  /// Second press must come within this time.
  final Duration window;

  /// Called on the first press (show a SnackBar / toast).
  final void Function(BuildContext context)? onWarning;

  /// The page.
  final Widget child;

  /// Whether exit confirmation applies on this platform.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  State<OmniExitGuard> createState() => _OmniExitGuardState();
}

class _OmniExitGuardState extends State<OmniExitGuard> {
  Timer? _armed;

  @override
  void dispose() {
    _armed?.cancel();
    super.dispose();
  }

  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    if (_armed?.isActive ?? false) {
      _armed!.cancel();
      SystemNavigator.pop();
      return;
    }
    _armed = Timer(widget.window, () {});
    widget.onWarning?.call(context);
  }

  @override
  Widget build(BuildContext context) {
    // Same widget shape for every page (only canPop changes), so page state
    // is never reset. Also checks OmniRouter.canPopOf so shells/sub-navigators
    // pushed over another root page don't trigger double-back exit early.
    final isRoot =
        (ModalRoute.of(context)?.isFirst ?? false) &&
        !OmniRouter.canPopOf(context);
    return PopScope(
      canPop: !isRoot,
      onPopInvokedWithResult: _onBack,
      child: widget.child,
    );
  }
}
