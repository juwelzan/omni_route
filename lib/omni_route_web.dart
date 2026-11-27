import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/platform/omni_device_info.dart';
import 'src/platform/omni_route_platform_interface.dart';

/// Web implementation of [OmniRoutePlatform] registered automatically by
/// `flutter_web_plugins`.
class OmniRouteWeb extends OmniRoutePlatform {
  /// Constructs an [OmniRouteWeb] instance.
  OmniRouteWeb();

  /// Registers [OmniRouteWeb] as the active [OmniRoutePlatform] on the Web.
  static void registerWith(Registrar registrar) {
    OmniRoutePlatform.instance = OmniRouteWeb();
  }

  @override
  Future<String?> getPlatformVersion() async =>
      'Web (${web.window.navigator.userAgent})';

  @override
  Future<OmniDeviceInfo> getDeviceInfo() async => OmniDeviceInfo(
    platform: 'web',
    osVersion: web.window.navigator.userAgent,
    appName: web.document.title,
    packageName: web.window.location.host,
    locale: web.window.navigator.language,
  );

  @override
  Future<bool> hideKeyboard() async {
    try {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      final active = web.document.activeElement;
      if (active != null && active.isA<web.HTMLElement>()) {
        (active as web.HTMLElement).blur();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> keepScreenOn(bool enabled) async => false;

  @override
  Future<bool> clearNativeCache() async => true;
}
