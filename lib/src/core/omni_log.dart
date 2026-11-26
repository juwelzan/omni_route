import 'package:logger/logger.dart';
import 'package:meta/meta.dart';

import '../screens/omni_screen.dart';
import 'omni_log_colors_stub.dart'
    if (dart.library.io) 'omni_log_colors_io.dart';
import 'omni_route_entry.dart';

/// OmniRoute's default logger: debug builds only, one framed block per
/// event with level emoji, time and time since start, no stack trace.
///
/// ```text
/// ┌───────────────────────────────────────────────────────────────────────
/// │ 10:42:07.311 (+0:00:05.402070)
/// ├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
/// │ 💡 OmniRoute · navigation
/// │ 💡 from  /settings          SettingsScreen
/// │ 💡 to    /settings/profile  ProfileScreen
/// └───────────────────────────────────────────────────────────────────────
/// ```
@internal
Logger defaultOmniLogger({LogOutput? output}) => Logger(
  filter: DevelopmentFilter(), // nothing is logged in release builds
  printer: PrettyPrinter(
    methodCount: 0, // no stack trace for normal events
    errorMethodCount: 6, // short trace for errors
    lineLength: 72,
    // Colours only where they render; phone/simulator logs would show the
    // raw escape codes.
    colors: consoleSupportsColors(),
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  output: output,
);

/// The log text for one navigation: where from, where to, which screen.
@internal
String navigationMessage(OmniNavigation n) {
  final from = n.from;
  final to = n.to;
  final rows = <(String, String, String)>[
    ('from', from?.location ?? '(app start)', _screen(from)),
    ('to', to.location, _screen(to)),
  ];
  if (n.uri.hasQuery || n.uri.hasFragment) {
    rows.add(('uri', n.uri.toString(), ''));
  }
  final width = rows.map((r) => r.$2.length).reduce((a, b) => a > b ? a : b);
  return [
    'OmniRoute · navigation',
    for (final (label, location, screen) in rows)
      '${label.padRight(4)}  ${location.padRight(width)}  $screen'.trimRight(),
  ].join('\n');
}

// The screen class, or the route name / canonical routePath when the route
// was declared without a specific screen type (`OmniPage<OmniScreen>`).
String _screen(OmniRouteEntry? e) {
  if (e == null) return '';
  final screen = e.screen;
  if (screen != null && screen != OmniScreen) return '$screen';
  return e.name ?? e.routePath ?? '';
}
