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

/// Base entry accepted by `OmniApp(blocs:)`, `OmniPage(blocs:/provide:)`,
/// `OmniRouteGroup(provide:)`, and `OmniShell(provide:)`.
///
/// Being non-generic lets Dart infer exact Bloc types automatically in list
/// literals such as `[OmniBloc((_) => MyBloc())]` without repeating `<MyBloc>`.
abstract class OmniBlocEntry {
  /// Const constructor for subclasses.
  const OmniBlocEntry();

  /// The concrete Bloc or Cubit [Type] managed by this entry.
  Type get type;

  /// Whether creation waits until the Bloc is first read.
  bool get lazy;

  /// Whether OmniRoute owns and closes this Bloc when leaving its scope.
  bool get isOwned;

  /// Whether this entry embeds its own inline factory or existing instance.
  @internal
  bool get hasInlineSource;

  /// Creates the underlying Bloc instance using [context] and [registry].
  @internal
  OmniAnyBloc instantiate(BuildContext context, OmniBlocRegistry registry);

  /// Wraps [child] with an already instantiated [bloc] without closing it.
  @internal
  BlocProvider<OmniAnyBloc> valueProvider(OmniAnyBloc bloc, {Widget? child});

  /// Converts this entry into a [BlocProvider] using [registry] if needed.
  @internal
  BlocProvider<OmniAnyBloc> toProvider(OmniBlocRegistry registry);
}

/// Registers how to create [B].
///
/// Pass inside `OmniApp(blocs: [...])` for global/shared Blocs (`global: true`
/// lives for the whole app), or declare directly on `OmniPage(blocs: [...])` /
/// screen `provide` (`Provide.bloc((_) => ...)` or `OmniBloc.forPage((_) => ...)`)
/// so the BlocProvider registers automatically when entering that page.
@immutable
class OmniBloc<B extends OmniAnyBloc> extends Provide<B> {
  /// Registers [create] as the factory for [B].
  const OmniBloc(this.create, {this.global = false, super.lazy = true})
    : super.create(create);

  /// Registers [create] as an eager factory (`lazy: false`), instantiating [B]
  /// immediately upon entering the page or starting the app.
  const OmniBloc.eager(this.create, {this.global = false})
    : super.create(create, lazy: false);

  /// Declares a page-scoped [OmniBloc] inside a `List<Provide>` getter with
  /// automatic type inference (`OmniBloc.forPage((_) => MyBloc())`).
  static OmniBloc<OmniAnyBloc> forPage<B extends OmniAnyBloc>(
    OmniBlocCreate<B> create, {
    bool lazy = true,
  }) => OmniBloc<B>(create, lazy: lazy);

  /// Creates a new [B]. Called once per owning scope.
  final OmniBlocCreate<B> create;

  /// Whether one app-wide instance is created above the router.
  final bool global;

  BlocProvider<B> _provider(Widget? child) =>
      BlocProvider<B>(create: create, lazy: lazy, child: child);
}

/// Lookup of [OmniBloc] factories by Bloc type.
///
/// Starts with factories declared in `OmniApp(blocs: [...])` and also
/// registers page-scoped [OmniBloc] factories dynamically when pages are first
/// entered.
class OmniBlocRegistry {
  /// Indexes [blocs] by type.
  ///
  /// Throws [OmniRouteException] if a type is registered twice.
  factory OmniBlocRegistry(Iterable<OmniBlocEntry> blocs) {
    final map = <Type, OmniBloc>{};
    for (final entry in blocs) {
      if (entry is! OmniBloc) {
        throw OmniRouteException(
          OmniErrorCode.unsupportedConfiguration,
          'OmniApp(blocs: [...]) only accepts OmniBloc entries (got ${entry.runtimeType}).',
          hint: 'Use OmniBloc((_) => ${entry.type}(...), global: true).',
        );
      }
      _checkInferredBlocType(entry.type);
      if (map.containsKey(entry.type)) {
        throw OmniRouteException(
          OmniErrorCode.duplicateBlocRegistration,
          '${entry.type} is registered more than once.',
        );
      }
      map[entry.type] = entry;
    }
    return OmniBlocRegistry._(map, true);
  }

  const OmniBlocRegistry._(this._factories, this._mutable);

  /// A registry with no factories.
  static const empty = OmniBlocRegistry._({}, false);

  final Map<Type, OmniBloc> _factories;
  final bool _mutable;

  /// Whether a factory for [B] has been registered yet.
  bool isRegistered<B extends OmniAnyBloc>() => _factories.containsKey(B);

  /// Whether a factory for [type] has been registered yet.
  bool contains(Type type) => _factories.containsKey(type);

  /// Whether [type] is registered as a `global: true` Bloc.
  bool isGlobal(Type type) => _factories[type]?.global ?? false;

  /// Registers page/screen-level [OmniBloc] entries on first page entry.
  ///
  /// Throws [OmniRouteException] if a screen attempts to re-provide a
  /// `global: true` Bloc or uses an un-inferred `OmniAnyBloc` type.
  @internal
  void registerPageBlocs(Iterable<OmniBlocEntry> entries) {
    for (final p in entries) {
      _checkInferredBlocType(p.type);
      if (p.isOwned && isGlobal(p.type)) {
        throw OmniRouteException(
          OmniErrorCode.unsupportedConfiguration,
          '${p.type} is global; a screen must not provide it again.',
          hint:
              'Remove Provide<${p.type}>() and use context.read<${p.type}>().',
        );
      }
      if (_mutable && p is OmniBloc && !p.global) {
        _factories.putIfAbsent(p.type, () => p);
      }
    }
  }

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
        hint:
            'Pass `Provide.bloc((_) => $B(...))` in screen `provide` / '
            '`OmniPage(blocs: ...)` or register it in `OmniApp(blocs: [...])`.',
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

  /// Merges updated `OmniApp(blocs: ...)` declarations on Hot Reload without
  /// discarding page-scoped factories registered at runtime.
  @internal
  void mergeEntries(Iterable<OmniBlocEntry> next) {
    if (!_mutable) return;
    final seen = <Type>{};
    for (final entry in next) {
      if (entry is! OmniBloc) {
        throw OmniRouteException(
          OmniErrorCode.unsupportedConfiguration,
          'OmniApp(blocs: [...]) only accepts OmniBloc entries (got ${entry.runtimeType}).',
          hint: 'Use OmniBloc((_) => ${entry.type}(...), global: true).',
        );
      }
      _checkInferredBlocType(entry.type);
      if (!seen.add(entry.type)) {
        throw OmniRouteException(
          OmniErrorCode.duplicateBlocRegistration,
          '${entry.type} is registered more than once.',
        );
      }
      _factories[entry.type] = entry;
    }
  }

  /// Providers for all global Blocs, created once for the app.
  @internal
  List<BlocProvider> globalProviders() => [
    for (final b in globals) b._provider(null),
  ];
}

void _checkInferredBlocType(Type type) {
  if (type == OmniAnyBloc || type == BlocBase || type == Bloc) {
    throw OmniRouteException(
      OmniErrorCode.unsupportedConfiguration,
      'Could not infer concrete Bloc type (inferred as $type) inside List<Provide>.',
      hint:
          'Use `Provide.bloc((_) => MyBloc())`, `OmniBloc<MyBloc>((_) => MyBloc())`, '
          'or put `OmniBloc((_) => MyBloc())` inside `OmniPage(blocs: [...])`.',
    );
  }
}

/// Declares a Bloc a screen needs. Owned Blocs are closed when the screen's
/// route is removed; [Provide.value] Blocs are never closed by OmniRoute.
///
/// Inside a screen's `List<Provide> get provide`, write:
/// ```dart
/// @override
/// List<Provide> get provide => [
///   Provide.bloc((_) => StudentBloc()),       // auto-inferred type, registered on page entry
///   Provide.blocEager((_) => DashboardBloc()),// eager creation on page entry
///   const Provide<SharedBloc>(),              // from OmniApp or previously registered factory
///   Provide.value(existingBloc),              // pre-existing instance, never closed
/// ];
/// ```
@immutable
class Provide<B extends OmniAnyBloc> extends OmniBlocEntry {
  /// Created from the registered [OmniBloc] factory. Owned by the screen.
  const Provide({this.lazy = true}) : _create = null, _value = null;

  /// Created by a screen-specific factory, e.g. one that needs a route
  /// parameter. Owned by the screen.
  const Provide.create(OmniBlocCreate<B> create, {this.lazy = true})
    : _create = create,
      _value = null;

  /// Eagerly creates [B] (`lazy: false`) as soon as the page enters the tree.
  const Provide.eager(OmniBlocCreate<B> create)
    : _create = create,
      _value = null,
      lazy = false;

  /// An existing instance. Owned by whoever created it; never closed here.
  const Provide.value(B value) : _value = value, _create = null, lazy = true;

  /// Concise screen-scoped factory helper that preserves [T] cleanly even
  /// inside `List<Provide>` (`Provide.bloc((_) => MyBloc())`).
  static Provide<OmniAnyBloc> bloc<T extends OmniAnyBloc>(
    OmniBlocCreate<T> create, {
    bool lazy = true,
  }) => OmniBloc<T>(create, lazy: lazy);

  /// Eager variant of [Provide.bloc] (`lazy: false`) for immediate page-entry
  /// instantiation without repeating `<T>`.
  static Provide<OmniAnyBloc> blocEager<T extends OmniAnyBloc>(
    OmniBlocCreate<T> create,
  ) => OmniBloc<T>.eager(create);

  final OmniBlocCreate<B>? _create;
  final B? _value;

  @override
  final bool lazy;

  @override
  Type get type => B;

  @override
  bool get isOwned => _value == null;

  @override
  @internal
  bool get hasInlineSource => _value != null || _create != null;

  @override
  @internal
  OmniAnyBloc instantiate(BuildContext context, OmniBlocRegistry registry) =>
      _value ?? (_create ?? registry.factoryFor<B>().create)(context);

  @override
  @internal
  BlocProvider<B> valueProvider(OmniAnyBloc bloc, {Widget? child}) =>
      BlocProvider<B>.value(value: bloc as B, child: child);

  @override
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

/// Base entry accepted by `OmniApp(repositories: [...])`.
///
/// Being non-generic lets Dart infer each service or repository type cleanly
/// from `[OmniRepo((_) => AuthRepository()), ...]`.
abstract class OmniRepoEntry {
  /// Const constructor for subclasses.
  const OmniRepoEntry();

  /// Provided service or repository [Type].
  Type get type;

  /// Converts this entry into a [RepositoryProvider] for `MultiRepositoryProvider`.
  @internal
  RepositoryProvider<dynamic> toProvider();
}

/// Declares an app-wide repository or service instance registered inside
/// `OmniApp(repositories: [...])` above all global Blocs.
@immutable
class OmniRepo<T> extends OmniRepoEntry {
  /// Registers a repository factory invoked lazily (or eagerly when `lazy: false`).
  const OmniRepo(
    T Function(BuildContext context) this._create, {
    this.lazy = true,
    this.dispose,
  }) : _value = null;

  /// Provides an existing [value] without calling [dispose] on unmount.
  const OmniRepo.value(T value)
    : _value = value,
      _create = null,
      lazy = true,
      dispose = null;

  final T Function(BuildContext context)? _create;
  final T? _value;

  /// Whether creation waits until `context.read<T>()` is first invoked.
  final bool lazy;

  /// Optional cleanup invoked when `OmniApp` unmounts.
  final void Function(T instance)? dispose;

  @override
  Type get type => T;

  @override
  @internal
  RepositoryProvider<T> toProvider() {
    if (_create == null) {
      return RepositoryProvider<T>.value(value: _value as T);
    }
    return RepositoryProvider<T>(create: _create, lazy: lazy, dispose: dispose);
  }
}
