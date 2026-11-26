import '../bloc/omni_bloc.dart';
import '../guards/omni_guard.dart';
import 'omni_page.dart';
import 'omni_route_state.dart';

/// Returns the identity of a group's scope for the current location; when
/// it changes, the group's Blocs are closed and recreated.
typedef OmniScopeKey = Object? Function(OmniRouteState state);

/// Routes that share Blocs without introducing a nested `Navigator`.
///
/// The Blocs in [provide] are created when entering any route inside [routes]
/// and remain alive while moving between routes in the group or pushing
/// outside routes on top of them. Once the last page belonging to this
/// `(group, scopeKey)` leaves the stack, owned Blocs are closed cleanly.
///
/// ```dart
/// OmniPage('/students', (_) => const StudentListScreen(), routes: [
///   OmniRouteGroup(
///     scopeKey: (s) => s.pathParameters['id'],
///     provide: [
///       Provide<StudentBloc>.create(
///         (c) => StudentBloc(OmniParams.of(c).pathInt('id')),
///       ),
///     ],
///     routes: [
///       OmniPage(':id', (p) => const StudentDetailScreen()),
///       OmniPage(':id/edit', (p) => const StudentEditScreen()),
///     ],
///   ),
/// ])
/// ```
class OmniRouteGroup extends OmniRouteBase {
  /// Creates a group of [routes] sharing the Blocs in [provide].
  const OmniRouteGroup({
    required this.routes,
    required this.provide,
    this.scopeKey,
    this.guards = const [],
    this.transition,
  });

  /// Routes inside this shared Bloc scope.
  final List<OmniRouteBase> routes;

  /// Blocs created for this group and closed when leaving it.
  final List<OmniBlocEntry> provide;

  /// Computes a scope identity from the active route state (for example
  /// `(s) => s.pathParameters['id']`). Changing identity closes old Blocs
  /// and instantiates new ones.
  final OmniScopeKey? scopeKey;

  /// Guards applied to every route inside this group.
  final List<OmniGuard> guards;

  /// Default page transition for routes inside this group.
  final OmniPageType? transition;

  @override
  List<OmniRouteBase> get childRoutes => routes;
}
