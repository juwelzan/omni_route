import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/testing.dart';

class _TestBloc extends Cubit<int> {
  _TestBloc() : super(0);
}

class _FakePlatform extends OmniRoutePlatform {
  @override
  Future<String?> getPlatformVersion() async => 'FakeOS 9.9';

  @override
  Future<OmniDeviceInfo> getDeviceInfo() async => const OmniDeviceInfo(
    platform: 'fake',
    osVersion: '9.9',
    appName: 'FakeApp',
    packageName: 'dev.fake.app',
    version: '1.2.3',
    buildNumber: '42',
    locale: 'bn-BD',
  );

  @override
  Future<bool> hideKeyboard() async => true;

  @override
  Future<bool> keepScreenOn(bool enabled) async => enabled;

  @override
  Future<bool> clearNativeCache() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('All-in-one OmniRoute Plugin & Unified Exports', () {
    tearDown(() {
      OmniRoutePlatform.instance = MethodChannelOmniRoute();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.omniroute/omni_route'),
            null,
          );
    });

    test('single import exposes routing, Bloc and responsive APIs', () async {
      // Routing & Flows
      const flowCfg = OmniConfig(auth: OmniAuthConfig(homeRoute: '/home'));
      expect(flowCfg.auth?.homeRoute, '/home');

      // Bloc (re-exported from flutter_bloc)
      final bloc = _TestBloc();
      expect(bloc.state, 0);
      await bloc.close();

      // Responsive UI (re-exported from omni_responsive)
      expect(OmniTheme.presets, isNotEmpty);
      expect(const OmniResponsiveConfig().enabled, isTrue);
    });

    test('omni_route does not pull in networking or secure storage', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final deps = pubspec.substring(
        pubspec.indexOf('\ndependencies:'),
        pubspec.indexOf('\ndev_dependencies:'),
      );
      for (final heavy in [
        'dio',
        'flutter_secure_storage',
        'web_socket_channel',
        'omni_network',
      ]) {
        expect(
          RegExp('^  $heavy\\b', multiLine: true).hasMatch(deps),
          isFalse,
          reason: '$heavy must stay an opt-in package',
        );
      }
    });

    test(
      'MethodChannelOmniRoute communicates cleanly with native handlers & falls back safely',
      () async {
        // Unmocked VM test fallback never throws MissingPluginException.
        final fallbackInfo = await OmniNative.getDeviceInfo();
        expect(fallbackInfo.platform, isNotEmpty);
        expect(await OmniNative.getPlatformVersion(), isNotEmpty);
        expect(await OmniNative.hideKeyboard(), isTrue);
        expect(await OmniNative.keepScreenOn(true), isFalse);
        expect(await OmniNative.clearNativeCache(), isFalse);

        // Mock native plugin responses over dev.omniroute/omni_route MethodChannel.
        final recordedCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('dev.omniroute/omni_route'),
              (call) async {
                recordedCalls.add(call);
                return switch (call.method) {
                  'getPlatformVersion' => 'Android 15',
                  'getDeviceInfo' => {
                    'platform': 'android',
                    'osVersion': 'Android 15 (SDK 35)',
                    'appName': 'Omni Demo',
                    'packageName': 'dev.omniroute.demo',
                    'version': '0.4.0',
                    'buildNumber': '4',
                    'locale': 'bn-BD',
                  },
                  'hideKeyboard' => true,
                  'keepScreenOn' => (call.arguments as Map)['enabled'] == true,
                  'clearNativeCache' => true,
                  _ => null,
                };
              },
            );

        expect(await OmniNative.getPlatformVersion(), 'Android 15');
        final info = await OmniNative.getDeviceInfo();
        expect(info.platform, 'android');
        expect(info.appName, 'Omni Demo');
        expect(info.packageName, 'dev.omniroute.demo');
        expect(info.version, '0.4.0');
        expect(info.buildNumber, '4');
        expect(info.locale, 'bn-BD');
        expect(await OmniNative.hideKeyboard(), isTrue);
        expect(await OmniNative.keepScreenOn(true), isTrue);
        expect(await OmniNative.clearNativeCache(), isTrue);
        expect(recordedCalls.map((c) => c.method), [
          'getPlatformVersion',
          'getDeviceInfo',
          'hideKeyboard',
          'keepScreenOn',
          'clearNativeCache',
        ]);
      },
    );

    test(
      'custom OmniRoutePlatform backend override works seamlessly',
      () async {
        OmniRoutePlatform.instance = _FakePlatform();
        expect(await OmniNative.getPlatformVersion(), 'FakeOS 9.9');
        final info = await OmniNative.getDeviceInfo();
        expect(info.appName, 'FakeApp');
        expect(info.locale, 'bn-BD');
        expect(await OmniNative.keepScreenOn(true), isTrue);
      },
    );
  });
}
