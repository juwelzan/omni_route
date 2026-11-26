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
      // Global Blocs: created once, live for the whole app.
      OmniBloc<AuthBloc>((_) => AuthBloc(), global: true, lazy: false),
      OmniBloc<ThemeBloc>((_) => ThemeBloc(), global: true),
      // Factories for screen-scoped Blocs: created per screen, closed on pop.
      OmniBloc<StudentBloc>((_) => StudentBloc()),
      OmniBloc<AttendanceBloc>((_) => AttendanceBloc()),
    ],
    routes: [
      OmniPage('/login', (_) => const LoginScreen()),
      // A dialog route: `await OmniRoute.push<bool>('/confirm-logout')`
      // returns what the dialog passes to `OmniRoute.pop(...)`.
      OmniPage(
        '/confirm-logout',
        (_) => const ConfirmLogoutScreen(),
        transition: OmniPages.dialog(),
      ),
      OmniStatefulShell(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          OmniBranch(
            routes: [OmniPage('/dashboard', (_) => const DashboardScreen())],
          ),
          OmniBranch(
            routes: [
              OmniPage(
                '/students',
                (_) => const StudentListScreen(),
                routes: [
                  // Route scope: detail and edit share these Blocs; they are
                  // closed when the user leaves this student.
                  OmniRouteGroup(
                    scopeKey: (s) => s.pathParameters['id'],
                    provide: [
                      Provide<StudentDetailBloc>.create(
                        (c) =>
                            StudentDetailBloc(OmniParams.of(c).pathInt('id')),
                      ),
                      const Provide<AttendanceBloc>(),
                    ],
                    routes: [
                      OmniPage(
                        ':id',
                        (p) => StudentDetailScreen(id: p.pathInt('id')),
                        routes: [
                          // Edit form slides up from the bottom.
                          OmniPage(
                            'edit',
                            (_) => const StudentEditScreen(),
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
              OmniPage(
                '/settings',
                (_) => const SettingsScreen(),
                routes: [OmniPage('profile', (_) => const ProfileScreen())],
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
  String get screenName => 'Login';
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
  String get screenName => 'Dashboard';
  @override
  State<DashboardScreen> createState() => _DashboardState();
}

class _DashboardState extends OmniState<DashboardScreen> with OmniLifecycle {
  int taps = 0;
  int returns = 0;

  // Lifecycle hooks: no WidgetsBindingObserver boilerplate.
  @override
  void onAppResumed(BuildContext context) => setState(() => returns++);

  @override
  void onScreenVisible(BuildContext context) => debugPrint('Dashboard visible');
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.screenName)),
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
            onPressed: () =>
                OmniRoute.to<StudentDetailScreen>(path: {'id': '101'}),
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
  String get screenName => 'Students';
  @override
  List<Provide> get provide => const [Provide<StudentBloc>()];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(screenName)),
    body: BlocBuilder<StudentBloc, List<String>>(
      builder: (context, students) => ListView(
        children: [
          for (var i = 0; i < students.length; i++)
            ListTile(
              title: Text(students[i]),
              onTap: () => OmniRoute.open('/students/${101 + i}'),
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
  String get screenName => 'Student';
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
            onPressed: () => OmniRoute.open('/students/$id/edit'),
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
  String get screenName => 'Edit student';
  @override
  State<StudentEditScreen> createState() => _StudentEditState();
}

class _StudentEditState extends OmniState<StudentEditScreen> {
  // Same StudentDetailBloc instance as the detail page (route scope).
  late final controller = TextEditingController(
    text: context.read<StudentDetailBloc>().state,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.screenName)),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: controller),
          FilledButton(
            onPressed: () {
              context.read<StudentDetailBloc>().add(controller.text);
              OmniRoute.pop();
            },
            child: const Text('Save'),
          ),
          // Pops edit and detail in one go, back to the list.
          TextButton(
            onPressed: () => OmniRoute.popUntil('/students'),
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
  String get screenName => 'Settings';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(screenName)),
    body: ListView(
      children: [
        ListTile(
          title: const Text('Profile'),
          onTap: () => OmniRoute.go('/settings/profile'),
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
            final ok = await OmniRoute.push<bool>('/confirm-logout');
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
  String get screenName => 'Profile';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(screenName)),
    body: const Center(child: Text('Profile')),
  );
}

class ConfirmLogoutScreen extends OmniStatelessWidget {
  const ConfirmLogoutScreen({super.key});
  @override
  String get screenName => 'Confirm log out';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log out?'),
    actions: [
      TextButton(
        onPressed: () => OmniRoute.pop(false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => OmniRoute.pop(true),
        child: const Text('Yes, log out'),
      ),
    ],
  );
}
