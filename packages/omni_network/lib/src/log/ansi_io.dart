import 'dart:io';

/// Whether log lines can carry ANSI colours. Internal.
///
/// * `NO_COLOR` env var disables colours; `FORCE_COLOR` enables them.
/// * Android, macOS, and Linux: enabled automatically (covering `flutter run`
///   pipes, VS Code, IntelliJ/Android Studio Debug Consoles, and terminals).
/// * iOS: off by default (`os_log` converts ESC into `\^[`), unless `FORCE_COLOR`
///   is set or `LogOptions(colors: true)` / `logColors: true` is passed.
/// * Windows / other hosts: enabled when stdout is an ANSI terminal or running
///   under modern terminal / IDE environments (`TERM`, `WT_SESSION`, etc.).
bool terminalSupportsColors() {
  try {
    final env = Platform.environment;
    if (env.containsKey('NO_COLOR')) return false;
    final force = env['FORCE_COLOR'];
    if (force != null && force.isNotEmpty && force != '0') return true;
    // In `flutter test` headless pipes keep auto-color matched to the actual TTY
    // unless `FORCE_COLOR` or `LogOptions(colors: true)` is requested.
    if (env['FLUTTER_TEST'] == 'true') {
      return stdout.hasTerminal && stdout.supportsAnsiEscapes;
    }
    if (Platform.isAndroid || Platform.isMacOS || Platform.isLinux) return true;
    if (Platform.isIOS) return false;
    if (stdout.hasTerminal && stdout.supportsAnsiEscapes) return true;
    final term = env['TERM'];
    if (term != null && term.isNotEmpty && term != 'dumb') return true;
    return env.containsKey('WT_SESSION') ||
        env.containsKey('TERM_PROGRAM') ||
        env.containsKey('VSCODE_PID');
  } catch (_) {
    return false;
  }
}
