import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  OmniRoute.usePathUrls();
  runApp(const ExampleApp());
}

// =============================================================================
// Domain & Scoped Blocs
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

class ClassicStudentBloc extends Cubit<String?> {
  ClassicStudentBloc() : super(null);

  void load(int id) {
    emit('ClassicStudent(id: $id, name: "Classic #$id", dept: "CSE")');
  }
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
// Fast, Zero-Network Application Root
// =============================================================================

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OmniApp.material(
      title: 'OmniRoute Example',
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
        // ১টি কমন OmniFieldTheme পুরো অ্যাপের সব ফিল্ডে প্রযোজ্য,
        // কিন্তু identityStyles দিয়ে প্রতিটি ফিল্ডের আলাদা আইডেন্টিটি থাকে:
        fieldTheme: OmniFieldTheme(
          variant: OmniInputVariant.outlined,
          labelMode: OmniFieldLabelMode.above,
          borderRadius: 14,
          showClearButton: true,
          identityStyles: {
            OmniFieldIdentity.email: OmniFieldStyle(
              accentColor: Color(0xFF0284C7),
              darkAccentColor: Color(0xFF38BDF8),
            ),
            OmniFieldIdentity.password: OmniFieldStyle(
              accentColor: Color(0xFF7C3AED),
              darkAccentColor: Color(0xFFA78BFA),
            ),
            OmniFieldIdentity.phone: OmniFieldStyle(
              accentColor: Color(0xFF059669),
              darkAccentColor: Color(0xFF34D399),
            ),
            OmniFieldIdentity.otp: OmniFieldStyle(
              accentColor: Color(0xFFD97706),
              darkAccentColor: Color(0xFFFBBF24),
            ),
          },
        ),
        persistMode: true,
      ),
      themes: OmniTheme.presets,
      initialRoute: '/dashboard',
      transition: OmniPages.fadeSlide,
      guards: const [AuthGuard()],
      blocs: [
        OmniBloc((_) => AuthBloc(), global: true),
        OmniBloc((_) => ClassicStudentBloc()),
      ],
      routes: [
        OmniPage('/login', (_) => const LoginScreen()),
        OmniPage.screen(
          const ConfirmLogoutScreen(),
          transition: OmniPages.dialog(),
        ),
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
            // Branch 2: Settings -> nested '/settings/profile'
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  void _submitLogin() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AuthBloc>().logIn();
    OmniRoute.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
        actions: const [OmniThemeModeButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: tk.pagePadding,
          child: OmniResponsiveContainer(
            maxWidth: 440,
            child: Card(
              child: Padding(
                padding: tk.cardPadding,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Welcome back', style: context.textStyles.heading),
                      tk.gapXs,
                      Text(
                        'Shared OmniFieldTheme + Gmail & Password validation',
                        style: context.textStyles.bodyMuted,
                      ),
                      tk.gapMd,
                      const OmniEmailField.gmail(
                        label: 'Gmail Address',
                        initialValue: 'student@gmail.com',
                      ),
                      tk.gapSm,
                      const OmniPasswordField(
                        label: 'Password',
                        initialValue: 'Pass@1234',
                        showStrengthIndicator: true,
                      ),
                      tk.gapMd,
                      FilledButton(
                        onPressed: _submitLogin,
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
          const OmniThemeButton(),
          const OmniThemeModeButton(),
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
                    onPressed: () => OmniRoute.pushNamed(
                      'classic_student',
                      path: {'id': '205'},
                    ),
                    child: const Text('Classic Named Route'),
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

class StudentListScreen extends OmniStatefulWidget {
  const StudentListScreen({super.key});

  @override
  String get routePath => '/students';

  @override
  List<Provide> get provide => [
    Provide.bloc((_) => StudentBloc()),
  ];

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends OmniState<StudentListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<StudentBloc>().state;
    final filtered = _query.trim().isEmpty
        ? ids
        : ids.where((id) => '$id'.contains(_query.trim())).toList();

    return Scaffold(
      appBar: AppBar(title: Text('$screenTitle ($routePath)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: OmniSearchField(
              hint: 'Search student ID (e.g. 101)...',
              onChanged: (q) => safeSetState(() => _query = q),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final id in filtered)
                  ListTile(
                    title: Text('Student #$id'),
                    subtitle: const Text('Tap for scoped detail group'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/students/$id'),
                  ),
              ],
            ),
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
            OmniNameField(
              label: 'Student Name',
              hint: 'Enter student name',
              controller: _controller,
              allowDigits: true,
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

class ClassicStudentDetailScreen extends StatelessWidget {
  const ClassicStudentDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ClassicStudentBloc>()..load(id);
    return BlocBuilder<ClassicStudentBloc, String?>(
      bloc: bloc,
      builder: (context, student) => Scaffold(
        appBar: AppBar(title: Text('Classic Route #$id')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Classic Style: OmniPage("/classic-student/:id", ..., name: "classic_student") + '
                'pre-registered OmniBloc<ClassicStudentBloc> + pushNamed',
              ),
              const SizedBox(height: 12),
              Text('Loaded: $student'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Pop Classic Route'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Settings Tab (Theming, Color Palettes, Animations & Nested Profile Route)
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
          OmniThemeModeButton(),
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
                const OmniThemeSettingsTile(showAnimationPicker: true),
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

class ProfileScreen extends OmniStatefulWidget {
  const ProfileScreen({super.key});

  @override
  String get routePath => '/settings/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends OmniState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassController = TextEditingController();
  bool _phoneVerified = false;
  bool _otpVerified = false;
  String _fullPhone = '';

  @override
  void dispose() {
    _newPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text('$screenTitle ($routePath)')),
      body: SingleChildScrollView(
        padding: tk.pagePadding,
        child: OmniResponsiveContainer(
          maxWidth: 620,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Full nested routePath: $routePath',
                  style: context.textStyles.caption,
                ),
                tk.gapMd,
                const OmniNameField.firstName(initialValue: 'Rahim'),
                tk.gapSm,
                const OmniNameField.username(initialValue: 'rahim_dev'),
                tk.gapSm,
                const OmniEmailField(
                  label: 'Recovery Email',
                  initialValue: 'rahim@example.com',
                ),
                tk.gapSm,
                OmniPhoneField(
                  countryCode: '+880',
                  initialValue: '01712345678',
                  isVerified: _phoneVerified,
                  onFullNumberChanged: (v) => _fullPhone = v,
                  onVerifyPressed: () =>
                      safeSetState(() => _phoneVerified = true),
                ),
                tk.gapSm,
                OmniOtpField(
                  length: 6,
                  isVerified: _otpVerified,
                  helperText: 'Enter 6-digit OTP or paste from SMS',
                  onCompleted: (_) => safeSetState(() => _otpVerified = true),
                  onResend: () {},
                ),
                tk.gapSm,
                OmniPasswordField.newPassword(
                  controller: _newPassController,
                  label: 'New Password',
                ),
                tk.gapSm,
                OmniPasswordField.confirm(
                  matchController: _newPassController,
                ),
                tk.gapSm,
                const OmniNumberField.integer(
                  label: 'Batch Year',
                  initialValue: '2026',
                  min: 2000,
                  max: 2050,
                ),
                tk.gapSm,
                const OmniNumberField.currency(
                  label: 'Scholarship Budget',
                  initialValue: '5000',
                  min: 0,
                ),
                tk.gapSm,
                const OmniUrlField(
                  label: 'Portfolio URL',
                  initialValue: 'https://omniroute.dev',
                ),
                tk.gapSm,
                const OmniMultilineField(
                  label: 'Bio & Address',
                  initialValue: 'Flutter & Dart developer',
                  maxLength: 160,
                ),
                tk.gapSm,
                const OmniTextField(
                  label: 'Referral Tag',
                  hint: 'Optional promo/referral code',
                ),
                tk.gapMd,
                FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () {
                    final valid = _formKey.currentState?.validate() ?? false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          valid
                              ? 'Profile valid! ${_fullPhone.isNotEmpty ? _fullPhone : ''}'
                              : 'Please complete highlighted fields',
                        ),
                      ),
                    );
                  },
                  label: const Text('Validate & Save Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
