/// OmniRoute: high-performance native Flutter router, screens, transitions,
/// and Bloc scoping.
///
/// Call [OmniRoute.usePathUrls] in `main()` before `runApp` if you want clean
/// URLs on the web.
library;

export 'src/bloc/omni_bloc.dart'
    show
        AnyBloc,
        OmniAnyBloc,
        OmniBloc,
        OmniBlocCreate,
        OmniBlocEntry,
        OmniBlocRegistry,
        OmniRepo,
        OmniRepoEntry,
        Provide;
export 'src/bloc/omni_bloc_scope.dart' hide hostedScreenAbove;
export 'src/core/omni_app.dart';
export 'src/core/omni_app_features.dart'
    show OmniInitErrorBuilder, OmniInitialRouteResolver;
export 'src/core/omni_route.dart';
export 'src/core/omni_route_entry.dart'
    show OmniNavigation, OmniNavigationKind, OmniRouteEntry;
export 'src/core/omni_router.dart' show OmniRouter;
export 'src/errors/omni_route_exception.dart';
export 'src/guards/omni_guard.dart' show OmniGuard, OmniGuardRedirect;
export 'src/routing/omni_page.dart'
    show
        OmniErrorBuilder,
        OmniNoTransitionPage,
        OmniPage,
        OmniPageExit,
        OmniPageType,
        OmniPages,
        OmniScreenBuilder,
        OmniTransition,
        OmniTransitionBuilder,
        defaultOmniErrorBuilder;
export 'src/routing/omni_params.dart' show OmniParams;
export 'src/routing/omni_route_group.dart';
export 'src/routing/omni_route_state.dart' show OmniRouteBase, OmniRouteState;
export 'src/routing/omni_shell.dart';
export 'src/routing/omni_swipe_back.dart'
    show OmniSwipeBack, OmniSwipeBackPage, OmniSwipeBackStyle, OmniSwipeEdge;
export 'src/screens/omni_lifecycle.dart' show OmniLifecycle;
export 'src/screens/omni_screen.dart' show OmniScreen, OmniScreenMetadata;
export 'src/screens/omni_screen_host.dart' show OmniScreenHost;
export 'src/screens/omni_stateful_widget.dart';
export 'src/screens/omni_stateless_widget.dart';
