import 'dart:io';

/// Whether log lines can carry ANSI colours. Internal.
///
/// * `NO_COLOR` env var disables colours; `FORCE_COLOR` enables them.
/// * Android: yes. Logcat keeps the codes, and `flutter run` and IDEs show
///   them as colours.
/// * iOS: no by default. Its system log turns the escape character into `\^[`
///   text unless explicitly forced via `LogOptions(colors: true)` /
///   `logColors: true`.
/// * Desktop / CLI / IDE Debug Consoles: enabled when stdout is a TTY with
///   ANSI support or when `TERM` is set (and not `dumb`), which also covers
///   `flutter run` child-process pipes in VS Code and IntelliJ.
bool terminalSupportsColors() {
  try {
    final env = Platform.environment;
    if (env.containsKey('NO_COLOR')) return false;
    final force = env['FORCE_COLOR'];
    if (force != null && force.isNotEmpty && force != '0') return true;
    if (Platform.isAndroid) return true;
    if (Platform.isIOS) return false;
    if (stdout.hasTerminal) return stdout.supportsAnsiEscapes;
    final term = env['TERM'];
    return term != null && term.isNotEmpty && term != 'dumb';
  } catch (_) {
    return false;
  }
}
