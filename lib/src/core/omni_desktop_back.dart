import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'omni_router.dart';

/// Desktop "back": Alt+← (Windows/Linux), Cmd+[ and Cmd+← (macOS), the mouse
/// back button, and optionally Escape. Delegates to `routerDelegate.popRoute`
/// so `PopScope` and nested shell navigators behave uniformly. Not active on
/// web (the browser handles back) or mobile.
@internal
class OmniDesktopBack extends StatelessWidget {
  const OmniDesktopBack({
    super.key,
    required this.router,
    required this.escape,
    required this.child,
  });

  final OmniRouter router;
  final bool escape;
  final Widget child;

  static bool get isDesktop =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  void _back() => router.routerDelegate.popRoute();

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return child;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return Listener(
      onPointerDown: (e) {
        if (e.buttons & kBackMouseButton != 0) _back();
      },
      child: Shortcuts(
        shortcuts: {
          if (mac) ...{
            const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true):
                const _BackIntent(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
                const _BackIntent(),
          } else
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
                const _BackIntent(),
          if (escape)
            const SingleActivator(LogicalKeyboardKey.escape):
                const _BackIntent(),
        },
        child: Actions(
          actions: {
            _BackIntent: CallbackAction<_BackIntent>(onInvoke: (_) => _back()),
          },
          child: child,
        ),
      ),
    );
  }
}

class _BackIntent extends Intent {
  const _BackIntent();
}
