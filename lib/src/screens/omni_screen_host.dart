import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../bloc/omni_bloc_scope.dart';
import '../errors/omni_route_exception.dart';
import 'omni_screen.dart';

/// Shows [screen] with the Blocs from its `provide` list.
///
/// Routes do this for you. Use it when a screen is shown **outside** a
/// route — embedded in a layout, a master–detail pane or a dialog:
///
/// ```dart
/// Row(children: [
///   const Expanded(child: StudentScreen()),               // stateless: automatic
///   Expanded(child: OmniScreenHost(screen: DashboardScreen())), // stateful: wrap
/// ])
/// ```
///
/// Stateless screens host themselves when needed; stateful screens must be
/// wrapped, because a `State` always reads from its own (outer) context.
/// The Blocs follow the host's lifecycle: created once, closed when the host
/// is removed.
class OmniScreenHost extends StatelessWidget {
  /// Hosts [screen].
  const OmniScreenHost({super.key, required this.screen});

  /// The screen to show.
  final OmniScreen screen;

  @override
  Widget build(BuildContext context) => hostScreen(screen);
}

/// Wraps [screen] in its Bloc scope; [wrap] decorates the screen inside the
/// scope (used by routes to add the title).
@internal
Widget hostScreen(OmniScreen screen, {Widget Function(Widget)? wrap}) {
  final inner = wrap == null ? screen as Widget : wrap(screen);
  if (screen.provide.isEmpty) return inner;
  return OmniBlocScope.forScreen(
    screen: screen,
    provide: screen.provide,
    child: inner,
  );
}

/// Whether [screen], about to mount under [context], has its Blocs above it.
@internal
bool isHosted(BuildContext? context, OmniScreen screen) =>
    screen.provide.isEmpty || identical(hostedScreenAbove(context), screen);

/// Error reported for a stateful screen shown without its Blocs.
@internal
OmniRouteException notHostedError(OmniScreen screen) => OmniRouteException(
  OmniErrorCode.screenNotHosted,
  '${screen.debugName} declares Blocs in `provide` but is shown outside a '
  'route, so they were not created.',
  hint:
      'Wrap it: ${screen.debugName}(...).hosted() or OmniScreenHost(screen: ...), '
      'or show it through an OmniPage.',
);
