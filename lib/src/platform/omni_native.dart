import 'omni_device_info.dart';
import 'omni_route_platform_interface.dart';

/// Unified native platform utilities bundled directly inside the `omni_route`
/// Flutter plugin across Android, iOS, macOS, Linux, Windows, and Web.
abstract final class OmniNative {
  /// Returns the host platform & OS version string (e.g. `Android 15`,
  /// `iOS 18.2`, `macOS 15.3`, or `Web (...)`).
  static Future<String?> getPlatformVersion() =>
      OmniRoutePlatform.instance.getPlatformVersion();

  /// Returns native device, OS, bundle/package ID, version, build number, and
  /// active locale metadata.
  static Future<OmniDeviceInfo> getDeviceInfo() =>
      OmniRoutePlatform.instance.getDeviceInfo();

  /// Hides the native software keyboard / clears the active OS input focus.
  static Future<bool> hideKeyboard() =>
      OmniRoutePlatform.instance.hideKeyboard();

  /// Keeps the device screen awake while [enabled] is `true` (Android & iOS).
  static Future<bool> keepScreenOn(bool enabled) =>
      OmniRoutePlatform.instance.keepScreenOn(enabled);

  /// Clears temporary native cache files where supported by the host OS.
  static Future<bool> clearNativeCache() =>
      OmniRoutePlatform.instance.clearNativeCache();
}
