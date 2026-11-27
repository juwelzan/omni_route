import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'omni_device_info.dart';
import 'omni_route_platform_interface.dart';

/// Default [OmniRoutePlatform] implementation backed by [MethodChannel].
class MethodChannelOmniRoute extends OmniRoutePlatform {
  /// Method channel communicating with native Android, iOS, macOS, Linux, and
  /// Windows code.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'dev.omniroute/omni_route',
  );

  String get _fallbackPlatformName => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'macos',
          TargetPlatform.linux => 'linux',
          TargetPlatform.windows => 'windows',
          TargetPlatform.fuchsia => 'fuchsia',
        };

  @override
  Future<String?> getPlatformVersion() async {
    try {
      return await methodChannel.invokeMethod<String>('getPlatformVersion');
    } on MissingPluginException {
      return _fallbackPlatformName;
    }
  }

  @override
  Future<OmniDeviceInfo> getDeviceInfo() async {
    final fallback = _fallbackPlatformName;
    try {
      final map = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getDeviceInfo',
      );
      if (map != null) {
        return OmniDeviceInfo.fromMap(map, fallbackPlatform: fallback);
      }
    } on MissingPluginException {
      // Fallback for unmocked VM tests / unsupported targets.
    }
    return OmniDeviceInfo(platform: fallback);
  }

  @override
  Future<bool> hideKeyboard() async {
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    } catch (_) {
      // Best-effort Flutter channel clear.
    }
    try {
      return await methodChannel.invokeMethod<bool>('hideKeyboard') ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  @override
  Future<bool> keepScreenOn(bool enabled) async {
    try {
      return await methodChannel.invokeMethod<bool>('keepScreenOn', {
            'enabled': enabled,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> clearNativeCache() async {
    try {
      return await methodChannel.invokeMethod<bool>('clearNativeCache') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
