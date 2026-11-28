import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class _PageView extends StatelessWidget {
  const _PageView(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

class _DummyCubit extends Cubit<int> {
  _DummyCubit(super.initialState);
}

class _ChildScreen extends OmniStatelessWidget {
  const _ChildScreen();

  @override
  String get routePath => '/child';

  @override
  Widget build(BuildContext context) => const _PageView('child-screen');
}

void main() {
  group('Async & sync guard error handling', () {
    testWidgets(
      'sync allow, sync redirect, async allow, async redirect & ordering',
      (t) async {
        final order = <String>[];
        await t.pumpWidget(
          OmniApp(
            transition: OmniPages.none,
            guards: [
              OmniGuard.fn((c, s) {
                order.add('sync:${s.matchedLocation}');
                if (s.matchedLocation == '/sync-redir') return '/target';
                return null;
              }),
              OmniGuard.fn((c, s) async {
                await Future<void>.delayed(Duration.zero);
                order.add('async:${s.matchedLocation}');
                if (s.matchedLocation == '/async-redir') return '/target';
                return null;
              }),
            ],
            routes: [
              OmniPage('/', (_) => const _PageView('home')),
              OmniPage('/sync-redir', (_) => const _PageView('sync-redir')),
              OmniPage('/async-redir', (_) => const _PageView('async-redir')),
              OmniPage('/target', (_) => const _PageView('target')),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('home'), findsOneWidget);
        expect(order, ['sync:/', 'async:/']);

        order.clear();
        OmniRoute.go('/sync-redir');
        await t.pumpAndSettle();
        expect(find.text('target'), findsOneWidget);
        // Async guard did NOT run for `/sync-redir` because sync guard redirected first.
        expect(order, ['sync:/sync-redir', 'sync:/target', 'async:/target']);

        order.clear();
        final pushFuture = OmniRoute.push<Object?>('/async-redir');
        await t.pumpAndSettle();
        expect(find.text('target'), findsOneWidget);
        OmniRoute.pop('done');
        await t.pumpAndSettle();
        expect(await pushFuture, 'done');
      },
    );

    testWidgets('sync throw & async throw route to error page cleanly', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          notFound: (_, s, err) => _PageView('err:${s.matchedLocation}:$err'),
          guards: [
            OmniGuard.fn((c, s) {
              if (s.matchedLocation == '/sync-boom') {
                throw StateError('sync guard boom');
              }
              return null;
            }),
            OmniGuard.fn((c, s) async {
              await Future<void>.delayed(Duration.zero);
              if (s.matchedLocation == '/async-boom') {
                throw StateError('async guard boom');
              }
              return null;
            }),
          ],
          routes: [
            OmniPage('/', (_) => const _PageView('home')),
            OmniPage('/sync-boom', (_) => const _PageView('sync-boom')),
            OmniPage('/async-boom', (_) => const _PageView('async-boom')),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      final f1 = OmniRoute.push<Object?>('/sync-boom');
      await t.pumpAndSettle();
      expect(find.textContaining('sync guard boom'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(await f1, isNull);

      final f2 = OmniRoute.push<Object?>('/async-boom');
      await t.pumpAndSettle();
      expect(find.textContaining('async guard boom'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(await f2, isNull);
    });

    testWidgets(
      'async guard timeout & initial guard failure do not stall app',
      (t) async {
        await t.pumpWidget(
          OmniApp(
            transition: OmniPages.none,
            guardTimeout: const Duration(milliseconds: 20),
            initialRoute: '/hang',
            notFound: (_, _, err) => _PageView('init-err:$err'),
            guards: [
              OmniGuard.fn((c, s) {
                if (s.matchedLocation == '/hang') {
                  return Completer<String?>().future;
                }
                return null;
              }),
            ],
            routes: [
              OmniPage('/', (_) => const _PageView('home')),
              OmniPage('/hang', (_) => const _PageView('hang')),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pump(const Duration(milliseconds: 40));
        await t.pumpAndSettle();
        expect(find.textContaining('TimeoutException'), findsOneWidget);
      },
    );

    testWidgets('invalid redirect URI fails safely and routes to error page', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          notFound: (_, _, err) => _PageView('bad-redir:$err'),
          guards: [
            OmniGuard.fn((c, s) async {
              await Future<void>.delayed(Duration.zero);
              if (s.matchedLocation == '/bad') return 'http://[::1';
              return null;
            }),
          ],
          routes: [
            OmniPage('/', (_) => const _PageView('home')),
            OmniPage('/bad', (_) => const _PageView('bad')),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      final f = OmniRoute.push<Object?>('/bad');
      await t.pumpAndSettle();
      expect(find.textContaining('bad-redir:'), findsOneWidget);
      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(await f, isNull);
    });

    testWidgets(
      'simultaneous push superseded completes unresolved future cleanly',
      (t) async {
        final gate = Completer<String?>();
        await t.pumpWidget(
          OmniApp(
            transition: OmniPages.none,
            guards: [
              OmniGuard.fn((c, s) {
                if (s.matchedLocation == '/slow') return gate.future;
                return null;
              }),
            ],
            routes: [
              OmniPage('/', (_) => const _PageView('home')),
              OmniPage('/slow', (_) => const _PageView('slow')),
              OmniPage('/fast', (_) => const _PageView('fast')),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();

        final slowFuture = OmniRoute.push<Object?>('/slow');
        // Immediately supersede while `/slow` guard is still pending.
        OmniRoute.go('/fast');
        await t.pumpAndSettle();

        expect(find.text('fast'), findsOneWidget);
        expect(await slowFuture, isNull);
        // Completing gate late is safely ignored.
        gate.complete(null);
        await t.pumpAndSettle();
        expect(find.text('fast'), findsOneWidget);
      },
    );

    testWidgets(
      'query-stripping redirect is honored; async redirect loop caught',
      (t) async {
        await t.pumpWidget(
          OmniApp(
            transition: OmniPages.none,
            notFound: (_, _, err) => _PageView('loop:$err'),
            guards: [
              OmniGuard.fn((c, s) {
                if (s.matchedLocation == '/search' && s.uri.query.isNotEmpty) {
                  return '/search';
                }
                return null;
              }),
              OmniGuard.fn((c, s) async {
                await Future<void>.delayed(Duration.zero);
                if (s.matchedLocation == '/a') return '/b';
                if (s.matchedLocation == '/b') return '/a';
                return null;
              }),
            ],
            routes: [
              OmniPage('/', (_) => const _PageView('home')),
              OmniPage('/search', (p) => _PageView('search:${p.query('q')}')),
              OmniPage('/a', (_) => const _PageView('a')),
              OmniPage('/b', (_) => const _PageView('b')),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();

        OmniRoute.go('/search?q=1');
        await t.pumpAndSettle();
        expect(find.text('search:null'), findsOneWidget);

        OmniRoute.go('/a');
        await t.pumpAndSettle();
        expect(find.textContaining('loop:OmniRouteException'), findsOneWidget);
      },
    );

    testWidgets('guard refresh stream errors do not escape uncaught', (
      t,
    ) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          guards: [OmniGuard.fn((_, _) => null, refresh: (_) => ctrl.stream)],
          routes: [OmniPage('/', (_) => const _PageView('home'))],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      final reported = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = prev);

      ctrl.addError(StateError('stream hiccup'));
      await t.pump();
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
    });
  });

  group('Navigation lifecycle, dialogs & pop safety', () {
    testWidgets('onExit on root page never empties Navigator.pages', (t) async {
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          routes: [
            OmniPage(
              '/',
              (_) => const _PageView('root'),
              onExit: (_) async => true,
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      final nav = t.widget<Navigator>(find.byType(Navigator).first);
      expect(nav.pages, isNotEmpty);
    });

    testWidgets('maybePop honors OmniPage.onExit', (t) async {
      var exitCalls = 0;
      var allow = false;
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          routes: [
            OmniPage('/', (_) => const _PageView('home')),
            OmniPage(
              '/edit',
              (_) => const _PageView('edit'),
              onExit: (_) async {
                exitCalls++;
                return allow;
              },
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      OmniRoute.push('/edit');
      await t.pumpAndSettle();

      expect(OmniRoute.maybePop(), isTrue);
      await t.pumpAndSettle();
      expect(exitCalls, 1);
      expect(find.text('edit'), findsOneWidget);

      allow = true;
      expect(OmniRoute.maybePop(), isTrue);
      await t.pumpAndSettle();
      expect(exitCalls, 2);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('popRoute closes root dialog before shell branch page', (
      t,
    ) async {
      late OmniNavigationShell shell;
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          initialRoute: '/tab1',
          routes: [
            OmniStatefulShell(
              builder: (_, _, s) {
                shell = s;
                return Scaffold(body: s);
              },
              branches: [
                OmniBranch(
                  routes: [
                    OmniPage('/tab1', (_) => const _PageView('tab1-root')),
                    OmniPage('/tab1/sub', (_) => const _PageView('tab1-sub')),
                  ],
                ),
                OmniBranch(
                  routes: [
                    OmniPage('/tab2', (_) => const _PageView('tab2-root')),
                  ],
                ),
              ],
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      OmniRoute.push('/tab1/sub');
      await t.pumpAndSettle();
      expect(find.text('tab1-sub'), findsOneWidget);

      final ctx = t.element(find.text('tab1-sub'));
      unawaited(
        showDialog<void>(
          context: ctx,
          useRootNavigator: true,
          builder: (_) => const AlertDialog(title: Text('root-dialog')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('root-dialog'), findsOneWidget);

      // First back closes root dialog, NOT `tab1-sub`.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('root-dialog'), findsNothing);
      expect(find.text('tab1-sub'), findsOneWidget);

      // Second back pops `tab1-sub`.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('tab1-root'), findsOneWidget);
      expect(shell.currentIndex, 0);
    });

    testWidgets('branch switch enforces guards & shell clear finishes futures', (
      t,
    ) async {
      late OmniNavigationShell shell;
      var blockTab2 = true;
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          initialRoute: '/tab1',
          guards: [
            OmniGuard.fn((_, s) {
              if (blockTab2 && s.matchedLocation == '/tab2') return '/login';
              return null;
            }),
          ],
          routes: [
            OmniPage('/login', (_) => const _PageView('login')),
            OmniStatefulShell(
              builder: (_, _, s) {
                shell = s;
                return Scaffold(body: s);
              },
              branches: [
                OmniBranch(
                  routes: [
                    OmniPage('/tab1', (_) => const _PageView('tab1')),
                    OmniPage('/tab1/detail', (_) => const _PageView('detail')),
                  ],
                ),
                OmniBranch(
                  routes: [OmniPage('/tab2', (_) => const _PageView('tab2'))],
                ),
              ],
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      final pendingDetail = OmniRoute.push<Object?>('/tab1/detail');
      await t.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      // Attempting protected tab switch redirects to /login and resolves pushed future!
      shell.goBranch(1);
      await t.pumpAndSettle();
      expect(find.text('login'), findsOneWidget);
      expect(await pendingDetail, isNull);

      blockTab2 = false;
      OmniRoute.go('/tab1');
      await t.pumpAndSettle();
      shell.goBranch(1);
      await t.pumpAndSettle();
      expect(find.text('tab2'), findsOneWidget);
    });

    testWidgets('post-dispose navigation calls are safe no-ops', (t) async {
      late OmniRouter router;
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          routes: [OmniPage('/', (_) => const _PageView('home'))],
          builder: (_, r) {
            router = r;
            return MaterialApp.router(routerConfig: r);
          },
        ),
      );
      await t.pumpAndSettle();

      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();

      expect(router.isDisposed, isTrue);
      router.go('/other');
      expect(await router.push('/other'), isNull);
      router.replace('/other');
      expect(await router.open('/other'), isNull);
      expect(await router.popUntil('/'), isFalse);
      expect(router.maybePop(), isFalse);
    });
  });

  group('Route compilation, wildcards, groups & onboarding', () {
    testWidgets('wildcards and root-nested child OmniScreen compile cleanly', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          routes: [
            OmniPage(
              '/',
              (_) => const _PageView('home'),
              routes: [OmniPage.screen(const _ChildScreen())],
            ),
            OmniPage(
              '/files/*rest',
              (p) => _PageView('file:${p.path('rest')}'),
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      OmniRoute.go('/child');
      await t.pumpAndSettle();
      expect(find.text('child-screen'), findsOneWidget);

      OmniRoute.go('/files/a/b/c.png');
      await t.pumpAndSettle();
      expect(find.text('file:a/b/c.png'), findsOneWidget);
    });

    test('duplicate ancestor/child param name & global page bloc rejected', () {
      expect(
        () => OmniApp.validateRoutes([
          OmniPage(
            '/org/:id',
            (_) => const SizedBox.shrink(),
            routes: [OmniPage(':id', (_) => const SizedBox.shrink())],
          ),
        ]),
        throwsA(isA<OmniRouteException>()),
      );

      final reg = OmniBlocRegistry(const []);
      expect(
        () => reg.registerPageBlocs([
          OmniBloc<_DummyCubit>((_) => _DummyCubit(0), global: true),
        ]),
        throwsA(
          isA<OmniRouteException>().having(
            (e) => e.code,
            'code',
            OmniErrorCode.unsupportedConfiguration,
          ),
        ),
      );
    });

    testWidgets('OmniRouteGroup routes OmniParams errors to errorBuilder', (
      t,
    ) async {
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          initialRoute: '/items/not-a-number',
          notFound: (_, _, e) => _PageView('group-err:$e'),
          routes: [
            OmniRouteGroup(
              provide: [
                Provide<_DummyCubit>.create(
                  (c) => _DummyCubit(OmniParams.of(c).pathInt('id')),
                ),
              ],
              routes: [OmniPage('/items/:id', (_) => const _PageView('ok'))],
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('group-err:OmniRouteException'),
        findsOneWidget,
      );
    });

    testWidgets('pushPublic opens public route during route-based onboarding', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(
        OmniApp(
          transition: OmniPages.none,
          config: OmniConfig(
            onboarding: const OmniOnboarding(routes: ['/ob/1']),
            publicPages: [OmniPage('/terms', (_) => const _PageView('terms'))],
          ),
          routes: [
            OmniPage('/', (_) => const _PageView('home')),
            OmniPage(
              '/ob/1',
              (_) => Builder(
                builder: (c) => TextButton(
                  onPressed: () => c.flow?.pushPublic('/terms'),
                  child: const Text('view-terms'),
                ),
              ),
            ),
          ],
          builder: (_, r) => MaterialApp.router(routerConfig: r),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.text('view-terms'));
      await t.pumpAndSettle();
      expect(find.text('terms'), findsOneWidget);

      OmniRoute.pop();
      await t.pumpAndSettle();
      expect(find.text('view-terms'), findsOneWidget);
    });
  });
}
