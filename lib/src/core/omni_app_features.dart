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

/// Shows [splash] until [onInit] completes, then [child].
@internal
class OmniInitGate extends StatefulWidget {
  /// Runs [onInit] once.
  const OmniInitGate({
    super.key,
    required this.onInit,
    required this.splash,
    required this.child,
  });

  /// Startup work; the context can read global Blocs.
  final Future<void> Function(BuildContext context) onInit;

  /// Shown while [onInit] runs.
  final WidgetBuilder? splash;

  /// The app, shown afterwards.
  final Widget child;

  @override
  State<OmniInitGate> createState() => _OmniInitGateState();
}

class _OmniInitGateState extends State<OmniInitGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.sync(() => widget.onInit(context))
        .catchError((Object e, StackTrace s) {
          // Reported, then the app opens anyway so it is never stuck on the
          // splash screen.
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: e,
              stack: s,
              library: 'omni_route',
              context: ErrorDescription('in OmniApp.onInit'),
            ),
          );
        })
        .whenComplete(() {
          if (mounted) setState(() => _ready = true);
        });
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : (widget.splash?.call(context) ?? const SizedBox.shrink());
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
