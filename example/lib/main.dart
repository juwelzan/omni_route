import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

import 'api_lab_screens.dart';

void main() {
  OmniRoute.usePathUrls();
  runApp(const ExampleApp());
}

// =============================================================================
// Separate Colored Bloc & Route Logger -> Terminal + OmniInspector
// =============================================================================

void _printSeparateBox({
  required String colorCode,
  required String header,
  String? detail,
}) {
  final rule = '─' * 60;
  final paint = '\x1B[${colorCode}m';
  const reset = '\x1B[0m';
  final lines = <String>[
    '$paint┌$rule$reset',
    '$paint│$reset $paint$header$reset',
    if (detail != null && detail.isNotEmpty) '$paint│$reset $detail',
    '$paint└$rule$reset',
  ];
  for (final l in lines) {
    debugPrint(l);
  }
}

class _ExampleBlocObserver extends BlocObserver {
  _ExampleBlocObserver({required this.printTerminal});

  final bool printTerminal;
  OmniInspector? inspector;

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    final name = bloc.runtimeType.toString();
    if (printTerminal && kDebugMode) {
      _printSeparateBox(
        colorCode: '38;5;78',
        header: '🟩 bloc-create · $name',
      );
    }
    scheduleMicrotask(() {
      inspector?.logBloc(
        'bloc-create',
        '$name created',
        kind: InspectorLogKind.blocCreate,
      );
    });
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final name = bloc.runtimeType.toString();
    final nextSummary = change.nextState.toString();
    if (printTerminal && kDebugMode && name != 'ApiLabCubit') {
      _printSeparateBox(
        colorCode: '38;5;43',
        header: '🔄 bloc-transition · $name',
        detail: 'nextState: $nextSummary',
      );
    }
    scheduleMicrotask(() {
      inspector?.logBloc(
        'bloc-transition',
        '$name state updated',
        kind: InspectorLogKind.blocTransition,
        subtitle: nextSummary,
        copyText: '[bloc-transition] $name\nfrom: ${change.currentState}\nto:   ${change.nextState}',
      );
    });
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    final name = bloc.runtimeType.toString();
    if (printTerminal && kDebugMode) {
      _printSeparateBox(
        colorCode: '38;5;196',
        header: '\x1B[1;38;5;15;48;5;196m ⛔ bloc-error · $name \x1B[0m',
        detail: '$error',
      );
    }
    scheduleMicrotask(() {
      inspector?.logError('$name error', subtitle: '$error');
    });
  }
}

// =============================================================================
// Domain + Global & Lazy-Registered Blocs
// =============================================================================

class AuthBloc extends Cubit<bool> {
  AuthBloc() : super(false);
  void logIn() => emit(true);
  void logOut() => emit(false);
}

class StudentBloc extends Cubit<List<int>> {
  StudentBloc() : super(const [101, 102, 103]);
}

class StudentDetailState {
  const StudentDetailState({
    required this.id,
    required this.name,
    this.hasUnsavedEdits = false,
  });

  final int id;
  final String name;
  final bool hasUnsavedEdits;
}

class StudentDetailBloc extends Cubit<StudentDetailState> {
  StudentDetailBloc(int id)
    : super(StudentDetailState(id: id, name: 'Student #$id'));

  void markDirty(bool dirty) {
    if (state.hasUnsavedEdits == dirty) return;
    emit(
      StudentDetailState(
        id: state.id,
        name: state.name,
        hasUnsavedEdits: dirty,
      ),
    );
  }

  void rename(String name) =>
      emit(StudentDetailState(id: state.id, name: name, hasUnsavedEdits: false));
}

class AttendanceBloc extends Cubit<bool> {
  AttendanceBloc() : super(false);
  void toggle() => emit(!state);
}

// =============================================================================
// Route Guard
// =============================================================================

class AuthGuard extends OmniGuard {
  const AuthGuard();

  @override
  Stream<Object?>? refresh(BuildContext context) =>
      context.read<AuthBloc>().stream;

  @override
  FutureOr<String?> redirect(
    BuildContext context,
    OmniRouteState state,
  ) {
    final loggedIn = context.read<AuthBloc>().state;
    final atLogin = state.uri.path == '/login';
    if (!loggedIn && !atLogin) {
      return Uri(
        path: '/login',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }
    if (loggedIn && atLogin) {
      return state.params.query('from') ?? '/dashboard';
    }
    return null;
  }
}

// =============================================================================
// Application Root
// =============================================================================

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, this.useLiveNetwork = true});

  /// Defaults to `true` so running the app calls real public developer APIs
  /// (JSONPlaceholder, DummyJSON, Open-Meteo, PokeAPI, Postman WS Echo).
  /// Hermetic widget tests pass `false` since Flutter's test binding blocks
  /// real sockets.
  final bool useLiveNetwork;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final _ExampleBlocObserver _blocObserver = _ExampleBlocObserver(
    printTerminal: widget.useLiveNetwork,
  );

  @override
  void dispose() {
    _blocObserver.inspector = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OmniApp.material(
      title: 'OmniRoute & OmniNetwork Example',
      screenMode: OmniScreenMode.edgeToEdge,
      orientation: OmniOrientation.portraitOnMobile,
      omniTheme: const OmniTheme(
        id: 'ocean',
        name: 'Ocean',
        seedColor: Color(0xFF2563EB),
        secondaryColor: Color(0xFF0EA5E9),
        statusBar: OmniStatusBarStyle.transparent(),
        systemNavigationBar: OmniSystemNavigationBarStyle.transparent(),
        light: OmniColorPalette(
          surfaceColor: Color(0xFFF8FAFC),
          cardColor: Colors.white,
        ),
        dark: OmniColorPalette(
          primaryColor: Color(0xFF3B82F6),
          secondaryColor: Color(0xFF38BDF8),
          surfaceColor: Color(0xFF0B1120),
          cardColor: Color(0xFF131C31),
        ),
        persistMode: true,
      ),
      themes: OmniTheme.presets,
      initialRoute: '/dashboard',
      transition: OmniPages.fadeSlide,
      guards: const [AuthGuard()],
      blocObserver: _blocObserver,
      logNavigation: false,
      onNavigate: (nav) {
        final from = nav.from?.location ?? '(start)';
        final to = nav.to.location;
        if (widget.useLiveNetwork && kDebugMode) {
          _printSeparateBox(
            colorCode: '38;5;141',
            header: '🧭 route (${nav.kind.name}) · $from -> $to',
            detail: 'uri: ${nav.uri}',
          );
        }
        scheduleMicrotask(() {
          _blocObserver.inspector?.logRoute(
            '[${nav.kind.name}] $from -> $to',
            subtitle: 'uri: ${nav.uri}',
            copyText:
                '[route:${nav.kind.name}]\nfrom: $from\nto:   $to\nuri:  ${nav.uri}',
          );
        });
      },
      appBuilder: (context, child) {
        final inspector = context.read<ApiLabCubit>().inspector;
        _blocObserver.inspector = inspector;
        return OmniInspectorLauncher(
          inspector: inspector,
          initialTab: InspectorTab.logs,
          child: child ?? const SizedBox.shrink(),
        );
      },
      blocs: [
        OmniBloc((_) => AuthBloc(), global: true),
        OmniBloc(
          (_) => ApiLabCubit(useLiveNetwork: widget.useLiveNetwork),
          global: true,
        ),
        // Classic pre-registered style kept alongside page-entry registration:
        OmniBloc((_) => ClassicStudentBloc()),
      ],
      routes: [
        OmniPage.screen(const LoginScreen()),
        OmniPage.screen(
          const ConfirmLogoutScreen(),
          transition: OmniPages.dialog(),
        ),
        OmniPage.screen(
          const ApiSheetScreen(),
          transition: OmniPages.bottomSheet(
            showDragHandle: true,
            isScrollControlled: true,
          ),
        ),
        // Classic string-based + named route style:
        OmniPage(
          '/classic-student/:id',
          (p) => ClassicStudentDetailScreen(id: p.pathInt('id')),
          name: 'classic_student',
          provide: const [Provide<ClassicStudentBloc>()],
        ),
        OmniStatefulShell(
          builder: (context, state, shell) => HomeShell(shell: shell),
          branches: [
            // Branch 0: Dashboard (.hosted() + OmniLifecycle + OmniState)
            OmniBranch(
              routes: [OmniPage.screen(const DashboardScreen())],
            ),
            // Branch 1: Students (Lazy page-entry StudentBloc + OmniRouteGroup)
            OmniBranch(
              routes: [
                OmniPage.screen(
                  const StudentListScreen(),
                  routes: [
                    OmniRouteGroup(
                      scopeKey: (s) => s.pathParameters['id'],
                      provide: [
                        Provide.bloc(
                          (c) => StudentDetailBloc(
                            OmniParams.of(c).pathInt('id'),
                          ),
                        ),
                      ],
                      routes: [
                        OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id'))),
                        OmniPage(
                          ':id/edit',
                          (p) => StudentEditScreen(id: p.pathInt('id')),
                          transition: OmniPages.slideUp,
                          onExit: (ctx) => StudentEditScreen.confirmLeave(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Branch 2: API, WebSocket & AI Lab wrapped in OmniShell
            OmniBranch(
              routes: [
                OmniShell(
                  builder: (context, state, child) =>
                      ApiLabShellFrame(state: state, child: child),
                  routes: [
                    OmniPage.screen(
                      const ApiCompareScreen(),
                      routes: [
                        OmniPage.screen(
                          const AiAssistantScreen(),
                          path: 'ai-chat',
                        ),
                        OmniPage.screen(
                          const RealtimeChatScreen(),
                          path: 'chat',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Branch 3: Settings -> nested '/settings/profile'
            OmniBranch(
              routes: [
                OmniPage.screen(
                  const SettingsScreen(),
                  routes: [
                    OmniPage.screen(const ProfileScreen(), path: 'profile'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Auth + Persistent Shell
// =============================================================================

class LoginScreen extends OmniStatelessWidget {
  const LoginScreen({super.key});

  @override
  String get routePath => '/login';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: FilledButton(
          onPressed: () {
            context.read<AuthBloc>().logIn();
            OmniRoute.refresh();
          },
          child: const Text('Log in'),
        ),
      ),
    );
  }
}

class ConfirmLogoutScreen extends OmniStatelessWidget {
  const ConfirmLogoutScreen({super.key});

  @override
  String get routePath => '/confirm-logout';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log out?'),
      content: const Text('Your guard will redirect back to the login screen.'),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => context.pop(true),
          child: const Text('Log out'),
        ),
      ],
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final OmniNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(icon: Icon(Icons.school), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'API & AI'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// =============================================================================
// Hosted OmniStatelessWidget Card + Dashboard (OmniLifecycle)
// =============================================================================

class WelcomeBadge extends OmniStatelessWidget {
  const WelcomeBadge({super.key});

  @override
  String get routePath => '/welcome-badge';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Hosted OmniStatelessWidget ($routePath) inside Dashboard',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class DashboardScreen extends OmniStatefulWidget {
  const DashboardScreen({super.key});

  @override
  String get routePath => '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends OmniState<DashboardScreen> with OmniLifecycle {
  int _showCount = 0;

  @override
  void onScreenVisible(BuildContext context) =>
      safeSetState(() => _showCount++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$screenTitle ($routePath)'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await push<bool>('/confirm-logout');
              if (confirmed == true && context.mounted) {
                context.read<AuthBloc>().logOut();
                OmniRoute.refresh();
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Demonstrates embedding an OmniScreen outside a route via .hosted()
              const WelcomeBadge().hosted(),
              const SizedBox(height: 12),
              Text('OmniLifecycle onShow count: $_showCount'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => go('/students/101'),
                    child: const Text('Open student 101'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => go('/api'),
                    child: const Text('Open API & AI Lab'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Students Tab (Page-Entry Provide.bloc Registration + OmniRouteGroup)
// =============================================================================

class StudentListScreen extends OmniStatelessWidget {
  const StudentListScreen({super.key});

  @override
  String get routePath => '/students';

  // Notice StudentBloc is NOT in OmniApp(blocs: ...); OmniRoute registers its
  // BlocProvider automatically when first entering `/students`.
  @override
  List<Provide> get provide => [
    Provide.bloc((_) => StudentBloc()),
  ];

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<StudentBloc>().state;
    return Scaffold(
      appBar: AppBar(title: Text('$title ($routePath)')),
      body: ListView(
        children: [
          for (final id in ids)
            ListTile(
              title: Text('Student #$id'),
              subtitle: const Text('Tap for scoped detail group'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/students/$id'),
            ),
        ],
      ),
    );
  }
}

class StudentDetailScreen extends OmniStatelessWidget {
  const StudentDetailScreen({super.key, required this.id});

  final int id;

  @override
  String get routePath => '/students/$id';

  @override
  List<Provide> get provide => [
    Provide.bloc((_) => AttendanceBloc()),
  ];

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<StudentDetailBloc>().state;
    final present = context.watch<AttendanceBloc>().state;
    return Scaffold(
      appBar: AppBar(title: Text(detail.name)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Route: $routePath'),
            const SizedBox(height: 8),
            Text('Present: $present'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context.read<AttendanceBloc>().toggle(),
                  child: const Text('Mark present'),
                ),
                FilledButton(
                  onPressed: () => context.push('/students/$id/edit'),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StudentEditScreen extends OmniStatefulWidget {
  const StudentEditScreen({super.key, required this.id});

  final int id;

  @override
  String get routePath => '/students/$id/edit';

  static Future<bool> confirmLeave(BuildContext context) async {
    if (!context.read<StudentDetailBloc>().state.hasUnsavedEdits) {
      return true;
    }
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard edits?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends OmniState<StudentEditScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: readBloc<StudentDetailBloc>().state.name,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit #${widget.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: (value) => readBloc<StudentDetailBloc>().markDirty(
                value != readBloc<StudentDetailBloc>().state.name,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    readBloc<StudentDetailBloc>().rename(_controller.text);
                    pop();
                  },
                  child: const Text('Save'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Back to list'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Settings Tab (Nested Child routePath '/settings/profile')
// =============================================================================

class SettingsScreen extends OmniStatelessWidget {
  const SettingsScreen({super.key});

  @override
  String get routePath => '/settings';

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final ui = context.ui;
    return Scaffold(
      appBar: AppBar(
        title: Text('$title ($routePath)'),
        actions: const [
          OmniFullscreenButton(),
          OmniThemeButton(),
          OmniThemeModeButton(allowSystemMode: true),
        ],
      ),
      body: ListView(
        padding: tk.pagePadding,
        children: [
          const OmniThemePanel(
            modeTitle: 'Theme Mode',
            themeTitle: 'Color Palette',
            showStylePicker: true,
            showAnimationPicker: true,
          ),
          tk.gapMd,
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const OmniThemeSettingsTile(),
                Divider(height: 1, color: ui.colors.dividerColor),
                ListTile(
                  title: const Text('Profile'),
                  subtitle: const Text('Opens nested /settings/profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.to<ProfileScreen>(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends OmniStatelessWidget {
  const ProfileScreen({super.key});

  // Declared as child `path: 'profile'` under `/settings`; nested `routePath`
  // matches `/settings/profile` cleanly!
  @override
  String get routePath => '/settings/profile';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$title ($routePath)')),
      body: Center(
        child: Text('Full nested routePath: $routePath'),
      ),
    );
  }
}
