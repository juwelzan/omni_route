import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../errors/omni_route_exception.dart';
import 'omni_bloc.dart';

/// Makes [registry] and its global Blocs available below. `OmniApp` inserts
/// this once above the router; it is public for tests and custom setups.
class OmniGlobalBlocScope extends StatelessWidget {
  /// Provides [registry] and its global Blocs to [child].
  const OmniGlobalBlocScope({
    super.key,
    required this.registry,
    required this.child,
  });

  /// Factories for all Blocs of the app.
  final OmniBlocRegistry registry;

  /// The widget below this scope.
  final Widget child;

  /// The nearest registry, or [OmniBlocRegistry.empty].
  static OmniBlocRegistry registryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RegistryScope>()?.registry ??
      OmniBlocRegistry.empty;

  @override
  Widget build(BuildContext context) {
    final providers = registry.globalProviders();
    final inner = providers.isEmpty
        ? child
        : MultiBlocProvider(providers: providers, child: child);
    return _RegistryScope(registry: registry, child: inner);
  }
}

class _RegistryScope extends InheritedWidget {
  const _RegistryScope({required this.registry, required super.child});
  final OmniBlocRegistry registry;
  @override
  bool updateShouldNotify(_RegistryScope old) => old.registry != registry;
}

/// Provides a screen's [provide] list above [child]. Used by OmniRoute's
/// page builder so Blocs exist before the screen's own `build`/`initState`.
///
/// Blocs are created once per element: rebuilds do not recreate them, and
/// owned Blocs are closed by flutter_bloc when this widget is unmounted.
class OmniBlocScope extends StatelessWidget {
  /// Provides the Blocs in [provide] to [child].
  const OmniBlocScope({super.key, required this.provide, required this.child})
    : _screen = null;

  /// Scope for [screen], shown as or inside [child]. Marks the screen as
  /// hosted so it does not create its Blocs a second time.
  @internal
  const OmniBlocScope.forScreen({
    super.key,
    required Widget this._screen,
    required this.provide,
    required this.child,
  });

  final Widget? _screen;

  /// The Blocs to provide; each type at most once.
  final List<OmniBlocEntry> provide;

  /// The widget below this scope.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (provide.isEmpty) return child;
    final seen = <Type>{};
    for (final p in provide) {
      if (!seen.add(p.type)) {
        throw OmniRouteException(
          OmniErrorCode.duplicateBlocRegistration,
          '${p.type} appears twice in one provide list.',
        );
      }
    }
    final registry = OmniGlobalBlocScope.registryOf(context);
    registry.registerPageBlocs(provide);
    // A screen wrapped directly (or via forScreen) counts as hosted.
    final screen = _screen ?? child;
    return MultiBlocProvider(
      providers: [for (final p in provide) p.toProvider(registry)],
      child: _HostMarker(screen: screen, child: child),
    );
  }
}

class _HostMarker extends InheritedWidget {
  const _HostMarker({required this.screen, required super.child});
  final Widget screen;
  @override
  bool updateShouldNotify(_HostMarker old) => false;
}

/// The screen widget whose Blocs the nearest scope above [context] provides.
@internal
Widget? hostedScreenAbove(BuildContext? context) =>
    context?.getInheritedWidgetOfExactType<_HostMarker>()?.screen;
