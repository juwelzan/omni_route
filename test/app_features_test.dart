// 0.2.3: optional app-level conveniences on OmniApp.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionBloc extends Bloc<bool, bool> {
  SessionBloc() : super(false) {
    on<bool>((v, emit) => emit(v));
  }
}

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/${label.replaceAll(' ', '-').toLowerCase()}';
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
    expect(find.byType(MultiRepositoryProvider), findsNothing);
  });

  group('OmniApp upgrades & hot-reload fixes', () {
    testWidgets(
      'OmniApp.material + OmniRepo + overlayBuilder + themeModeBuilder work seamlessly',
      (t) async {
        var disposed = false;
        await t.pumpWidget(
          OmniApp.material(
            title: 'Upgraded App',
            repositories: [
              OmniRepo(
                (_) => _GreetingService('Hello DI'),
                dispose: (_) => disposed = true,
              ),
            ],
            blocs: [
              OmniBloc((_) => SessionBloc(), global: true),
              OmniBloc(
                (c) => _GreetingBloc(c.read<_GreetingService>().greeting),
                global: true,
              ),
            ],
            themeModeBuilder: (c) => c.watch<SessionBloc>().state
                ? ThemeMode.dark
                : ThemeMode.light,
            overlayBuilder: (_, child) => Stack(
              textDirection: TextDirection.ltr,
              children: [
                child!,
                const Positioned(top: 0, left: 0, child: Text('overlay-pill')),
              ],
            ),
            routes: [
              OmniPage('/', (_) => const _GreetingScreen()),
              OmniPage('/next', (_) => const S('next')),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('Hello DI'), findsOneWidget);
        expect(find.text('overlay-pill'), findsOneWidget);
        expect(OmniRoute.paths, containsAll(['/', '/next']));

        await t.pumpWidget(const SizedBox());
        expect(disposed, isTrue);
      },
    );

    testWidgets('OmniApp.cupertino builds CupertinoApp.router cleanly', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp.cupertino(
          title: 'Cupertino App',
          routes: [
            OmniPage('/', (_) => const CupertinoPageScaffold(child: Text('cu'))),
          ],
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(CupertinoApp), findsOneWidget);
      expect(find.text('cu'), findsOneWidget);
    });

    testWidgets(
      'onInitError supports retry & initTimeout; resolveInitialRoute chooses startup route',
      (t) async {
        var attempts = 0;
        await t.pumpWidget(
          OmniApp.material(
            onInit: (_) async {
              attempts++;
              if (attempts == 1) {
                throw StateError('network down');
              }
            },
            resolveInitialRoute: (_) async => '/onboarding',
            onInitError: (_, err, _, retry) => Directionality(
              textDirection: TextDirection.ltr,
              child: TextButton(
                onPressed: retry,
                child: Text('Retry: $err'),
              ),
            ),
            routes: [
              OmniPage('/', (_) => const S('home')),
              OmniPage('/onboarding', (_) => const S('onboarding')),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.textContaining('Retry: Bad state: network down'), findsOneWidget);
        await t.tap(find.byType(TextButton));
        await t.pumpAndSettle();
        expect(find.text('onboarding'), findsOneWidget);

        // initTimeout triggers onInitError cleanly.
        await t.pumpWidget(
          OmniApp.material(
            key: const ValueKey('timeout'),
            onInit: (_) => Completer<void>().future,
            initTimeout: const Duration(milliseconds: 20),
            onInitError: (_, err, _, _) => Directionality(
              textDirection: TextDirection.ltr,
              child: Text('TimedOut: ${err.runtimeType}'),
            ),
            routes: [OmniPage('/', (_) => const S('home'))],
          ),
        );
        await t.pump(const Duration(milliseconds: 50));
        await t.pumpAndSettle();
        expect(find.text('TimedOut: TimeoutException'), findsOneWidget);
      },
    );

    testWidgets(
      'didUpdateWidget recovers from bad routes, syncs GuardRefresh, blocObserver & onNavigate',
      (t) async {
        final navKinds = <OmniNavigationKind>[];
        final authStream1 = StreamController<bool>.broadcast();
        final authStream2 = StreamController<bool>.broadcast();
        addTearDown(() async {
          await authStream1.close();
          await authStream2.close();
        });
        var authed = false;

        Widget buildApp({
          required bool brokenRoutes,
          required bool enableNavCallback,
          required Stream<bool> guardStream,
          BlocObserver? observer,
        }) => OmniApp.material(
          blocObserver: observer,
          onNavigate: enableNavCallback ? (e) => navKinds.add(e.kind) : null,
          guards: [
            OmniGuard.fn(
              (_, s) => !authed && s.matchedLocation != '/login'
                  ? '/login'
                  : (authed && s.matchedLocation == '/login' ? '/next' : null),
              refresh: (_) => guardStream,
            ),
          ],
          routes: brokenRoutes
              ? [OmniPage('/dup', (_) => const S('a')), OmniPage('/dup', (_) => const S('b'))]
              : [
                  OmniPage('/', (_) => const S('home')),
                  OmniPage('/login', (_) => const S('login')),
                  OmniPage('/next', (_) => const S('next')),
                ],
        );

        // 1. Start with broken duplicate routes -> renders ErrorWidget.
        await t.pumpWidget(
          buildApp(
            brokenRoutes: true,
            enableNavCallback: false,
            guardStream: authStream1.stream,
          ),
        );
        expect(t.takeException(), isA<OmniRouteException>());
        expect(find.byType(ErrorWidget), findsOneWidget);

        // 2. Recover via widget update (simulating Hot Reload fix) + enable nav callback & guard stream 2.
        final observer = LogObserver();
        await t.pumpWidget(
          buildApp(
            brokenRoutes: false,
            enableNavCallback: true,
            guardStream: authStream2.stream,
            observer: observer,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('login'), findsOneWidget);
        expect(Bloc.observer, same(observer));

        // 3. Emitting on new guardStream2 triggers redirect (previously stuck on stale stream1).
        authed = true;
        authStream2.add(true);
        await t.pumpAndSettle();
        expect(find.text('next'), findsOneWidget);

        // 4. Verified navigation kinds tracked cleanly when toggled on dynamically.
        OmniRoute.push('/');
        await t.pumpAndSettle();
        expect(navKinds, contains(OmniNavigationKind.push));
        OmniRoute.pop();
        await t.pumpAndSettle();
        expect(navKinds.last, OmniNavigationKind.pop);
      },
    );

    test('OmniApp.validateRoutes catches duplicates and lists canonical paths', () {
      expect(
        OmniApp.validateRoutes([
          OmniPage('/', (_) => const S('home')),
          OmniPage('/users/:id', (_) => const S('user')),
        ]),
        ['/', '/users/:id'],
      );
      expect(
        () => OmniApp.validateRoutes([
          OmniPage('/a', (_) => const S('a1')),
          OmniPage('/a', (_) => const S('a2')),
        ]),
        throwsA(isA<OmniRouteException>()),
      );
    });
  });

  group('OmniConfig: Splash, Multi-Screen Onboarding, Auth & Public Screens', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'OmniSplash(screen/manualFinish) -> multi-screen OmniOnboarding(screens + overlayBuilder) step controls, redirectTo & replay',
      (t) async {
        var initDone = false;
        var completedCount = 0;
        var skipped = false;
        final stepChanges = <int>[];
        BuildContext? appCtx;

        await t.pumpWidget(
          OmniApp.material(
            config: OmniConfig(
              splash: OmniSplash(
                minDuration: const Duration(milliseconds: 120),
                manualFinish: true,
                builder: (ctx) => Scaffold(
                  body: Column(
                    children: [
                      const Text('MyCustomSplash'),
                      TextButton(
                        onPressed: () => ctx.flow?.finishSplash(),
                        child: const Text('EnterApp'),
                      ),
                    ],
                  ),
                ),
                onInit: (_) async {
                  initDone = true;
                },
              ),
              onboarding: OmniOnboarding(
                screens: [
                  Builder(
                    builder: (ctx) => Column(
                      children: [
                        const Text('Slide-1'),
                        TextButton(
                          onPressed: () => ctx.flow?.nextOnboarding(),
                          child: const Text('NextFrom1'),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (ctx) => Column(
                      children: [
                        const Text('Slide-2'),
                        TextButton(
                          onPressed: () => ctx.flow?.previousOnboarding(),
                          child: const Text('BackFrom2'),
                        ),
                        TextButton(
                          onPressed: () => ctx.flow?.goToOnboardingStep(2),
                          child: const Text('JumpTo3'),
                        ),
                      ],
                    ),
                  ),
                  Builder(
                    builder: (ctx) => Column(
                      children: [
                        const Text('Slide-3'),
                        TextButton(
                          onPressed: () => ctx.flow?.nextOnboarding(),
                          child: const Text('DoneOn3'),
                        ),
                      ],
                    ),
                  ),
                ],
                overlayBuilder: (ctx, flow, child) => Scaffold(
                  body: Column(
                    children: [
                      Text('Step ${flow.onboardingStep + 1}/${flow.onboardingCount}'),
                      Expanded(child: child),
                      TextButton(
                        onPressed: () => flow.skipOnboarding(),
                        child: const Text('SkipOB'),
                      ),
                    ],
                  ),
                ),
                onStepChanged: stepChanges.add,
                onSkip: (_) => skipped = true,
                onDone: (_) => completedCount++,
                afterDone: (_) => '/home',
              ),
            ),
            routes: [
              OmniPage('/', (_) => const S('root')),
              OmniPage(
                '/home',
                (_) => Builder(
                  builder: (ctx) {
                    appCtx = ctx;
                    return Scaffold(
                      body: Column(
                        children: [
                          const Text('home-page'),
                          TextButton(
                            onPressed: () => ctx.flow?.replayOnboarding(),
                            child: const Text('ReplayOB'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        // Stays on splash during minDuration & manualFinish hold.
        await t.pump();
        expect(initDone, isTrue);
        expect(find.text('MyCustomSplash'), findsOneWidget);

        await t.pump(const Duration(milliseconds: 150));
        expect(find.text('MyCustomSplash'), findsOneWidget);

        // Finish splash -> opens multi-screen onboarding on Slide 1.
        await t.tap(find.text('EnterApp'));
        await t.pumpAndSettle();
        expect(find.text('Slide-1'), findsOneWidget);
        expect(find.text('Step 1/3'), findsOneWidget);
        expect(appCtx, isNull); // /home not mounted yet

        // Next -> Slide 2, Back -> Slide 1, Next -> Slide 2, Jump -> Slide 3.
        await t.tap(find.text('NextFrom1'));
        await t.pumpAndSettle();
        expect(find.text('Slide-2'), findsOneWidget);
        expect(find.text('Step 2/3'), findsOneWidget);

        await t.tap(find.text('BackFrom2'));
        await t.pumpAndSettle();
        expect(find.text('Slide-1'), findsOneWidget);

        await t.tap(find.text('NextFrom1'));
        await t.pumpAndSettle();
        await t.tap(find.text('JumpTo3'));
        await t.pumpAndSettle();
        expect(find.text('Slide-3'), findsOneWidget);
        expect(find.text('Step 3/3'), findsOneWidget);

        // Next on last slide completes onboarding cleanly -> /home.
        expect(stepChanges, [1, 0, 1, 2]);
        await t.tap(find.text('DoneOn3'));
        await t.pumpAndSettle();
        expect(completedCount, 1);
        expect(skipped, isFalse);
        expect(find.text('home-page'), findsOneWidget);
        expect(OmniRoute.location.path, '/home');
        expect(appCtx?.flow, isNotNull);

        // Replay onboarding -> starts back on Slide 1 -> Skip skips cleanly.
        await t.tap(find.text('ReplayOB'));
        await t.pumpAndSettle();
        expect(find.text('Slide-1'), findsOneWidget);
        expect(find.text('Step 1/3'), findsOneWidget);

        await t.tap(find.text('SkipOB'));
        await t.pumpAndSettle();
        expect(skipped, isTrue);
        expect(completedCount, 2);
        expect(find.text('home-page'), findsOneWidget);
      },
    );

    testWidgets(
      'OmniAuth(loginScreen/signupScreen) + publicScreens/publicPages/publicRoutes, pushPublic, ?from= return & logout',
      (t) async {
        final authed = ValueNotifier<bool>(false);
        addTearDown(authed.dispose);

        await t.pumpWidget(
          OmniApp.material(
            config: OmniConfig(
              auth: OmniAuth(
                isAuthenticated: (_) => authed.value,
                refreshListenable: authed,
                homeRoute: '/home',
                loginRoute: '/login',
                loginScreen: Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('LoginScreen'),
                        TextButton(
                          onPressed: () => ctx.flow?.pushPublic('/terms'),
                          child: const Text('ReadTerms'),
                        ),
                        TextButton(
                          onPressed: () => ctx.flow?.goToSignup(),
                          child: const Text('GoSignup'),
                        ),
                      ],
                    ),
                  ),
                ),
                signupRoute: '/signup',
                signupScreen: Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('SignupScreen'),
                        TextButton(
                          onPressed: () => authed.value = true,
                          child: const Text('CompleteSignup'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              publicScreens: const {
                '/about': S('AboutPublicScreen'),
                '/terms': S('TermsPublicScreen'),
              },
              publicPages: [
                OmniPage('/article/:id', (p) => S('Article-${p.path('id')}')),
              ],
              publicRoutes: const ['/docs/*'],
            ),
            routes: [
              OmniPage(
                '/home',
                (_) => Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('HomeDashboard'),
                        TextButton(
                          onPressed: () =>
                              ctx.flow?.logout((_) => authed.value = false),
                          child: const Text('LogOut'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OmniPage('/docs/intro', (_) => const S('DocsIntro')),
              OmniPage(
                '/profile/:id',
                (p) => S('Profile-${p.path('id')}-${p.query('tab')}'),
              ),
            ],
          ),
        );

        await t.pumpAndSettle();
        // Auto-started at homeRoute ('/home'), unauthenticated -> clean '/login'.
        expect(find.text('LoginScreen'), findsOneWidget);
        expect(OmniRoute.location.toString(), '/login');

        // pushPublic from Login -> opens /terms, and pop returns cleanly to Login.
        await t.tap(find.text('ReadTerms'));
        await t.pumpAndSettle();
        expect(find.text('TermsPublicScreen'), findsOneWidget);
        expect(OmniRoute.canPop(), isTrue);
        OmniRoute.pop();
        await t.pumpAndSettle();
        expect(find.text('LoginScreen'), findsOneWidget);

        // All publicScreens, publicPages & publicRoutes work before login.
        OmniRoute.go('/about');
        await t.pumpAndSettle();
        expect(find.text('AboutPublicScreen'), findsOneWidget);

        OmniRoute.go('/article/99');
        await t.pumpAndSettle();
        expect(find.text('Article-99'), findsOneWidget);

        OmniRoute.go('/docs/intro');
        await t.pumpAndSettle();
        expect(find.text('DocsIntro'), findsOneWidget);

        // Protected deep route while logged out redirects to /login?from=...
        OmniRoute.go('/profile/7?tab=security');
        await t.pumpAndSettle();
        expect(find.text('LoginScreen'), findsOneWidget);
        expect(
          OmniRoute.location.queryParameters['from'],
          '/profile/7?tab=security',
        );

        // Switching to Signup preserves ?from= and authenticating returns to /profile/7?tab=security!
        await t.tap(find.text('GoSignup'));
        await t.pumpAndSettle();
        expect(find.text('SignupScreen'), findsOneWidget);

        await t.tap(find.text('CompleteSignup'));
        await t.pumpAndSettle();
        expect(find.text('Profile-7-security'), findsOneWidget);

        // Cannot go back to /login or /signup while authenticated.
        expect(OmniRoute.canPop(), isFalse);
        OmniRoute.go('/login');
        await t.pumpAndSettle();
        expect(find.text('HomeDashboard'), findsOneWidget);
        expect(OmniRoute.location.path, '/home');

        OmniRoute.go('/signup');
        await t.pumpAndSettle();
        expect(find.text('HomeDashboard'), findsOneWidget);

        // Logout clears session & redirects cleanly to /login with no pop stack back to /home.
        await t.tap(find.text('LogOut'));
        await t.pumpAndSettle();
        expect(find.text('LoginScreen'), findsOneWidget);
        expect(OmniRoute.location.toString(), '/login');
        expect(OmniRoute.canPop(), isFalse);
      },
    );

    testWidgets(
      'Cupertino supports OmniConfig with multi-route onboarding, authRefresh stream, afterLogout & onError retry',
      (t) async {
        final authStream = StreamController<bool>.broadcast();
        addTearDown(authStream.close);
        var loggedIn = false;
        var attempts = 0;

        await t.pumpWidget(
          OmniApp.cupertino(
            title: 'Cupertino Flow',
            config: OmniConfig(
              splash: OmniSplash(
                screen: const CupertinoPageScaffold(
                  child: Center(child: Text('CuSplash')),
                ),
                onInit: (_) async {
                  attempts++;
                  if (attempts == 1) throw StateError('boot failed');
                },
                onError: (_, err, _, retry) => CupertinoPageScaffold(
                  child: Center(
                    child: CupertinoButton(
                      onPressed: retry,
                      child: Text('RetryInit: $err'),
                    ),
                  ),
                ),
              ),
              onboarding: OmniOnboarding(
                routes: const ['/ob-1', '/ob-2'],
                shouldShow: (_) => true,
              ),
              auth: OmniAuth(
                isAuthenticated: (_) => loggedIn,
                refreshStream: (_) => authStream.stream,
                loginRoute: '/login',
                homeRoute: '/app',
                afterLogout: (_) => '/goodbye',
              ),
              publicScreens: const {
                '/goodbye': CupertinoPageScaffold(child: Text('GoodbyePublic')),
              },
            ),
            routes: [
              OmniPage(
                '/ob-1',
                (_) => Builder(
                  builder: (ctx) => CupertinoPageScaffold(
                    child: CupertinoButton(
                      onPressed: () => ctx.flow?.nextOnboarding(),
                      child: const Text('ObStep1Next'),
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/ob-2',
                (_) => Builder(
                  builder: (ctx) => CupertinoPageScaffold(
                    child: CupertinoButton(
                      onPressed: () => ctx.flow?.nextOnboarding(),
                      child: const Text('ObStep2Finish'),
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/login',
                (_) => CupertinoPageScaffold(
                  child: CupertinoButton(
                    onPressed: () {
                      loggedIn = true;
                      authStream.add(true);
                    },
                    child: const Text('CuLogin'),
                  ),
                ),
              ),
              OmniPage(
                '/app',
                (_) => Builder(
                  builder: (ctx) => CupertinoPageScaffold(
                    child: CupertinoButton(
                      onPressed: () => ctx.flow?.logout((_) {
                        loggedIn = false;
                      }),
                      child: const Text('CuLogout'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        await t.pumpAndSettle();
        expect(find.byType(CupertinoApp), findsNothing);
        expect(
          find.textContaining('RetryInit: Bad state: boot failed'),
          findsOneWidget,
        );

        // Retry init -> transitions to /ob-1 inside CupertinoApp!
        await t.tap(find.textContaining('RetryInit:'));
        await t.pumpAndSettle();
        expect(find.byType(CupertinoApp), findsOneWidget);
        expect(find.text('ObStep1Next'), findsOneWidget);
        expect(OmniRoute.location.path, '/ob-1');

        // nextOnboarding moves /ob-1 -> /ob-2, then completes -> /login!
        await t.tap(find.text('ObStep1Next'));
        await t.pumpAndSettle();
        expect(find.text('ObStep2Finish'), findsOneWidget);
        expect(OmniRoute.location.path, '/ob-2');

        await t.tap(find.text('ObStep2Finish'));
        await t.pumpAndSettle();
        expect(find.text('CuLogin'), findsOneWidget);
        expect(OmniRoute.location.path, '/login');

        // Stream authRefresh triggers redirect from /login -> /app.
        await t.tap(find.text('CuLogin'));
        await t.pumpAndSettle();
        expect(find.text('CuLogout'), findsOneWidget);
        expect(OmniRoute.location.path, '/app');

        // Logout uses afterLogout ('/goodbye'), registered via publicScreens.
        await t.tap(find.text('CuLogout'));
        await t.pumpAndSettle();
        expect(find.text('GoodbyePublic'), findsOneWidget);
        expect(OmniRoute.location.path, '/goodbye');
      },
    );

    testWidgets(
      'custom OmniApp(config:, builder:) supports alwaysShow & direct completeOnboarding(redirectTo:)',
      (t) async {
        await t.pumpWidget(
          OmniApp(
            config: OmniConfig(
              onboarding: OmniOnboarding(
                alwaysShow: true,
                shouldShow: (_) => false,
                builder: (_, flow) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        flow.completeOnboarding(redirectTo: '/guest'),
                    child: const Text('CustomBuilderOB'),
                  ),
                ),
              ),
              publicScreens: const {
                '/guest': S('GuestLand'),
              },
            ),
            routes: [OmniPage('/', (_) => const S('BuilderHome'))],
            builder: (_, router) => MaterialApp.router(routerConfig: router),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('CustomBuilderOB'), findsOneWidget);

        await t.tap(find.text('CustomBuilderOB'));
        await t.pumpAndSettle();
        expect(find.text('GuestLand'), findsOneWidget);
      },
    );

    testWidgets(
      'auto local DB persistence: onceUntilLoginScreen saves on Login screen entry, survives background kill & resetOnboarding restores',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final authed = ValueNotifier<bool>(false);
        addTearDown(authed.dispose);

        Widget buildApp() => OmniApp.material(
          key: UniqueKey(),
          config: OmniConfig(
            onboarding: OmniOnboarding(
              mode: OmniOnboardingMode.onceUntilLoginScreen,
              screens: [
                Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('Install-Slide-1'),
                        TextButton(
                          onPressed: () => ctx.flow?.nextOnboarding(),
                          child: const Text('ObNext'),
                        ),
                        TextButton(
                          onPressed: () => ctx.flow?.goToLogin(),
                          child: const Text('JumpToLogin'),
                        ),
                      ],
                    ),
                  ),
                ),
                const S('Install-Slide-2'),
              ],
            ),
            auth: OmniAuth(
              isAuthenticated: (_) => authed.value,
              refreshListenable: authed,
              homeRoute: '/home',
              loginScreen: Builder(
                builder: (ctx) => Scaffold(
                  body: Column(
                    children: [
                      const Text('AutoLoginScreen'),
                      TextButton(
                        onPressed: () => ctx.flow?.resetOnboarding(replay: true),
                        child: const Text('ResetOB'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          routes: [OmniPage('/home', (_) => const S('HomeAfterAuto'))],
        );

        // 1. Fresh install -> shows Onboarding Slide 1.
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('Install-Slide-1'), findsOneWidget);

        // 2. Kill app BEFORE entering Login screen -> reopen MUST still show Onboarding.
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('Install-Slide-1'), findsOneWidget);

        // 3. Enter Login screen (without actually logging in!) -> auto-persisted to local DB.
        await t.tap(find.text('JumpToLogin'));
        await t.pumpAndSettle();
        expect(find.text('AutoLoginScreen'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('omni_route.onboarding.default.done'), isTrue);

        // 4. Clear app from background & reopen -> Onboarding MUST NOT show; opens Login directly.
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('Install-Slide-1'), findsNothing);
        expect(find.text('AutoLoginScreen'), findsOneWidget);

        // 5. resetOnboarding clears local DB flag and replays immediately when replay: true.
        await t.tap(find.text('ResetOB'));
        await t.pumpAndSettle();
        expect(find.text('Install-Slide-1'), findsOneWidget);
        expect(prefs.getBool('omni_route.onboarding.default.done'), isNull);
      },
    );

    testWidgets(
      'auto local DB persistence: untilLoggedIn keeps showing across restarts until user actually logs in',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final authed = ValueNotifier<bool>(false);
        addTearDown(authed.dispose);

        Widget buildApp() => OmniApp.material(
          key: UniqueKey(),
          config: OmniConfig(
            onboarding: OmniOnboarding(
              mode: OmniOnboardingMode.untilLoggedIn,
              screens: [
                Builder(
                  builder: (ctx) => Scaffold(
                    body: Column(
                      children: [
                        const Text('UntilLogin-Slide'),
                        TextButton(
                          onPressed: () => ctx.flow?.completeOnboarding(),
                          child: const Text('FinishSlide'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            auth: OmniAuth(
              isAuthenticated: (_) => authed.value,
              refreshListenable: authed,
              homeRoute: '/home',
              loginScreen: Builder(
                builder: (_) => Scaffold(
                  body: Column(
                    children: [
                      const Text('LoginGate'),
                      TextButton(
                        onPressed: () => authed.value = true,
                        child: const Text('PerformLogin'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          routes: [OmniPage('/home', (_) => const S('LoggedInHome'))],
        );

        // 1. First open -> Onboarding -> finish to Login screen (NOT logged in yet).
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('UntilLogin-Slide'), findsOneWidget);

        await t.tap(find.text('FinishSlide'));
        await t.pumpAndSettle();
        expect(find.text('LoginGate'), findsOneWidget);

        // 2. Kill app before logging in -> reopen MUST show Onboarding AGAIN!
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('UntilLogin-Slide'), findsOneWidget);

        // 3. Finish Onboarding -> now perform actual Login -> auto-saved to local DB!
        await t.tap(find.text('FinishSlide'));
        await t.pumpAndSettle();
        await t.tap(find.text('PerformLogin'));
        await t.pumpAndSettle();
        expect(find.text('LoggedInHome'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('omni_route.onboarding.default.done'), isTrue);

        // 4. Kill app & reopen later (even if session expired / logged out) -> Onboarding skips!
        authed.value = false;
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildApp());
        await t.pumpAndSettle();
        expect(find.text('UntilLogin-Slide'), findsNothing);
        expect(find.text('LoginGate'), findsOneWidget);
      },
    );

    testWidgets(
      'developer controls: enabled: false disables onboarding cleanly, persist: false ignores storage, & custom OmniLocalStore works',
      (t) async {
        // 1. enabled: false suppresses Onboarding completely even with screens defined.
        await t.pumpWidget(
          OmniApp.material(
            key: UniqueKey(),
            config: OmniConfig(
              onboarding: const OmniOnboarding(
                enabled: false,
                screens: [S('DisabledSlide')],
              ),
            ),
            routes: [OmniPage('/', (_) => const S('DirectMainApp'))],
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('DisabledSlide'), findsNothing);
        expect(find.text('DirectMainApp'), findsOneWidget);

        // 2. custom OmniLocalStore + persist: false control.
        final customDb = _InMemoryLocalStore();

        Widget buildCustomStoreApp({required bool persist}) => OmniApp.material(
          key: UniqueKey(),
          config: OmniConfig(
            onboarding: OmniOnboarding(
              persist: persist,
              storageKey: 'v2',
              storage: customDb,
              screens: [
                Builder(
                  builder: (ctx) => Scaffold(
                    body: TextButton(
                      onPressed: () => ctx.flow?.completeOnboarding(),
                      child: const Text('CustomDbObDone'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          routes: [OmniPage('/', (_) => const S('MainAfterCustomDb'))],
        );

        // persist: false does not save in customDb -> re-shows after restart.
        await t.pumpWidget(buildCustomStoreApp(persist: false));
        await t.pumpAndSettle();
        await t.tap(find.text('CustomDbObDone'));
        await t.pumpAndSettle();
        expect(customDb.data, isEmpty);

        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildCustomStoreApp(persist: false));
        await t.pumpAndSettle();
        expect(find.text('CustomDbObDone'), findsOneWidget);

        // persist: true saves under storageKey 'v2' in customDb -> skips next open!
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildCustomStoreApp(persist: true));
        await t.pumpAndSettle();
        await t.tap(find.text('CustomDbObDone'));
        await t.pumpAndSettle();
        expect(customDb.data['omni_route.onboarding.v2.done'], isTrue);

        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(buildCustomStoreApp(persist: true));
        await t.pumpAndSettle();
        expect(find.text('CustomDbObDone'), findsNothing);
        expect(find.text('MainAfterCustomDb'), findsOneWidget);
      },
    );
  });
}

class _InMemoryLocalStore implements OmniLocalStore {
  final Map<String, bool> data = {};

  @override
  Future<bool?> getBool(String key) async => data[key];

  @override
  Future<void> setBool(String key, bool value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

class _GreetingService {
  const _GreetingService(this.greeting);
  final String greeting;
}

class _GreetingBloc extends Cubit<String> {
  _GreetingBloc(super.initialState);
}

class _GreetingScreen extends StatelessWidget {
  const _GreetingScreen();
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text(context.read<_GreetingBloc>().state));
}

class FormScreen extends OmniStatelessWidget {
  const FormScreen({super.key});
  @override
  String get routePath => '/form';
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
  String get routePath => '/boom';
  @override
  Widget build(BuildContext context) => throw StateError('boom');
}

bool fieldFocused(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
