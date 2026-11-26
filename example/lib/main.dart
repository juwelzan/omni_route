import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_route/omni_route.dart';

/// Swipe-back mode, changed live from Settings.
final swipeMode = ValueNotifier(OmniSwipeBack.zoom);

void main() {
  OmniRoute.usePathUrls();
  runApp(const ExampleApp());
}

// ── Blocs ─────────────────────────────────────────────────────────────
sealed class AuthEvent {}

class LoggedIn extends AuthEvent {}

class LoggedOut extends AuthEvent {}

class AuthBloc extends Bloc<AuthEvent, bool> {
  AuthBloc() : super(false) {
    on<LoggedIn>((_, emit) => emit(true));
    on<LoggedOut>((_, emit) => emit(false));
  }
}

class StudentBloc extends Bloc<String, List<String>> {
  StudentBloc() : super(const ['Rahim', 'Karim', 'Ayesha', 'Nusrat']) {
    on<String>((name, emit) => emit([...state, name]));
  }
}

/// Route-scoped: shared by a student's detail and edit pages.
class StudentDetailBloc extends Bloc<String, String> {
  StudentDetailBloc(int id) : super('Student #$id') {
    on<String>((name, emit) => emit(name));
  }
}

/// Global: one instance for the whole app.
class ThemeBloc extends Bloc<bool, bool> {
  ThemeBloc() : super(false) {
    on<bool>((dark, emit) => emit(dark));
  }
}

/// Screen-scoped, provided together with StudentDetailBloc (multiple Blocs).
class AttendanceBloc extends Bloc<void, int> {
  AttendanceBloc() : super(0) {
    on<void>((_, emit) => emit(state + 1));
  }
}

// ── Guard ─────────────────────────────────────────────────────────────
class AuthGuard extends OmniGuard {
  const AuthGuard();
  @override
  Stream<Object?> refresh(BuildContext context) =>
      context.read<AuthBloc>().stream;
  @override
  String? redirect(BuildContext c, OmniRouteState s) {
    final loggedIn = c.read<AuthBloc>().state;
    final atLogin = s.matchedLocation == '/login';
    if (!loggedIn && !atLogin) {
      return Uri(
        path: '/login',
        queryParameters: {'from': s.uri.toString()},
      ).toString();
    }
    if (loggedIn && atLogin) {
      return s.uri.queryParameters['from'] ?? '/dashboard';
    }
    return null;
  }
}

// ── App ───────────────────────────────────────────────────────────────
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: swipeMode,
    builder: (context, mode, _) => _app(mode),
  );

  Widget _app(OmniSwipeBack mode) => OmniApp(
    initialRoute: '/dashboard',
    guards: const [AuthGuard()],
    logNavigation: true, // debug builds print each navigation
    dismissKeyboardOnTap: true, // tap outside the edit form closes the keyboard
    maxTextScale: 1.4, // very large system fonts won't break layouts
    // Android: press back twice on the first page to leave the app.
    doubleBackToExit: const Duration(seconds: 2),
    onExitWarning: (context) => ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Press back again to exit'))),
    restorationScopeId: 'router', // restore the route stack after restart
    // Fade between pages; swipe from either edge to close. The swipe style
    // is app-wide and can be switched live in Settings.
    transition: OmniPages.fade,
    swipeBack: mode,
    // Android 14+: the system back gesture zooms the page out too (needs
    // enableOnBackInvokedCallback in AndroidManifest.xml).
    predictiveBack: true,
    blocs: [
      // Only truly app-wide global Blocs live on OmniApp.
      // Page-scoped Blocs live on their pages/screens and register on entry.
      OmniBloc((_) => AuthBloc(), global: true, lazy: false),
      OmniBloc((_) => ThemeBloc(), global: true),
    ],
    routes: [
      OmniPage.screen(const LoginScreen()),
      // A dialog route: `await OmniRoute.push<bool>('/confirm-logout')`
      // returns what the dialog passes to `OmniRoute.pop(...)`.
      OmniPage.screen(
        const ConfirmLogoutScreen(),
        transition: OmniPages.dialog(),
      ),
      OmniStatefulShell(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          OmniBranch(
            routes: [OmniPage.screen(const DashboardScreen())],
          ),
          OmniBranch(
            routes: [
              OmniPage.screen(
                const StudentListScreen(),
                routes: [
                  // Route scope: detail and edit share these Blocs; they are
                  // registered on first entry and closed on leave.
                  OmniRouteGroup(
                    scopeKey: (s) => s.pathParameters['id'],
                    provide: [
                      OmniBloc(
                        (c) =>
                            StudentDetailBloc(OmniParams.of(c).pathInt('id')),
                      ),
                      OmniBloc((_) => AttendanceBloc()),
                    ],
                    routes: [
                      OmniPage<StudentDetailScreen>(
                        ':id',
                        (p) => StudentDetailScreen(id: p.pathInt('id')),
                        routes: [
                          // Edit form slides up from the bottom.
                          OmniPage.screen(
                            const StudentEditScreen(),
                            transition: OmniPages.slideUp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          OmniBranch(
            routes: [
              OmniPage.screen(
                const SettingsScreen(),
                routes: [OmniPage.screen(const ProfileScreen())],
              ),
            ],
          ),
        ],
      ),
    ],
    builder: (context, router) => BlocBuilder<ThemeBloc, bool>(
      builder: (context, dark) => MaterialApp.router(
        title: 'OmniRoute Example',
        restorationScopeId: 'app',
        routerConfig: router,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
      ),
    ),
  );
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final OmniNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );
}

// ── Screens ───────────────────────────────────────────────────────────
class LoginScreen extends OmniStatelessWidget {
  const LoginScreen({super.key});
  @override
  String get routePath => '/login';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => context.read<AuthBloc>().add(LoggedIn()),
        child: const Text('Log in'),
      ),
    ),
  );
}

class DashboardScreen extends OmniStatefulWidget {
  const DashboardScreen({super.key});
  @override
  String get routePath => '/dashboard';
  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends OmniState<DashboardScreen> with OmniLifecycle {
  int taps = 0;
  int returns = 0;

  // Lifecycle hooks: no WidgetsBindingObserver boilerplate.
  @override
  void onAppResumed(BuildContext context) => safeSetState(() => returns++);

  @override
  void onScreenVisible(BuildContext context) => debugPrint('Dashboard visible');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(screenTitle)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tapped $taps times (kept across tabs)'),
          Text('Back in the app $returns times'),
          TextButton(
            onPressed: () => setState(() => taps++),
            child: const Text('Tap'),
          ),
          TextButton(
            onPressed: () => to<StudentDetailScreen>(path: {'id': '101'}),
            child: const Text('Open student 101'),
          ),
        ],
      ),
    ),
  );
}

class StudentListScreen extends OmniStatelessWidget {
  const StudentListScreen({super.key});
  @override
  String get routePath => '/students';
  // Registered automatically when entering /students for the first time.
  @override
  List<Provide> get provide => [Provide.bloc((_) => StudentBloc())];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: BlocBuilder<StudentBloc, List<String>>(
      builder: (context, students) => ListView(
        children: [
          for (var i = 0; i < students.length; i++)
            ListTile(
              title: Text(students[i]),
              onTap: () => context.open('/students/${101 + i}'),
            ),
        ],
      ),
    ),
  );
}

class StudentDetailScreen extends OmniStatelessWidget {
  const StudentDetailScreen({super.key, required this.id});
  final int id;
  @override
  String get routePath => '/students/:id';
  @override
  String get title => 'Student $id';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.watch<StudentDetailBloc>().state),
          Text('Present ${context.watch<AttendanceBloc>().state} days'),
          TextButton(
            onPressed: () => context.read<AttendanceBloc>().add(null),
            child: const Text('Mark present'),
          ),
          TextButton(
            onPressed: () => context.open('/students/$id/edit'),
            child: const Text('Edit'),
          ),
        ],
      ),
    ),
  );
}

class StudentEditScreen extends OmniStatefulWidget {
  const StudentEditScreen({super.key});
  @override
  String get routePath => '/students/:id/edit';
  @override
  String get title => 'Edit student';
  @override
  State<StudentEditScreen> createState() => _StudentEditState();
}

class _StudentEditState extends OmniState<StudentEditScreen> {
  // Same StudentDetailBloc instance as the detail page (route scope).
  late final controller = TextEditingController(
    text: readBloc<StudentDetailBloc>().state,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(screenTitle)),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: controller),
          FilledButton(
            onPressed: () {
              readBloc<StudentDetailBloc>().add(controller.text);
              pop();
            },
            child: const Text('Save'),
          ),
          // Pops edit and detail in one go, back to the list.
          TextButton(
            onPressed: () => context.popUntil('/students'),
            child: const Text('Back to list'),
          ),
        ],
      ),
    ),
  );
}

class SettingsScreen extends OmniStatelessWidget {
  const SettingsScreen({super.key});
  @override
  String get routePath => '/settings';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      children: [
        ListTile(
          title: const Text('Profile'),
          onTap: () => const ProfileScreen().go(context),
        ),
        ValueListenableBuilder(
          valueListenable: swipeMode,
          builder: (context, mode, _) => ListTile(
            title: const Text('Swipe back'),
            trailing: DropdownButton<OmniSwipeBack>(
              value: mode,
              onChanged: (m) => swipeMode.value = m!,
              items: [
                for (final m in OmniSwipeBack.values)
                  DropdownMenuItem(value: m, child: Text(m.name)),
              ],
            ),
          ),
        ),
        BlocBuilder<ThemeBloc, bool>(
          builder: (context, dark) => SwitchListTile(
            title: const Text('Dark mode'),
            value: dark,
            onChanged: (v) => context.read<ThemeBloc>().add(v),
          ),
        ),
        ListTile(
          title: const Text('Log out'),
          onTap: () async {
            final auth = context.read<AuthBloc>();
            final ok = await const ConfirmLogoutScreen().push<bool>(context);
            if (ok ?? false) auth.add(LoggedOut());
          },
        ),
      ],
    ),
  );
}

class ProfileScreen extends OmniStatelessWidget {
  const ProfileScreen({super.key});
  @override
  String get routePath => '/settings/profile';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const Center(child: Text('Profile')),
  );
}

class ConfirmLogoutScreen extends OmniStatelessWidget {
  const ConfirmLogoutScreen({super.key});
  @override
  String get routePath => '/confirm-logout';
  @override
  String get title => 'Confirm log out';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log out?'),
    actions: [
      TextButton(
        onPressed: () => context.pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => context.pop(true),
        child: const Text('Yes, log out'),
      ),
    ],
  );
}
