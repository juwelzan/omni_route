import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'omni_device_info.dart';
import 'omni_route_method_channel.dart';

/// Platform interface implemented by each native platform plugin backend for
/// `omni_route`.
abstract class OmniRoutePlatform extends PlatformInterface {
  /// Constructs an [OmniRoutePlatform].
  OmniRoutePlatform() : super(token: _token);

  static final Object _token = Object();

  static OmniRoutePlatform _instance = MethodChannelOmniRoute();

  /// Active platform implementation (defaults to [MethodChannelOmniRoute]).
  static OmniRoutePlatform get instance => _instance;

  /// Overrides [instance] with a platform implementation or test fake.
  static set instance(OmniRoutePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a human-readable host OS/platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Returns structured native device & app bundle metadata.
  Future<OmniDeviceInfo> getDeviceInfo() {
    throw UnimplementedError('getDeviceInfo() has not been implemented.');
  }

  /// Hides the native software keyboard / clears active input responder.
  Future<bool> hideKeyboard() {
    throw UnimplementedError('hideKeyboard() has not been implemented.');
  }

  /// Toggles native screen wake-lock (`true` keeps screen awake).
  Future<bool> keepScreenOn(bool enabled) {
    throw UnimplementedError('keepScreenOn() has not been implemented.');
  }

  /// Clears temporary native plugin/app cache files where supported.
  Future<bool> clearNativeCache() {
    throw UnimplementedError('clearNativeCache() has not been implemented.');
  }
}
