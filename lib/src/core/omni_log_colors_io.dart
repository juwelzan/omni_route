import 'dart:io';

/// Whether the console shows ANSI colours: enabled on desktop/Android/terminals
/// unless `NO_COLOR` is set, and off on iOS (`os_log` escapes ESC into `\^[`).
/// Internal.
bool consoleSupportsColors() {
  try {
    final env = Platform.environment;
    if (env.containsKey('NO_COLOR')) return false;
    final force = env['FORCE_COLOR'];
    if (force != null && force.isNotEmpty && force != '0') return true;
    if (env['FLUTTER_TEST'] == 'true') {
      return stdout.hasTerminal && stdout.supportsAnsiEscapes;
    }
    if (Platform.isAndroid || Platform.isMacOS || Platform.isLinux) return true;
    if (Platform.isIOS) return false;
    return stdout.hasTerminal && stdout.supportsAnsiEscapes;
  } catch (_) {
    return false;
  }
}
