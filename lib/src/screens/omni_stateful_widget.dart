import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../errors/omni_route_exception.dart';
import '../routing/omni_route_state.dart';

import 'omni_lifecycle.dart';
import 'omni_screen.dart';
import 'omni_screen_host.dart';

/// A [StatefulWidget] screen with OmniRoute metadata. Pair with [OmniState].
abstract class OmniStatefulWidget extends StatefulWidget with OmniScreen {
  /// Creates a stateful screen.
  const OmniStatefulWidget({super.key});

  @override
  State<OmniStatefulWidget> createState();

  @override
  StatefulElement createElement() => _OmniStatefulElement(this);
}

class _OmniStatefulElement extends StatefulElement {
  _OmniStatefulElement(OmniStatefulWidget super.widget);

  // Widget types already reported for OmniLifecycle-on-the-widget, so the
  // mistake is reported once per type, not on every rebuild or page.
  static final Set<Type> _reportedLifecycleOnWidget = {};

  // Only States that mix in OmniLifecycle get a hub (no cost otherwise).
  OmniLifecycleHub? _lifecycle;

  @override
  void unmount() {
    _lifecycle?.dispose();
    _lifecycle = null;
    super.unmount();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    // Reported (not thrown) before initState runs, so the cause is shown
    // first and the element still mounts and disposes normally.
    final screen = widget as OmniStatefulWidget;
    if (!isHosted(parent, screen)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: notHostedError(screen),
          library: 'omni_route',
        ),
      );
    }
    if (kDebugMode &&
        screen is OmniLifecycle &&
        state is! OmniLifecycle &&
        _reportedLifecycleOnWidget.add(screen.runtimeType)) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: OmniRouteException(
            OmniErrorCode.lifecycleOnWidget,
            '${screen.runtimeType} mixes in OmniLifecycle, but hooks on a '
            'stateful screen run on its State, so they would never be called.',
            hint:
                'Mix OmniLifecycle into your OmniState instead: '
                'class _${screen.runtimeType}State extends '
                'OmniState<${screen.runtimeType}> with OmniLifecycle.',
          ),
          library: 'omni_route',
        ),
      );
    }
    if (state is OmniLifecycle) {
      _lifecycle = OmniLifecycleHub(
        this,
        () => state is OmniLifecycle ? state as OmniLifecycle : null,
      );
    }
    super.mount(parent, newSlot);
  }

  @override
  Widget build() {
    validateScreen(widget as OmniScreen);
    final built = super.build();
    return _lifecycle?.wrap(built) ?? built;
  }
}

/// [State] for an [OmniStatefulWidget]. Adds no lifecycle of its own:
/// `initState`, `didChangeDependencies`, `didUpdateWidget` and `dispose`
/// behave exactly as in Flutter.
abstract class OmniState<T extends OmniStatefulWidget> extends State<T> {
  /// Metadata of the current widget.
  OmniScreenMetadata get metadata => widget.metadata;

  /// Route state of the page this screen is on (path, query, extra).
  OmniRouteState get routeState => OmniRouteState.of(context);
}
