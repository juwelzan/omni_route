/// OmniRoute: fast Trie routing, Bloc scoping, guards, onboarding & auth
/// flows with local persistence, and native OS utilities across Android,
/// iOS, Web, macOS, Windows, and Linux.
///
/// Also re-exports `flutter_bloc`, `shared_preferences` and `omni_responsive`
/// (themes, responsive layout, fields, localization — built into `OmniApp`).
///
/// Networking is a separate package: add `omni_network` (and optionally
/// `omni_network_flutter` for the inspector and secure token storage) to
/// your `pubspec.yaml` only when you need it.
library;

// ── State Management, Persistence & Responsive UI ───────────────────────────
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:omni_responsive/omni_responsive.dart';
export 'package:shared_preferences/shared_preferences.dart';

// ── Routing, Blocs, Flows & Local Persistence ───────────────────────────────
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
export 'src/core/omni_app_config.dart';
export 'src/core/omni_app_features.dart'
    show OmniInitErrorBuilder, OmniInitialRouteResolver;
export 'src/core/omni_breadcrumbs.dart' show OmniBreadcrumb;
export 'src/core/omni_onboarding_store.dart' show OmniLocalStore;
export 'src/core/omni_route.dart';
export 'src/core/omni_route_entry.dart'
    show OmniNavigation, OmniNavigationKind, OmniRouteEntry;
export 'src/core/omni_router.dart' show OmniRouter;
export 'src/errors/omni_route_exception.dart';
export 'src/guards/omni_guard.dart' show OmniGuard, OmniGuardRedirect;

// ── Native Platform Utilities ───────────────────────────────────────────────
export 'src/platform/omni_device_info.dart';
export 'src/platform/omni_native.dart';
export 'src/platform/omni_route_method_channel.dart'
    show MethodChannelOmniRoute;
export 'src/platform/omni_route_platform_interface.dart' show OmniRoutePlatform;

// ── Pages, Shells, Transitions & Screens ────────────────────────────────────
export 'src/routing/omni_bottom_bar_host.dart'
    show
        OmniBottomNavigationBarBuilder,
        OmniPageBarTransition,
        OmniPageBottomBarHost;
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

// ── Route-aware widgets ─────────────────────────────────────────────────────
export 'src/routing/omni_route_widgets.dart'
    show OmniBreadcrumbBar, OmniPrefetch;
