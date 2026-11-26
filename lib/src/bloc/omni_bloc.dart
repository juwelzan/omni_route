import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../errors/omni_route_exception.dart';

/// Any Bloc or Cubit OmniRoute can create, provide and close.
typedef OmniAnyBloc = BlocBase<Object?>;

/// Any Bloc (Cubits excluded). OmniRoute now accepts Cubits too; use
/// [OmniAnyBloc].
@Deprecated('Use OmniAnyBloc (also accepts Cubits). Removed in 1.0.0.')
typedef AnyBloc = Bloc<Object?, Object?>;

/// Factory that creates a Bloc or Cubit. Use [BuildContext] to read dependencies,
/// e.g. `(ctx) => AuthBloc(ctx.read<AuthRepository>())`.
typedef OmniBlocCreate<B extends OmniAnyBloc> =
    B Function(BuildContext context);

/// Registers how to create [B]. Registered once in `OmniApp(blocs: [...])`.
///
/// `global: true` creates one instance for the whole app; otherwise the
/// factory is used by screens that declare `Provide<B>()`.
@immutable
class OmniBloc<B extends OmniAnyBloc> {
  /// Registers [create] as the factory for [B].
  const OmniBloc(this.create, {this.global = false, this.lazy = true});

  /// Creates a new [B]. Called once per owning scope.
  final OmniBlocCreate<B> create;

  /// Whether one app-wide instance is created above the router.
  final bool global;

  /// Whether creation waits until the Bloc is first read.
  final bool lazy;

  /// The Bloc type this entry creates.
  Type get type => B;

  BlocProvider<B> _provider(Widget? child) =>
      BlocProvider<B>(create: create, lazy: lazy, child: child);
}

/// Immutable lookup of [OmniBloc] factories by Bloc type.
@immutable
class OmniBlocRegistry {
  /// Indexes [blocs] by type.
  ///
  /// Throws [OmniRouteException] if a type is registered twice.
  factory OmniBlocRegistry(Iterable<OmniBloc> blocs) {
    final map = <Type, OmniBloc>{};
    for (final b in blocs) {
      if (map.containsKey(b.type)) {
        throw OmniRouteException(
          OmniErrorCode.duplicateBlocRegistration,
          '${b.type} is registered more than once.',
        );
      }
      map[b.type] = b;
    }
    return OmniBlocRegistry._(Map.unmodifiable(map));
  }

  const OmniBlocRegistry._(this._factories);

  /// A registry with no factories.
  static const empty = OmniBlocRegistry._({});

  final Map<Type, OmniBloc> _factories;

  /// The entries marked `global: true`.
  Iterable<OmniBloc> get globals => _factories.values.where((b) => b.global);

  /// The factory for [B].
  ///
  /// Throws [OmniRouteException] if [B] is missing or global.
  OmniBloc<B> factoryFor<B extends OmniAnyBloc>() {
    final f = _factories[B];
    if (f == null) {
      throw OmniRouteException(
        OmniErrorCode.missingBlocFactory,
        'No factory registered for $B.',
        hint: 'Add `OmniBloc<$B>((ctx) => $B(...))` to OmniApp(blocs: [...]).',
      );
    }
    if (f.global) {
      throw OmniRouteException(
        OmniErrorCode.unsupportedConfiguration,
        '$B is global; a screen must not provide it again.',
        hint: 'Remove Provide<$B>() and use context.read<$B>().',
      );
    }
    return f as OmniBloc<B>;
  }

  /// Providers for all global Blocs, created once for the app.
  @internal
  List<BlocProvider> globalProviders() => [
    for (final b in globals) b._provider(null),
  ];
}

/// Declares a Bloc a screen needs. Owned Blocs are closed when the screen's
/// route is removed; [Provide.value] Blocs are never closed by OmniRoute.
///
/// ```dart
/// @override
/// List<Provide> get provide => const [Provide<StudentBloc>()];
/// ```
@immutable
class Provide<B extends OmniAnyBloc> {
  /// Created from the registered [OmniBloc] factory. Owned by the screen.
  const Provide({this.lazy = true}) : _create = null, _value = null;

  /// Created by a screen-specific factory, e.g. one that needs a route
  /// parameter. Owned by the screen.
  const Provide.create(OmniBlocCreate<B> create, {this.lazy = true})
    : _create = create,
      _value = null;

  /// An existing instance. Owned by whoever created it; never closed here.
  const Provide.value(B value) : _value = value, _create = null, lazy = true;

  final OmniBlocCreate<B>? _create;
  final B? _value;

  /// Whether creation waits until the Bloc is first read.
  final bool lazy;

  /// The Bloc type provided.
  Type get type => B;

  /// Whether OmniRoute closes this Bloc (false for [Provide.value]).
  bool get isOwned => _value == null;

  /// Creates an instance of [B] for group/route scopes using [context].
  @internal
  B instantiate(BuildContext context, OmniBlocRegistry registry) =>
      _value ?? (_create ?? registry.factoryFor<B>().create)(context);

  /// Exposes an already-created [bloc] without closing it when unmounted.
  @internal
  BlocProvider<B> valueProvider(OmniAnyBloc bloc, {Widget? child}) =>
      BlocProvider<B>.value(value: bloc as B, child: child);

  /// Builds the flutter_bloc provider for this entry.
  @internal
  BlocProvider<B> toProvider(OmniBlocRegistry registry) {
    final value = _value;
    if (value != null) return BlocProvider<B>.value(value: value);
    return BlocProvider<B>(
      create: _create ?? registry.factoryFor<B>().create,
      lazy: lazy,
    );
  }
}
