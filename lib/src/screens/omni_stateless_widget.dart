import 'package:flutter/widgets.dart';

import 'omni_lifecycle.dart';
import 'omni_screen.dart';
import 'omni_screen_host.dart';

/// A [StatelessWidget] screen with canonical [routePath] identity, automatic
/// lifecycle hooks, and automatic page-scoped Bloc hosting.
///
/// ```dart
/// class StudentScreen extends OmniStatelessWidget {
///   const StudentScreen({super.key});
///
///   @override
///   String get routePath => '/students';
///
///   @override
///   List<Provide> get provide => [
///     OmniBloc((_) => StudentBloc()),
///   ];
///
///   @override
///   Widget build(BuildContext context) => const Placeholder();
/// }
/// ```
abstract class OmniStatelessWidget extends StatelessWidget with OmniScreen {
  /// Creates a stateless screen.
  const OmniStatelessWidget({super.key});

  @override
  StatelessElement createElement() => _OmniStatelessElement(this);
}

class _OmniStatelessElement extends StatelessElement {
  _OmniStatelessElement(OmniStatelessWidget super.widget);

  // Only screens that mix in OmniLifecycle get a hub (no cost otherwise).
  OmniLifecycleHub? _lifecycle;

  @override
  void mount(Element? parent, Object? newSlot) {
    if (widget is OmniLifecycle) {
      _lifecycle = OmniLifecycleHub(
        this,
        () => widget is OmniLifecycle ? widget as OmniLifecycle : null,
      );
    }
    super.mount(parent, newSlot);
  }

  @override
  void unmount() {
    _lifecycle?.dispose();
    _lifecycle = null;
    super.unmount();
  }

  // Validating in build (not mount) lets Flutter show an ErrorWidget and
  // dispose the element normally.
  @override
  Widget build() {
    final screen = widget as OmniStatelessWidget;
    validateScreen(screen);
    if (isHosted(this, screen)) {
      _lifecycle?.hookContext = null;
      final built = super.build();
      return _lifecycle?.wrap(built) ?? built;
    }
    // Shown outside a route: provide our own Blocs above the screen and wrap
    // lifecycle inside that Bloc scope so lifecycle hooks can also `read<B>()`.
    return hostScreen(
      screen,
      // This element owns the widget; calling its build mirrors
      // StatelessElement while exposing provided Blocs to build & lifecycle.
      wrap: (_) => Builder(
        builder: (innerContext) {
          _lifecycle?.hookContext = innerContext;
          // ignore: invalid_use_of_protected_member
          final built = screen.build(innerContext);
          return _lifecycle?.wrap(built) ?? built;
        },
      ),
    );
  }
}
