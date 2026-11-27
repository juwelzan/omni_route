import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One shared, cached `SharedPreferences` load for every saved setting
/// (theme, language, text size).
///
/// Call [preload] before `runApp` and every setting is restored
/// synchronously while the first frame builds, so the app never shows a
/// frame in the default theme or language:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await OmniPreferences.preload();
///   runApp(const MyApp());
/// }
/// ```
///
/// Without [preload] the app host holds the first frame until the settings
/// are read (at most [startupWait]), so there is still no visible flash.
abstract final class OmniPreferences {
  static SharedPreferences? _instance;
  static Future<SharedPreferences>? _loading;

  /// Longest time the first frame is held while settings load.
  static const Duration startupWait = Duration(milliseconds: 120);

  /// The loaded instance, or `null` before the first load completed.
  static SharedPreferences? get cached => _instance;

  /// Loads (once) and returns the shared instance.
  static Future<SharedPreferences> load() {
    final instance = _instance;
    if (instance != null) return SynchronousFuture(instance);
    return _loading ??= SharedPreferences.getInstance().then(
      (prefs) => _instance = prefs,
      onError: (Object e, StackTrace st) {
        _loading = null;
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  /// Loads the settings before the first frame. Optional but recommended.
  static Future<void> preload() async {
    try {
      await load();
    } catch (_) {
      // No storage (headless tests, unsupported platform): defaults apply.
    }
  }

  /// Forgets the cached instance (tests that swap mock values call this).
  @visibleForTesting
  static void debugReset() {
    _instance = null;
    _loading = null;
  }
}
