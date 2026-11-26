// 0.2.3: optional app-level conveniences on OmniApp.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class SessionBloc extends Bloc<bool, bool> {
  SessionBloc() : super(false) {
    on<bool>((v, emit) => emit(v));
  }
}

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) => Scaffold(body: Text(label));
}

final log = <String>[];

class AppHooks with OmniLifecycle {
  @override
  void onAppResumed(BuildContext context) =>
      log.add('resumed session=${context.read<SessionBloc>().state}');
  @override
  void onAppPaused(BuildContext context) => log.add('paused');
  @override
  void onMemoryPressure(BuildContext context) => log.add('memory');
}

class LogObserver extends BlocObserver {
  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    log.add('created ${bloc.runtimeType}');
  }
}

Widget app({
  OmniLifecycle? lifecycle,
  Future<void> Function(BuildContext)? onInit,
  WidgetBuilder? splash,
  bool dismissKeyboard = false,
  Duration? doubleBack,
  void Function(BuildContext)? onExitWarning,
  List<DeviceOrientation>? orientations,
  double? maxTextScale,
  BlocObserver? blocObserver,
  void Function(Object, StackTrace)? onError,
  List<OmniGuard> guards = const [],
  List<OmniRouteBase> extra = const [],
}) => OmniApp(
  lifecycle: lifecycle,
  onInit: onInit,
  splash: splash,
  dismissKeyboardOnTap: dismissKeyboard,
  doubleBackToExit: doubleBack,
  onExitWarning: onExitWarning,
  orientations: orientations,
  maxTextScale: maxTextScale,
  blocObserver: blocObserver,
  onError: onError,
  guards: guards,
  blocs: [
    OmniBloc<SessionBloc>((_) => SessionBloc(), global: true, lazy: false),
  ],
  routes: [
    OmniPage('/', (_) => const S('home')),
    OmniPage('/login', (_) => const S('login')),
    OmniPage('/next', (_) => const S('next')),
    ...extra,
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

void main() {
  setUp(log.clear);

  testWidgets(
    'lifecycle: app-wide hooks can read global Blocs; stop on dispose',
    (t) async {
      await t.pumpWidget(app(lifecycle: AppHooks()));
      await t.pumpAndSettle();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      t.binding.handleMemoryPressure();
      expect(log, ['paused', 'resumed session=false', 'memory']);

      await t.pumpWidget(const SizedBox());
      log.clear();
      t.binding.handleMemoryPressure();
      expect(log, isEmpty);
    },
  );

  testWidgets('onInit: splash first, guards see the loaded state', (t) async {
    await t.pumpWidget(
      app(
        onInit: (context) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          context.read<SessionBloc>().add(true); // e.g. restored login
          await Future<void>.delayed(Duration.zero);
        },
        splash: (_) => const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('splash'),
        ),
        guards: [
          OmniGuard.fn((c, s) {
            final loggedIn = c.read<SessionBloc>().state;
            return !loggedIn && s.matchedLocation != '/login' ? '/login' : null;
          }),
        ],
      ),
    );
    expect(find.text('splash'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'not sent to login');
  });

  testWidgets('onInit error is reported and the app still opens', (t) async {
    await t.pumpWidget(app(onInit: (_) async => throw StateError('no prefs')));
    await t.pumpAndSettle();
    expect(t.takeException(), isA<StateError>());
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('dismissKeyboardOnTap: outside tap unfocuses, field tap keeps', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        dismissKeyboard: true,
        extra: [OmniPage('/form', (_) => const FormScreen())],
      ),
    );
    OmniRoute.go('/form');
    await t.pumpAndSettle();
    await t.tap(find.byType(TextField));
    await t.pump();
    expect(fieldFocused(t), isTrue);
    await t.tap(find.byType(TextField)); // tapping the field keeps focus
    await t.pump();
    expect(fieldFocused(t), isTrue);
    await t.tapAt(const Offset(400, 500)); // empty area
    await t.pump();
    expect(fieldFocused(t), isFalse);
  });

  group('doubleBackToExit', () {
    late List<String> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
            if (c.method == 'SystemNavigator.pop') calls.add('exit');
            return null;
          });
    });

    testWidgets('Android: second back within the window exits', (t) async {
      await t.pumpWidget(
        app(
          doubleBack: const Duration(seconds: 2),
          onExitWarning: (_) => log.add('warn'),
        ),
      );
      await t.pumpAndSettle();

      await t.binding.handlePopRoute();
      await t.pump();
      expect(log, ['warn']);
      expect(calls, isEmpty);
      expect(find.text('home'), findsOneWidget);

      await t.pump(const Duration(seconds: 3)); // window passed
      await t.binding.handlePopRoute();
      await t.pump();
      expect(log, ['warn', 'warn'], reason: 'too late: warns again');

      await t.binding.handlePopRoute();
      await t.pump();
      expect(calls, ['exit']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Android: non-root pages pop normally', (t) async {
      await t.pumpWidget(
        app(
          doubleBack: const Duration(seconds: 2),
          onExitWarning: (_) => log.add('warn'),
        ),
      );
      await t.pumpAndSettle();
      OmniRoute.push('/next');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(log, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('iOS: no effect', (t) async {
      await t.pumpWidget(
        app(
          doubleBack: const Duration(seconds: 2),
          onExitWarning: (_) => log.add('warn'),
        ),
      );
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pump();
      expect(log, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets('orientations are set and reset on dispose', (t) async {
    final sets = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
          if (c.method == 'SystemChrome.setPreferredOrientations') {
            sets.add(c.arguments);
          }
          return null;
        });
    await t.pumpWidget(app(orientations: const [DeviceOrientation.portraitUp]));
    await t.pumpWidget(const SizedBox());
    expect(sets, [
      ['DeviceOrientation.portraitUp'],
      <String>[],
    ]);
  });

  testWidgets('maxTextScale clamps large accessibility fonts', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(app(maxTextScale: 1.5));
    await t.pumpAndSettle();
    final scaler = MediaQuery.textScalerOf(t.element(find.text('home')));
    expect(scaler.scale(10), 15);
  });

  testWidgets('blocObserver sees global Blocs; previous observer restored', (
    t,
  ) async {
    final before = Bloc.observer;
    final observer = LogObserver();
    await t.pumpWidget(app(blocObserver: observer));
    expect(Bloc.observer, same(observer));
    expect(log, contains('created SessionBloc'));
    await t.pumpWidget(const SizedBox());
    expect(Bloc.observer, same(before));
  });

  testWidgets('onError gets framework and platform errors; handlers restored', (
    t,
  ) async {
    final errors = <Object>[];
    final flutterBefore = FlutterError.onError;
    final platformBefore = PlatformDispatcher.instance.onError;
    await t.pumpWidget(
      app(
        onError: (e, _) => errors.add(e),
        extra: [OmniPage('/boom', (_) => const Boom())],
      ),
    );
    OmniRoute.go('/boom');
    await t.pumpAndSettle();
    expect(
      t.takeException(),
      isA<StateError>(),
      reason: 'previous handler still runs',
    );
    expect(errors.single, isA<StateError>());

    PlatformDispatcher.instance.onError!(
      ArgumentError('async'),
      StackTrace.empty,
    );
    expect(errors.last, isA<ArgumentError>());

    await t.pumpWidget(const SizedBox());
    expect(FlutterError.onError, same(flutterBefore));
    expect(PlatformDispatcher.instance.onError, same(platformBefore));
  });

  testWidgets('defaults: none of the extras are installed', (t) async {
    final flutterBefore = FlutterError.onError;
    final observerBefore = Bloc.observer;
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(FlutterError.onError, same(flutterBefore));
    expect(Bloc.observer, same(observerBefore));
    expect(find.byType(GestureDetector), findsNothing);
    expect(find.byType(PopScope), findsNothing);
  });
}

class FormScreen extends OmniStatelessWidget {
  const FormScreen({super.key});
  @override
  String get screenName => 'form';
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 200, child: TextField()),
    ),
  );
}

class Boom extends OmniStatelessWidget {
  const Boom({super.key});
  @override
  String get screenName => 'boom';
  @override
  Widget build(BuildContext context) => throw StateError('boom');
}

bool fieldFocused(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
