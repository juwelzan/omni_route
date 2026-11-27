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

    test('single import exposes routing, Bloc, networking, inspector, & storage APIs cleanly', () async {
      // Routing & Flows
      const flowCfg = OmniConfig(
        auth: OmniAuthConfig(homeRoute: '/home'),
      );
      expect(flowCfg.auth?.homeRoute, '/home');

      // Bloc (re-exported from flutter_bloc)
      final bloc = _TestBloc();
      expect(bloc.state, 0);
      await bloc.close();

      // Networking & Flutter Inspector & Secure Storage (re-exported cleanly)
      final mockTransport = MockTransport(
        (_) async => OmniRawResponse(
          statusCode: 200,
          bodyBytes: Uint8List.fromList('{"ok":true}'.codeUnits),
          headers: const {'content-type': 'application/json'},
        ),
      );
      final net = OmniNetwork(
        baseUrl: 'https://example.com',
        auth: OmniAuth(storage: SecureTokenStorage()),
        transport: mockTransport,
      );
      final inspector = OmniInspector();
      final res = await net.get<Map<String, dynamic>>('/ping');
      expect(res, {'ok': true});
      expect(inspector, isA<OmniInspector>());
      expect(const RetryPolicy(), isA<RetryPolicy>());

      await net.close();
      inspector.dispose();
    });

    test('MethodChannelOmniRoute communicates cleanly with native handlers & falls back safely', () async {
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
    });

    test('custom OmniRoutePlatform backend override works seamlessly', () async {
      OmniRoutePlatform.instance = _FakePlatform();
      expect(await OmniNative.getPlatformVersion(), 'FakeOS 9.9');
      final info = await OmniNative.getDeviceInfo();
      expect(info.appName, 'FakeApp');
      expect(info.locale, 'bn-BD');
      expect(await OmniNative.keepScreenOn(true), isTrue);
    });
  });
}
