/// OmniRoute: all-in-one Flutter plugin providing fast Trie routing, Bloc
/// scoping, onboarding & auth flows with auto local persistence, networking
/// (HTTP/WebSocket/SSE/AI), in-app inspector UI, secure storage, and native OS
/// utilities across Android, iOS, Web, macOS, Windows, and Linux.
///
/// Just depend on `omni_route` and import `package:omni_route/omni_route.dart`
/// — no separate `flutter_bloc`, `omni_network`, `omni_network_flutter`, or
/// storage packages required in your app's `pubspec.yaml`.
library;

// ── State Management (flutter_bloc) ─────────────────────────────────────────
export 'package:flutter_bloc/flutter_bloc.dart';
export 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Core Networking & Flutter Network Tools ─────────────────────────────────
export 'package:omni_network/omni_network.dart';
export 'package:omni_network_flutter/omni_network_flutter.dart';
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

// ── Responsive Engine ───────────────────────────────────────────────────────
export 'src/responsive/omni_adaptive_extras.dart'
    show OmniBreadcrumbBar, OmniPrefetch, OmniResponsiveSliverGrid;
export 'src/responsive/omni_adaptive_shell.dart'
    show OmniAdaptiveDestination, OmniAdaptiveShellScaffold;
export 'src/responsive/omni_responsive_config.dart'
    show
        OmniDeviceType,
        OmniResponsiveConfig,
        OmniResponsiveTokenSet,
        OmniResponsiveTokens,
        OmniWindowSize;
export 'src/responsive/omni_responsive_extensions.dart';
export 'src/responsive/omni_responsive_scope.dart'
    show OmniResponsiveData, OmniResponsiveScope;
export 'src/responsive/omni_responsive_widgets.dart'
    show
        OmniGap,
        OmniResponsiveBuilder,
        OmniResponsiveColumns,
        OmniResponsiveContainer,
        OmniResponsiveGrid,
        OmniResponsiveLayout,
        OmniResponsivePadding,
        OmniResponsiveRowColumn,
        OmniResponsiveVisibility,
        OmniResponsiveWidgetBuilder;
export 'src/responsive/omni_split_view.dart'
    show
        OmniDetailBuilder,
        OmniFoldableSplit,
        OmniMasterBuilder,
        OmniMasterDetail,
        OmniMasterDetailController;
export 'src/responsive/omni_colors.dart'
    show OmniColorPalette, OmniColors, OmniColorsContext;
export 'src/responsive/omni_status_bar.dart' show OmniStatusBarStyle;
export 'src/responsive/omni_styles.dart'
    show
        OmniInputVariant,
        OmniStyles,
        OmniStylesContext,
        OmniTextStyles,
        OmniThemeStyle,
        OmniUiTheme;
export 'src/responsive/omni_system_navigation_bar.dart'
    show OmniSystemNavigationBarStyle;
export 'src/responsive/omni_system_ui.dart'
    show
        OmniFullscreenButton,
        OmniOrientation,
        OmniScreenMode,
        OmniSystemUi,
        OmniSystemUiContext,
        OmniSystemUiController,
        OmniSystemUiScope;
export 'src/responsive/omni_theme.dart'
    show
        OmniResponsiveThemeHost,
        OmniTheme,
        OmniThemeAnimationPicker,
        OmniThemeButton,
        OmniThemeContext,
        OmniThemeController,
        OmniThemeCustomizer,
        OmniThemeModeButton,
        OmniThemeModeSwitch,
        OmniThemePanel,
        OmniThemePicker,
        OmniThemePickerLayout,
        OmniThemeScope,
        OmniThemeSelection,
        OmniThemeSettingsTile,
        OmniThemeStylePicker,
        showOmniThemeSheet;
export 'src/responsive/omni_theme_transition.dart'
    show OmniThemeAnimation, OmniThemeAnimationMode, OmniThemeTransition;
export 'src/responsive/omni_fields.dart'
    show
        OmniCountryDialCode,
        OmniEmailField,
        OmniFieldIdentity,
        OmniFieldLabelMode,
        OmniFieldStyle,
        OmniFieldTheme,
        OmniFieldThemeScope,
        OmniMultilineField,
        OmniNameField,
        OmniNumberField,
        OmniOtpAnimationType,
        OmniOtpBoxStyle,
        OmniOtpErrorAnimation,
        OmniOtpField,
        OmniOtpStatus,
        OmniOtpVerifiedAnimation,
        OmniOtpWarningAnimation,
        OmniPasswordField,
        OmniPhoneField,
        OmniPinTheme,
        OmniSearchField,
        OmniTextField,
        OmniUrlField,
        OmniValidators;
export 'src/responsive/omni_localization.dart'
    show
        OmniCountryCode,
        OmniFallbackCupertinoLocalizationsDelegate,
        OmniFallbackMaterialLocalizationsDelegate,
        OmniFallbackWidgetsLocalizationsDelegate,
        OmniL10nScope,
        OmniLang,
        OmniLanguage,
        OmniLanguageButton,
        OmniLanguagePicker,
        OmniLanguagePickerLayout,
        OmniLanguageTile,
        OmniLocaleController,
        OmniLocaleState,
        OmniLocalization,
        OmniLocalizationHost,
        OmniText,
        OmniTextContext,
        showOmniLanguageSheet;
