import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

import 'bottom_nav_demo.dart';
import 'sheets_demo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OmniRoute.usePathUrls();
  // Saved theme, language and text size are ready for the very first frame.
  await OmniPreferences.preload();
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

  void rename(String name) => emit(
    StudentDetailState(id: state.id, name: name, hasUnsavedEdits: false),
  );
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
  FutureOr<String?> redirect(BuildContext context, OmniRouteState state) {
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
        OmniPage.screen(const BottomNavDemoScreen()),
        OmniPage.screen(
          const OmniPageNavFeedScreen(),
          bottomNavigationBar: omniPageDemoSharedBar,
        ),
        OmniPage.screen(
          const OmniPageNavExploreScreen(),
          bottomNavigationBar: omniPageDemoSharedBar,
        ),
        OmniPage.screen(
          const OmniPageNavSavedScreen(),
          bottomNavigationBar: omniPageDemoSharedBar,
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
            OmniBranch(routes: [OmniPage.screen(const DashboardScreen())]),
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
                          (c) =>
                              StudentDetailBloc(OmniParams.of(c).pathInt('id')),
                        ),
                      ],
                      routes: [
                        OmniPage(
                          ':id',
                          (p) => StudentDetailScreen(id: p.pathInt('id')),
                        ),
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
            // Branch 2: Interactive Playground of ALL Predefined Fields ('/fields')
            OmniBranch(
              routes: [OmniPage.screen(const FieldsPlaygroundScreen())],
            ),
            // Branch 3: Settings -> nested '/settings/profile'
            OmniBranch(
              routes: [
                OmniPage.screen(
                  const SettingsScreen(),
                  routes: [
                    OmniPage.screen(const ProfileScreen(), path: 'profile'),
                    OmniPage.screen(
                      const SheetsDemoScreen(),
                      path: 'sheets',
                      routes: [
                        OmniPage.screen(
                          const ScalableSheetDemoScreen(),
                          path: 'scalable',
                        ),
                      ],
                    ),
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
// Auth + Persistent Shell + Multi-Language Helper (OmniLang)
// =============================================================================

class _ExampleLang extends OmniLang {
  const _ExampleLang([super.context]);

  String get dashboardBanner => pick(
    en: 'Switch language anywhere — all screens update instantly with zero reload!',
    bn: 'যেকোনো জায়গায় ভাষা বদলান — রিলোড ছাড়াই পুরো অ্যাপ সাথে সাথে বদলে যাবে!',
    ar: 'بدّل اللغة في أي مكان — تتحدث كل الشاشات فوراً بدون إعادة تحميل!',
    hi: 'कहीं भी भाषा बदलें — बिना रीलोड सभी स्क्रीन तुरंत बदल जाएंगी!',
    es: 'Cambia el idioma en cualquier lugar: todas las pantallas se actualizan al instante!',
    fr: 'Changez de langue partout — tous les écrans se mettent à jour instantanément !',
  );
}

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
        title: OmniText(
          en: 'Sign in',
          bn: 'সাইন ইন',
          ar: 'تسجيل الدخول',
          hi: 'साइन इन',
        ),
        actions: const [OmniLanguageButton(), OmniThemeModeButton()],
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
                      OmniText(
                        en: 'Welcome back',
                        bn: 'আবার স্বাগতম',
                        ar: 'مرحباً بعودتك',
                        hi: 'वापसी पर स्वागत है',
                        style: context.textStyles.heading,
                      ),
                      tk.gapXs,
                      Text(
                        context.l10n(
                          en: 'Shared OmniFieldTheme + Gmail & Password validation',
                          bn: 'শেয়ার্ড OmniFieldTheme + জিমেইল ও পাসওয়ার্ড ভ্যালিডেশন',
                          ar: 'ثيم موحد للحقول + التحقق من البريد وكلمة المرور',
                          hi: 'शेयर्ड OmniFieldTheme + जीमेल और पासवर्ड सत्यापन',
                        ),
                        style: context.textStyles.bodyMuted,
                      ),
                      tk.gapMd,
                      const OmniEmailField.gmail(
                        label: 'Gmail',
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
                        child: Text(
                          context.l10n(
                            en: 'Log in',
                            bn: 'লগইন করুন',
                            ar: 'تسجيل الدخول',
                            hi: 'लॉग इन करें',
                          ),
                        ),
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
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: context.l10n(
              en: 'Dashboard',
              bn: 'ড্যাশবোর্ড',
              ar: 'لوحة التحكم',
              hi: 'डैशबोर्ड',
            ),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school),
            label: context.l10n(
              en: 'Students',
              bn: 'শিক্ষার্থী',
              ar: 'الطلاب',
              hi: 'छात्र',
            ),
          ),
          NavigationDestination(
            icon: const Icon(Icons.text_fields_rounded),
            label: context.l10n(
              en: 'Fields',
              bn: 'ফিল্ডস',
              ar: 'الحقول',
              hi: 'फ़ील्ड्स',
            ),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: context.l10n(
              en: 'Settings',
              bn: 'সেটিংস',
              ar: 'الإعدادات',
              hi: 'सेटिंग्स',
            ),
          ),
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

class _DashboardScreenState extends OmniState<DashboardScreen>
    with OmniLifecycle {
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
          const OmniLanguageButton(),
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
              Text(
                _ExampleLang(context).dashboardBanner,
                textAlign: TextAlign.center,
                style: context.textStyles.caption,
              ),
              const SizedBox(height: 8),
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
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.text_fields_rounded),
                    onPressed: () => go('/fields'),
                    label: const Text('All Text Fields Demo'),
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
  List<Provide> get provide => [Provide.bloc((_) => StudentBloc())];

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
  List<Provide> get provide => [Provide.bloc((_) => AttendanceBloc())];

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
          OmniLanguageButton(),
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
            child: Padding(
              padding: tk.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n(
                      en: 'Language & Country Code (OmniText)',
                      bn: 'ভাষা ও কান্ট্রি কোড (OmniText)',
                      ar: 'اللغة ورمز البلد (OmniText)',
                      hi: 'भाषा और देश कोड (OmniText)',
                    ),
                    style: context.textStyles.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_ExampleLang(context).dashboardBanner}\n'
                    'Active: ${context.currentLanguage.flag} ${context.currentLanguage.nativeName} '
                    '• Country enum: OmniCountryCode.${context.currentCountry.name} (${context.currentCountry.isoCode}) '
                    '• RTL: ${context.isRtl}',
                    style: context.textStyles.caption,
                  ),
                  tk.gapSm,
                  const OmniLanguagePicker(
                    languages: [
                      OmniLanguage.en,
                      OmniLanguage.bn,
                      OmniLanguage.ar,
                      OmniLanguage.hi,
                      OmniLanguage.es,
                      OmniLanguage.fr,
                      OmniLanguage.de,
                      OmniLanguage.ja,
                    ],
                  ),
                  tk.gapSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cc in const [
                        OmniCountryCode.bd,
                        OmniCountryCode.us,
                        OmniCountryCode.gb,
                        OmniCountryCode.sa,
                        OmniCountryCode.ind,
                      ])
                        ActionChip(
                          label: Text('${cc.flag} ${cc.isoCode}'),
                          backgroundColor: context.currentCountry == cc
                              ? ui.colors.primaryColor.withValues(alpha: 0.16)
                              : null,
                          onPressed: () => OmniText.setCountry(cc),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          tk.gapMd,
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const OmniLanguageTile(),
                Divider(height: 1, color: ui.colors.dividerColor),
                const OmniThemeSettingsTile(showAnimationPicker: true),
                Divider(height: 1, color: ui.colors.dividerColor),
                ListTile(
                  title: const Text('Profile'),
                  subtitle: const Text('Opens nested /settings/profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.to<ProfileScreen>(),
                ),
                Divider(height: 1, color: ui.colors.dividerColor),
                ListTile(
                  title: const Text('Bottom Sheets'),
                  subtitle: const Text(
                    'showOmniBottomSheet: iOS / Material / floating',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.to<SheetsDemoScreen>(),
                ),
                Divider(height: 1, color: ui.colors.dividerColor),
                ListTile(
                  title: const Text('Bottom Navigation Bar'),
                  subtitle: const Text(
                    '12 CollectUI modes, Floating, Glass, Notch & OmniPage bar',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.to<BottomNavDemoScreen>(),
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
                  leadingIcon: const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 18,
                  ),
                  isVerified: _phoneVerified,
                  onFullNumberChanged: (v) => _fullPhone = v,
                  onVerifyPressed: () =>
                      safeSetState(() => _phoneVerified = true),
                ),
                tk.gapSm,
                OmniOtpField(
                  length: 6,
                  isVerified: _otpVerified,
                  separatorBuilder: (_, i) => SizedBox(width: i == 2 ? 14 : 8),
                  helperText:
                      '6-digit Pinput-style OTP (supports 3, 4, 5, 6+ boxes)',
                  onCompleted: (_) => safeSetState(() => _otpVerified = true),
                  onResend: () {},
                ),
                tk.gapSm,
                OmniPasswordField.newPassword(
                  controller: _newPassController,
                  label: 'New Password',
                ),
                tk.gapSm,
                OmniPasswordField.confirm(matchController: _newPassController),
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

// =============================================================================
// Interactive All-Fields Playground ('/fields')
// =============================================================================

class FieldsPlaygroundScreen extends OmniStatefulWidget {
  const FieldsPlaygroundScreen({super.key});

  @override
  String get routePath => '/fields';

  @override
  State<FieldsPlaygroundScreen> createState() => _FieldsPlaygroundScreenState();
}

class _FieldsPlaygroundScreenState extends OmniState<FieldsPlaygroundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassController = TextEditingController();
  final _otpController = TextEditingController();

  OmniInputVariant _variant = OmniInputVariant.outlined;
  OmniFieldLabelMode _labelMode = OmniFieldLabelMode.above;
  bool _customIcons = false;

  int _otpLength = 6;
  OmniOtpBoxStyle _otpBoxStyle = OmniOtpBoxStyle.outlined;
  bool _otpObscure = false;
  String _otpCompletedCode = '';
  OmniOtpStatus? _otpStatus;
  OmniOtpAnimationType _otpPinAnim = OmniOtpAnimationType.spring;
  OmniOtpVerifiedAnimation _otpVerifiedAnim =
      OmniOtpVerifiedAnimation.mergeCheck;
  OmniOtpErrorAnimation _otpErrorAnim = OmniOtpErrorAnimation.shake;
  OmniOtpWarningAnimation _otpWarningAnim = OmniOtpWarningAnimation.pulse;
  int _otpErrorTrigger = 0;
  int _otpWarningTrigger = 0;

  String _e164Phone = '+8801712345678';
  bool _phoneVerified = false;
  num? _decimalWeight = 68.5;
  String _debouncedSearch = '';
  bool _filterActive = false;

  @override
  void dispose() {
    _newPassController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final tk = context.tokens;
    return Card(
      child: Padding(
        padding: tk.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.textStyles.title),
            const SizedBox(height: 2),
            Text(subtitle, style: context.textStyles.caption),
            tk.gapMd,
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) tk.gapSm,
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tokens;
    final currentTheme = OmniFieldTheme.of(context).copyWith(
      variant: _variant,
      labelMode: _labelMode,
      otpBoxStyle: _otpBoxStyle,
      identityStyles: _customIcons
          ? const {
              OmniFieldIdentity.email: OmniFieldStyle(
                accentColor: Color(0xFF0284C7),
                prefixIcon: Icon(Icons.mark_email_read_outlined),
              ),
              OmniFieldIdentity.password: OmniFieldStyle(
                accentColor: Color(0xFF7C3AED),
                prefixIcon: Icon(Icons.key_rounded),
              ),
              OmniFieldIdentity.name: OmniFieldStyle(
                accentColor: Color(0xFF0D9488),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              OmniFieldIdentity.phone: OmniFieldStyle(
                accentColor: Color(0xFF059669),
              ),
              OmniFieldIdentity.number: OmniFieldStyle(
                accentColor: Color(0xFFEA580C),
                prefixIcon: Icon(Icons.calculate_outlined),
              ),
            }
          : OmniFieldTheme.of(context).identityStyles,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Predefined Fields (/fields)'),
        actions: const [
          OmniLanguageButton(),
          OmniThemeButton(),
          OmniThemeModeButton(),
        ],
      ),
      body: OmniFieldThemeScope(
        theme: currentTheme,
        child: SingleChildScrollView(
          padding: tk.pagePadding,
          child: OmniResponsiveContainer(
            maxWidth: 720,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionCard(
                    context,
                    title: 'Shared Field Theme Controls',
                    subtitle: '1 theme controls ALL fields below while keeping each field identity & behavior distinct',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SegmentedButton<OmniInputVariant>(
                            segments: const [
                              ButtonSegment(
                                value: OmniInputVariant.outlined,
                                label: Text('Outlined'),
                              ),
                              ButtonSegment(
                                value: OmniInputVariant.filled,
                                label: Text('Filled'),
                              ),
                              ButtonSegment(
                                value: OmniInputVariant.underlined,
                                label: Text('Line'),
                              ),
                            ],
                            selected: {_variant},
                            onSelectionChanged: (s) =>
                                safeSetState(() => _variant = s.first),
                          ),
                          SegmentedButton<OmniFieldLabelMode>(
                            segments: const [
                              ButtonSegment(
                                value: OmniFieldLabelMode.above,
                                label: Text('Above'),
                              ),
                              ButtonSegment(
                                value: OmniFieldLabelMode.floating,
                                label: Text('Float'),
                              ),
                              ButtonSegment(
                                value: OmniFieldLabelMode.none,
                                label: Text('Hint'),
                              ),
                            ],
                            selected: {_labelMode},
                            onSelectionChanged: (s) =>
                                safeSetState(() => _labelMode = s.first),
                          ),
                          FilterChip(
                            label: const Text('Custom Identity Icons'),
                            selected: _customIcons,
                            onSelected: (v) =>
                                safeSetState(() => _customIcons = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '1. Name & Identity Fields',
                    subtitle: 'OmniNameField, .firstName, .lastName, .username',
                    children: [
                      const OmniNameField(
                        initialValue: 'Tanvir Ahmed',
                        showValidBadge: true,
                      ),
                      const Row(
                        children: [
                          Expanded(
                            child: OmniNameField.firstName(
                              initialValue: 'Tanvir',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OmniNameField.lastName(
                              initialValue: 'Ahmed',
                            ),
                          ),
                        ],
                      ),
                      const OmniNameField.username(initialValue: 'tanvir_dev'),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '2. Email & Gmail Verification',
                    subtitle: 'OmniEmailField (general) & OmniEmailField.gmail (@gmail.com check + quick-fill)',
                    children: [
                      const OmniEmailField(
                        label: 'Work Email',
                        initialValue: 'team@omniroute.dev',
                      ),
                      const OmniEmailField.gmail(
                        label: 'Gmail Verification',
                        initialValue: 'tanvir@gmail.com',
                        helperText: 'Clear & type a username to test 1-tap @gmail.com chip',
                      ),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '3. Password, Show/Hide, Strength & Match',
                    subtitle: 'OmniPasswordField, .newPassword (live strength bar) & .confirm',
                    children: [
                      const OmniPasswordField(
                        label: 'Current Password',
                        initialValue: 'Secret@12',
                      ),
                      OmniPasswordField.newPassword(
                        controller: _newPassController,
                        initialValue: 'StrongPass1!',
                      ),
                      OmniPasswordField.confirm(
                        matchController: _newPassController,
                        initialValue: 'StrongPass1!',
                      ),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '4. Mobile Number & Pinput-Style OTP',
                    subtitle: 'Per-country length limits & auto-masking + animated Warning / Error / Verified merge OTP',
                    children: [
                      OmniPhoneField(
                        countryCode: '+880',
                        initialValue: '01712345678',
                        leadingIcon: const Icon(
                          Icons.phone_in_talk_rounded,
                          size: 18,
                        ),
                        isVerified: _phoneVerified,
                        onFullNumberChanged: (e164) =>
                            safeSetState(() => _e164Phone = e164),
                        onVerifyPressed: () =>
                            safeSetState(() => _phoneVerified = true),
                        helperText:
                            'Normalized E.164: $_e164Phone • Switch country to test exact digit cap & mask',
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('OTP Digits:', style: context.textStyles.label),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 3, label: Text('3')),
                              ButtonSegment(value: 4, label: Text('4')),
                              ButtonSegment(value: 5, label: Text('5')),
                              ButtonSegment(value: 6, label: Text('6')),
                            ],
                            selected: {_otpLength},
                            onSelectionChanged: (s) => safeSetState(() {
                              _otpLength = s.first;
                              _otpCompletedCode = '';
                              _otpStatus = null;
                              _otpController.clear();
                            }),
                          ),
                          SegmentedButton<OmniOtpBoxStyle>(
                            segments: const [
                              ButtonSegment(
                                value: OmniOtpBoxStyle.outlined,
                                label: Text('Box'),
                              ),
                              ButtonSegment(
                                value: OmniOtpBoxStyle.filled,
                                label: Text('Fill'),
                              ),
                              ButtonSegment(
                                value: OmniOtpBoxStyle.underlined,
                                label: Text('Dash'),
                              ),
                            ],
                            selected: {_otpBoxStyle},
                            onSelectionChanged: (s) =>
                                safeSetState(() => _otpBoxStyle = s.first),
                          ),
                          FilterChip(
                            label: const Text('PIN Dots'),
                            selected: _otpObscure,
                            onSelected: (v) =>
                                safeSetState(() => _otpObscure = v),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<OmniOtpAnimationType>(
                            value: _otpPinAnim,
                            isDense: true,
                            onChanged: (v) {
                              if (v != null) {
                                safeSetState(() => _otpPinAnim = v);
                              }
                            },
                            items: OmniOtpAnimationType.values
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text('Type: ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                          DropdownButton<OmniOtpVerifiedAnimation>(
                            value: _otpVerifiedAnim,
                            isDense: true,
                            onChanged: (v) {
                              if (v == null) return;
                              final replay =
                                  _otpStatus == OmniOtpStatus.verified;
                              safeSetState(() {
                                _otpVerifiedAnim = v;
                                if (replay) _otpStatus = OmniOtpStatus.idle;
                              });
                              if (replay) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  safeSetState(
                                    () => _otpStatus = OmniOtpStatus.verified,
                                  );
                                });
                              }
                            },
                            items: OmniOtpVerifiedAnimation.values
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text('Verify: ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                          DropdownButton<OmniOtpErrorAnimation>(
                            value: _otpErrorAnim,
                            isDense: true,
                            onChanged: (v) {
                              if (v != null) {
                                safeSetState(() {
                                  _otpErrorAnim = v;
                                  if (_otpStatus == OmniOtpStatus.error) {
                                    _otpErrorTrigger++;
                                  }
                                });
                              }
                            },
                            items: OmniOtpErrorAnimation.values
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text('Error: ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                          DropdownButton<OmniOtpWarningAnimation>(
                            value: _otpWarningAnim,
                            isDense: true,
                            onChanged: (v) {
                              if (v != null) {
                                safeSetState(() {
                                  _otpWarningAnim = v;
                                  if (_otpStatus == OmniOtpStatus.warning) {
                                    _otpWarningTrigger++;
                                  }
                                });
                              }
                            },
                            items: OmniOtpWarningAnimation.values
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a,
                                    child: Text('Warn: ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => safeSetState(() {
                              _otpCompletedCode = '123456'.substring(
                                0,
                                _otpLength,
                              );
                              _otpController.text = _otpCompletedCode;
                              _otpStatus = OmniOtpStatus.verified;
                            }),
                            icon: const Icon(Icons.verified_rounded, size: 16),
                            label: const Text('Simulate Verify'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => safeSetState(() {
                              _otpStatus = OmniOtpStatus.warning;
                              _otpWarningTrigger++;
                            }),
                            icon: const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                            ),
                            label: const Text('Warning'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => safeSetState(() {
                              _otpStatus = OmniOtpStatus.error;
                              _otpErrorTrigger++;
                            }),
                            icon: const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                            ),
                            label: const Text('Error'),
                          ),
                          TextButton.icon(
                            onPressed: () => safeSetState(() {
                              _otpStatus = null;
                              _otpCompletedCode = '';
                              _otpController.clear();
                            }),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset OTP'),
                          ),
                        ],
                      ),
                      OmniOtpField(
                        key: ValueKey('playground_otp_$_otpLength'),
                        length: _otpLength,
                        controller: _otpController,
                        boxStyle: _otpBoxStyle,
                        pinAnimationType: _otpPinAnim,
                        obscureText: _otpObscure,
                        status: _otpStatus,
                        isVerified: _otpStatus == OmniOtpStatus.verified,
                        verifiedAnimation: _otpVerifiedAnim,
                        errorAnimation: _otpErrorAnim,
                        warningAnimation: _otpWarningAnim,
                        errorTrigger: _otpErrorTrigger,
                        warningTrigger: _otpWarningTrigger,
                        warningText: _otpStatus == OmniOtpStatus.warning
                            ? 'Only 2 attempts left — check your SMS code'
                            : null,
                        errorText: _otpStatus == OmniOtpStatus.error
                            ? 'Invalid verification code — please retry'
                            : null,
                        separatorBuilder: _otpLength == 6
                            ? (_, i) => SizedBox(width: i == 2 ? 14 : 6)
                            : null,
                        helperText: _otpCompletedCode.isNotEmpty
                            ? 'Entered $_otpLength-digit code: $_otpCompletedCode'
                            : 'Showing $_otpLength boxes — tap & type or test Warning / Error / Verify',
                        onChanged: (_) {
                          if (_otpStatus == OmniOtpStatus.error ||
                              _otpStatus == OmniOtpStatus.warning) {
                            safeSetState(() => _otpStatus = null);
                          }
                        },
                        onCompleted: (c) => safeSetState(() {
                          _otpCompletedCode = c;
                          _otpStatus = OmniOtpStatus.verified;
                        }),
                        resendDuration: const Duration(seconds: 20),
                        onResend: () => safeSetState(() {
                          _otpStatus = null;
                          _otpCompletedCode = '';
                          _otpController.clear();
                        }),
                      ),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '5. Numbers, Stepper & Currency Fields',
                    subtitle: 'OmniNumberField, .integer (stepper), .decimal & .currency',
                    children: [
                      const OmniNumberField(
                        label: 'Score (0-100)',
                        initialValue: '85',
                        min: 0,
                        max: 100,
                        showClearButton: true,
                      ),
                      const OmniNumberField.integer(
                        label: 'Seat Quantity (Stepper)',
                        initialValue: '3',
                        min: 1,
                        max: 20,
                      ),
                      OmniNumberField.decimal(
                        label: 'Package Weight',
                        initialValue: '68.50',
                        suffixText: 'kg',
                        decimalRange: 2,
                        onNumberChanged: (n) =>
                            safeSetState(() => _decimalWeight = n),
                        helperText: 'Parsed numeric value: $_decimalWeight',
                      ),
                      const OmniNumberField.currency(
                        label: 'Course Fee',
                        initialValue: '2500',
                        min: 100,
                      ),
                    ],
                  ),
                  tk.gapMd,
                  _sectionCard(
                    context,
                    title: '6. Search, URL, Multiline & Custom Text',
                    subtitle: 'OmniSearchField, OmniUrlField, OmniMultilineField & OmniTextField',
                    children: [
                      OmniSearchField(
                        hint: 'Search docs, packages, routes...',
                        onSearchChanged: (q) =>
                            safeSetState(() => _debouncedSearch = q),
                        onFilterPressed: () =>
                            safeSetState(() => _filterActive = !_filterActive),
                      ),
                      if (_debouncedSearch.isNotEmpty || _filterActive)
                        Text(
                          'Query: "${_debouncedSearch.isEmpty ? '(all)' : _debouncedSearch}" · Filter: $_filterActive',
                          style: context.textStyles.caption,
                        ),
                      const OmniUrlField(
                        label: 'Project Repository URL',
                        initialValue: 'https://pub.dev/packages/omni_route',
                      ),
                      const OmniMultilineField(
                        label: 'Short Bio / Notes',
                        initialValue: 'Building fast, cleanly-themed Flutter apps with OmniRoute.',
                        maxLength: 160,
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      const OmniTextField(
                        label: 'Promo / Referral Tag',
                        hint: 'Optional tag with custom icons',
                        prefixIcon: Icon(Icons.local_offer_outlined),
                        suffixIcon: Icon(Icons.auto_awesome_outlined),
                        showClearButton: true,
                        initialValue: 'OMNI2026',
                      ),
                    ],
                  ),
                  tk.gapMd,
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.fact_check_outlined),
                          onPressed: () {
                            final ok =
                                _formKey.currentState?.validate() ?? false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'All fields validated cleanly!'
                                      : 'Some fields need valid input (e.g. $_otpLength-digit OTP)',
                                ),
                              ),
                            );
                          },
                          label: const Text('Validate All Fields'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          _otpController.clear();
                          _formKey.currentState?.reset();
                          safeSetState(() {
                            _otpCompletedCode = '';
                            _phoneVerified = false;
                            _debouncedSearch = '';
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
