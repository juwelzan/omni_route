import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple key-value persistence backend used by `OmniOnboarding` to remember
/// whether Onboarding should still run across cold restarts (including clearing
/// the app from background).
///
/// By default OmniRoute uses [OmniOnboardingStore.defaultStore], backed
/// automatically by `shared_preferences` across Android, iOS, Web, macOS,
/// Windows, and Linux—no manual database setup required.
abstract interface class OmniLocalStore {
  /// Reads a stored boolean for [key], returning `null` if unset.
  Future<bool?> getBool(String key);

  /// Saves boolean [value] under [key].
  Future<void> setBool(String key, bool value);

  /// Deletes any value saved under [key].
  Future<void> remove(String key);
}

/// Built-in local database bridge for `OmniOnboarding` state persistence.
@internal
final class OmniOnboardingStore implements OmniLocalStore {
  OmniOnboardingStore._();

  /// Shared default store using `SharedPreferences` with safe in-memory
  /// fallback when platform channels are unavailable (e.g. unmocked VM tests).
  static final OmniOnboardingStore defaultStore = OmniOnboardingStore._();

  static final Map<String, bool> _memoryFallback = {};

  /// Canonical storage key prefix for an onboarding `storageKey`.
  static String prefKey(String storageKey) =>
      'omni_route.onboarding.$storageKey.done';

  /// Reads whether onboarding for [storageKey] has already satisfied its policy.
  static Future<bool> isDone(
    String storageKey, {
    OmniLocalStore? customStore,
  }) async {
    final store = customStore ?? defaultStore;
    return await store.getBool(prefKey(storageKey)) ?? false;
  }

  /// Persists completion for [storageKey].
  static Future<void> markDone(
    String storageKey, {
    OmniLocalStore? customStore,
  }) {
    final store = customStore ?? defaultStore;
    return store.setBool(prefKey(storageKey), true);
  }

  /// Clears stored state for [storageKey] so Onboarding can appear again.
  static Future<void> clearDone(
    String storageKey, {
    OmniLocalStore? customStore,
  }) {
    final store = customStore ?? defaultStore;
    return store.remove(prefKey(storageKey));
  }

  /// Clears the headless test fallback cache (useful between unit tests).
  @visibleForTesting
  static void resetMemoryFallback() => _memoryFallback.clear();

  @override
  Future<bool?> getBool(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key);
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _memoryFallback[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Fallback kept in _memoryFallback when platform channel unavailable.
    }
  }

  @override
  Future<void> remove(String key) async {
    _memoryFallback.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // Fallback kept in _memoryFallback when platform channel unavailable.
    }
  }
}
