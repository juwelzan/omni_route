/// Low-level hooks for frameworks that host `omni_responsive` inside their
/// own app widget (used by `omni_route`'s `OmniApp`). Apps normally import
/// `package:omni_responsive/omni_responsive.dart` instead.
library;

export 'src/omni_responsive_scope.dart' show OmniResponsiveTextScaleHost;
export 'src/omni_system_ui.dart'
    show composeOmniSystemUiOverlayStyle, resolveEffectiveOmniScreenMode;
export 'src/omni_ui_host.dart' show OmniUiHost;
export 'src/widgets/bottom_navigation/omni_bottom_navigation.dart'
    show OmniRouteNavigationBridge;
