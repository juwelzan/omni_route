import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class StudentScreen extends OmniStatelessWidget {
  const StudentScreen({super.key, this.label = 'a'});
  final String label;
  static int builds = 0;
  @override
  String get routePath => '/students';
  @override
  Widget build(BuildContext context) {
    builds++;
    return Text(label, textDirection: TextDirection.ltr);
  }
}

class EmptyPathScreen extends OmniStatelessWidget {
  const EmptyPathScreen({super.key});
  @override
  String get routePath => '  ';
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class InvalidPathScreen extends OmniStatelessWidget {
  const InvalidPathScreen({super.key});
  @override
  String get routePath => '/Invalid Path';
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class DashboardScreen extends OmniStatefulWidget {
  const DashboardScreen({super.key, this.label = 'a'});
  final String label;
  @override
  String get routePath => '/dashboard';
  @override
  String get title => 'Home';
  @override
  State<DashboardScreen> createState() => _DashboardState();
}

final events = <String>[];

class _DashboardState extends OmniState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    events.add('init:${metadata.routePath}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    events.add('deps');
  }

  @override
  void didUpdateWidget(DashboardScreen old) {
    super.didUpdateWidget(old);
    events.add('update:${old.label}->${widget.label}');
  }

  @override
  void dispose() {
    events.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.label, textDirection: TextDirection.ltr);
}

// ── Page-entry Bloc + OmniState upgrade fixtures ───────────────────────────

class LazyPageCubit extends Cubit<int> {
  LazyPageCubit(this.initial, {required this.onCreate, required this.onClose})
    : super(initial) {
    onCreate();
  }
  final int initial;
  final VoidCallback onCreate;
  final VoidCallback onClose;
  void inc() => emit(state + 1);
  @override
  Future<void> close() {
    onClose();
    return super.close();
  }
}

class GlobalSessionCubit extends Cubit<String> {
  GlobalSessionCubit() : super('ok');
}

class _LazyStatelessScreen extends OmniStatelessWidget {
  const _LazyStatelessScreen({
    required this.onCreate,
    required this.onClose,
    required this.onRegistryCheck,
  });
  final VoidCallback onCreate;
  final VoidCallback onClose;
  final void Function(OmniBlocRegistry) onRegistryCheck;

  @override
  String get routePath => '/lazy-stateless';

  @override
  List<Provide> get provide => [
    Provide.blocEager(
      (_) => LazyPageCubit(7, onCreate: onCreate, onClose: onClose),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    onRegistryCheck(OmniGlobalBlocScope.registryOf(context));
    final v = context.watch<LazyPageCubit>().state;
    final modalName = ModalRoute.of(context)?.settings.name;
    return Text('lazy:$v:$modalName');
  }
}

class _HomeRootScreen extends OmniStatelessWidget {
  const _HomeRootScreen({this.onRegistryCheck});
  final void Function(OmniBlocRegistry)? onRegistryCheck;
  @override
  String get routePath => '/';
  @override
  Widget build(BuildContext context) {
    onRegistryCheck?.call(OmniGlobalBlocScope.registryOf(context));
    return const Text('root-home');
  }
}

class _NestedChildScreen extends OmniStatelessWidget {
  const _NestedChildScreen();
  @override
  String get routePath => '/settings/profile-details';
  @override
  Widget build(BuildContext context) =>
      Text('nested:${context.routePath}:$title');
}

class _SettingsParentScreen extends OmniStatelessWidget {
  const _SettingsParentScreen();
  @override
  String get routePath => '/settings';
  @override
  Widget build(BuildContext context) => const Text('settings-parent');
}

class _UnhostedLifecycleScreen extends OmniStatelessWidget
    with OmniLifecycle {
  const _UnhostedLifecycleScreen({required this.log});
  final List<String> log;

  @override
  String get routePath => '/unhosted-feed';

  @override
  List<Provide> get provide => [
    Provide.bloc((_) => GlobalSessionCubit()),
  ];

  @override
  void onScreenVisible(BuildContext context) {
    log.add('visible:${context.read<GlobalSessionCubit>().state}');
  }

  @override
  void onAppResumed(BuildContext context) {
    log.add('resumed:${context.read<GlobalSessionCubit>().state}');
  }

  @override
  Widget build(BuildContext context) => Text('feed:${context.bloc<GlobalSessionCubit>().state}');
}

class _StatefulUpgradesScreen extends OmniStatefulWidget {
  const _StatefulUpgradesScreen({required this.log});
  final List<String> log;

  @override
  String get routePath => '/items/:id';

  @override
  List<Provide> get provide => [
    Provide.bloc((c) => LazyPageCubit(
      OmniParams.of(c).pathInt('id'),
      onCreate: () => log.add('cubit:create'),
      onClose: () => log.add('cubit:close'),
    )),
  ];

  @override
  State<_StatefulUpgradesScreen> createState() => _StatefulUpgradesState();
}

class _StatefulUpgradesState extends OmniState<_StatefulUpgradesScreen> {
  late final String initRoutePath;
  late final String initParamId;

  @override
  void initState() {
    super.initState();
    // Both routeState and params must work safely inside initState!
    initRoutePath = routeState.routePath ?? 'missing';
    initParamId = params.path('id');
    widget.log.add('init:$initRoutePath:$initParamId:${readBloc<LazyPageCubit>().state}');
  }

  @override
  void onReady(BuildContext context) {
    widget.log.add('ready:$routePath:$screenTitle');
    safeSetState(() {});
  }

  @override
  void onRouteChanged(OmniRouteState previous, OmniRouteState current) {
    widget.log.add(
      'changed:${previous.uri.queryParameters['tab']}->${current.uri.queryParameters['tab']}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = params.query('tab') ?? 'none';
    final count = watchBloc<LazyPageCubit>().state;
    return Column(
      children: [
        Text('state:$routePath:$count:$tab:${maybeParams?.path('id')}'),
        TextButton(
          onPressed: () => readBloc<LazyPageCubit>().inc(),
          child: const Text('inc'),
        ),
        TextButton(
          onPressed: () => pop('done'),
          child: const Text('close'),
        ),
      ],
    );
  }
}

void main() {
  setUp(events.clear);

  group('OmniStatelessWidget', () {
    test('metadata and routePath defaults', () {
      const s = StudentScreen();
      expect(s.routePath, '/students');
      expect(s.title, 'Students');
      expect(s.debugName, 'StudentScreen');
      expect(s.metadata.type, StudentScreen);
      expect(s.metadata.routePath, '/students');
      expect(s.metadata, const StudentScreen(label: 'b').metadata);

      const child = _NestedChildScreen();
      expect(child.title, 'Profile Details');
      expect(const _HomeRootScreen().title, 'Home');
    });

    test('resolvePath formats :params and query cleanly', () {
      final s = _StatefulUpgradesScreen(log: const []);
      expect(
        s.resolvePath(path: {'id': 42}, query: {'tab': 'bio'}),
        '/items/42?tab=bio',
      );
    });

    testWidgets('builds and rebuilds like StatelessWidget', (t) async {
      StudentScreen.builds = 0;
      await t.pumpWidget(const StudentScreen(label: 'one'));
      expect(find.text('one'), findsOneWidget);
      await t.pumpWidget(const StudentScreen(label: 'two'));
      expect(find.text('two'), findsOneWidget);
      expect(StudentScreen.builds, 2);
    });

    testWidgets('empty routePath throws emptyRoutePath', (t) async {
      await t.pumpWidget(const EmptyPathScreen());
      final e = t.takeException();
      expect(
        e,
        isA<OmniRouteException>().having(
          (e) => e.code,
          'code',
          OmniErrorCode.emptyRoutePath,
        ),
      );
    });

    testWidgets('invalid routePath throws invalidRoutePath', (t) async {
      await t.pumpWidget(const InvalidPathScreen());
      final e = t.takeException();
      expect(
        e,
        isA<OmniRouteException>().having(
          (e) => e.code,
          'code',
          OmniErrorCode.invalidRoutePath,
        ),
      );
    });

    testWidgets('unhosted OmniLifecycle + provide can read provided Blocs', (
      t,
    ) async {
      final log = <String>[];
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: _UnhostedLifecycleScreen(log: log),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('feed:ok'), findsOneWidget);
      expect(log, contains('visible:ok'));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(log, contains('resumed:ok'));
    });
  });

  group('OmniStatefulWidget & OmniState', () {
    test('metadata with custom title', () {
      const d = DashboardScreen();
      expect(d.metadata.routePath, '/dashboard');
      expect(d.metadata.title, 'Home');
      expect(d.metadata.type, DashboardScreen);
    });

    testWidgets('follows Flutter State lifecycle and maybeRouteState outside route', (
      t,
    ) async {
      await t.pumpWidget(const DashboardScreen(label: 'a'));
      await t.pumpWidget(const DashboardScreen(label: 'b'));
      await t.pumpWidget(const SizedBox());
      expect(events, ['init:/dashboard', 'deps', 'update:a->b', 'dispose']);
    });

    testWidgets(
      'OmniState provides initState-safe params/routeState, onReady, onRouteChanged, bloc & safeSetState',
      (t) async {
        final log = <String>[];
        final themeColor = ValueNotifier<Color>(Colors.blue);
        addTearDown(themeColor.dispose);

        await t.pumpWidget(
          ValueListenableBuilder<Color>(
            valueListenable: themeColor,
            builder: (_, color, _) => OmniApp(
              initialRoute: '/items/5?tab=a',
              routes: [
                const OmniPage.screen(_HomeRootScreen()),
                OmniPage<_StatefulUpgradesScreen>(
                  '/items/:id',
                  (_) => _StatefulUpgradesScreen(log: log),
                ),
              ],
              builder: (_, r) => MaterialApp.router(
                routerConfig: r,
                theme: ThemeData(colorSchemeSeed: color),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('state:/items/:id:5:a:5'), findsOneWidget);
        expect(log, contains('cubit:create'));
        expect(log, contains('init:/items/:id:5:5'));
        expect(log, contains('ready:/items/:id:Items'));

        // Unrelated theme update should NOT trigger onRouteChanged.
        log.clear();
        themeColor.value = Colors.red;
        await t.pumpAndSettle();
        expect(log.where((e) => e.startsWith('changed:')), isEmpty);

        // Changing query triggers onRouteChanged cleanly.
        OmniRoute.goPath('/items/:id', path: {'id': 5}, query: {'tab': 'b'});
        await t.pumpAndSettle();
        expect(find.text('state:/items/:id:5:b:5'), findsOneWidget);
        expect(log, ['changed:a->b']);

        await t.tap(find.text('inc'));
        await t.pumpAndSettle();
        expect(find.text('state:/items/:id:6:b:5'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
        expect(log, contains('cubit:close'));
      },
    );

    testWidgets('hosted() helper mounts stateful screen with Blocs cleanly', (
      t,
    ) async {
      final log = <String>[];
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: const _NestedScreenWithBloc().hosted(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('hosted:42'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(log, isEmpty);
    });
  });

  group('routePath unification & page-entry Bloc registration', () {
    testWidgets(
      'OmniPage.screen registers routePath, nested full paths, and page Blocs on first entry only',
      (t) async {
        var cubitCreated = 0;
        var cubitClosed = 0;
        OmniBlocRegistry? capturedRegistry;

        await t.pumpWidget(
          OmniApp(
            routes: [
              OmniPage.screen(
                _HomeRootScreen(onRegistryCheck: (r) => capturedRegistry = r),
              ),
              OmniPage(
                '/lazy-stateless',
                (_) => _LazyStatelessScreen(
                  onCreate: () => cubitCreated++,
                  onClose: () => cubitClosed++,
                  onRegistryCheck: (r) => capturedRegistry = r,
                ),
              ),
              const OmniPage.screen(
                _SettingsParentScreen(),
                routes: [OmniPage.screen(_NestedChildScreen())],
              ),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();

        // Before entering /lazy-stateless, its BlocProvider is NOT registered or created.
        expect(find.text('root-home'), findsOneWidget);
        expect(cubitCreated, 0);
        expect(capturedRegistry!.isRegistered<LazyPageCubit>(), isFalse);
        expect(OmniRoute.routePath, '/');
        expect(OmniRoute.current.routePath, '/');
        expect(OmniRoute.hasRoute('/settings/profile-details'), isTrue);

        // Entering /lazy-stateless registers & mounts the BlocProvider on entry.
        OmniRoute.push('/lazy-stateless');
        await t.pumpAndSettle();
        expect(find.text('lazy:7:/lazy-stateless'), findsOneWidget);
        expect(cubitCreated, 1);
        expect(cubitClosed, 0);
        expect(capturedRegistry!.isRegistered<LazyPageCubit>(), isTrue);
        expect(OmniRoute.routePath, '/lazy-stateless');
        expect(OmniRoute.current.routePath, '/lazy-stateless');

        // Leaving closes the page-scoped Bloc.
        OmniRoute.pop();
        await t.pumpAndSettle();
        expect(cubitClosed, 1);

        // Nested child screen declaring full routePath under /settings compiles cleanly.
        OmniRoute.goPath('/settings/profile-details');
        await t.pumpAndSettle();
        expect(
          find.text('nested:/settings/profile-details:Profile Details'),
          findsOneWidget,
        );
        expect(OmniRoute.current.routePath, '/settings/profile-details');
      },
    );

    testWidgets(
      'OmniPage(blocs: [...]) registers & creates page Bloc only when page is entered',
      (t) async {
        var pageCreated = 0;
        var pageClosed = 0;
        OmniBlocRegistry? reg;

        await t.pumpWidget(
          OmniApp(
            routes: [
              OmniPage.screen(
                _HomeRootScreen(onRegistryCheck: (r) => reg = r),
              ),
              OmniPage(
                '/page-bloc',
                (_) => Builder(
                  builder: (c) => Text('pb:${c.bloc<LazyPageCubit>().state}'),
                ),
                blocs: [
                  OmniBloc.eager(
                    (_) => LazyPageCubit(
                      99,
                      onCreate: () => pageCreated++,
                      onClose: () => pageClosed++,
                    ),
                  ),
                ],
              ),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();

        expect(pageCreated, 0);
        expect(reg!.isRegistered<LazyPageCubit>(), isFalse);

        OmniRoute.pushPath('/page-bloc');
        await t.pumpAndSettle();
        expect(find.text('pb:99'), findsOneWidget);
        expect(pageCreated, 1);
        expect(reg!.isRegistered<LazyPageCubit>(), isTrue);

        OmniRoute.pop();
        await t.pumpAndSettle();
        expect(pageClosed, 1);
      },
    );

    testWidgets(
      'OmniApp(blocs:) infers concrete global Bloc type without generic arg',
      (t) async {
        await t.pumpWidget(
          OmniApp(
            blocs: [OmniBloc((_) => GlobalSessionCubit(), global: true)],
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (c) => Text('sess:${c.bloc<GlobalSessionCubit>().state}'),
                ),
              ),
            ],
            builder: (_, r) => MaterialApp.router(routerConfig: r),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('sess:ok'), findsOneWidget);
      },
    );
  });
}

class _FixedIntCubit extends Cubit<int> {
  _FixedIntCubit() : super(42);
}

class _NestedScreenWithBloc extends OmniStatefulWidget {
  const _NestedScreenWithBloc();
  @override
  String get routePath => '/nested-hosted';
  @override
  List<Provide> get provide => [Provide.bloc((_) => _FixedIntCubit())];
  @override
  State<_NestedScreenWithBloc> createState() => _NestedScreenWithBlocState();
}

class _NestedScreenWithBlocState extends OmniState<_NestedScreenWithBloc> {
  late final int initialVal;
  @override
  void initState() {
    super.initState();
    initialVal = readBloc<_FixedIntCubit>().state;
  }

  @override
  Widget build(BuildContext context) => Text('hosted:$initialVal');
}
