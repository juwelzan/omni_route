# OmniRoute

**নিজস্ব Segment Trie রাউটার ইঞ্জিন (`OmniRouter`) আর `flutter_bloc`-এর উপর তৈরি — শূন্য-ল্যাগ Navigation, Transition Animation, আর Bloc ব্যবস্থাপনা।**

`0.4.0` থেকে OmniRoute-এ কোনো third-party রাউটার (`go_router`) নেই। Flutter SDK-র নিজস্ব
`Router` ও `Navigator`-এর উপর তৈরি হয়েছে জিরো-ওভারহেড [`OmniRouter`](lib/src/core/omni_router.dart)
ইঞ্জিন, আর state management-এ থাকে [flutter_bloc](https://pub.dev/packages/flutter_bloc)।

- `OmniPage<S extends Widget>` যেকোনো `OmniScreen` বা সাধারণ `Widget`-কে সরাসরি নেটিভ Flutter `Page`-এ কম্পাইল করে
- `OmniRouteTrie` স্টার্টআপে রুট কম্পাইল করে `O(segments)` সময়ে ম্যাচ করে (কোনো রানটাইম `RegExp` নেই)
- প্রতিটা Bloc থাকে `flutter_bloc`-এর সাধারণ `BlocProvider`-এ

> - **সম্পূর্ণ বাংলা ইউজার গাইড (প্রতিটি প্যারামিটার ও উদাহরণসহ):** [doc/guide.bn.md](doc/guide.bn.md)
> - আরও গভীরে (ইংরেজি): [doc/architecture.md](doc/architecture.md) (ভিতরের গঠন, lifecycle, Bloc ownership),
>   [doc/web.md](doc/web.md) (Web hosting), [doc/platforms.md](doc/platforms.md) (Android/iOS/Desktop),
>   [doc/migration.md](doc/migration.md) (পুরনো version থেকে আপগ্রেড)।

---

## সূচিপত্র

1. [ইনস্টলেশন](#১-ইনস্টলেশন)
2. [৫ মিনিটে শুরু](#২-৫-মিনিটে-শুরু)
3. [কোন API কী কাজে — এক নজরে](#৩-কোন-api-কী-কাজে--এক-নজরে)
4. [OmniApp — অ্যাপের মূল](#৪-omniapp--অ্যাপের-মূল)
5. [Screen তৈরি](#৫-screen-তৈরি)
6. [Route রেজিস্টার — OmniPage](#৬-route-রেজিস্টার--omnipage)
7. [Route Parameter — OmniParams](#৭-route-parameter--omniparams)
8. [Navigation — OmniRoute](#৮-navigation--omniroute-ও-buildcontext-এক্সটেনশন)
9. [Bloc — কোথায় কোনটা](#৯-bloc--কোথায়-কোনটা)
10. [Shell ও Tab — OmniShell / OmniStatefulShell](#১০-shell-ও-tab)
11. [Route Group — কয়েকটা Route একই Bloc ভাগ করে](#১১-route-group)
12. [Guard — Login, Role, Permission](#১২-guard--login-role-permission)
13. [Lifecycle Hook — OmniLifecycle](#১৩-lifecycle-hook--omnilifecycle)
14. [Route-এর বাইরে Screen — OmniScreenHost](#১৪-route-এর-বাইরে-screen--omniscreenhost)
15. [Web — পরিষ্কার URL](#১৫-web--পরিষ্কার-url)
16. [Deep Link](#১৬-deep-link)
17. [Platform সেটিং — Page Transition, Desktop Back, Restoration](#১৭-platform-সেটিং)
18. [Debugging ও Analytics](#১৮-debugging-ও-analytics)
19. [Error ও সমাধান](#১৯-error-ও-সমাধান)
20. [সম্পূর্ণ উদাহরণ](#২০-সম্পূর্ণ-উদাহরণ)
21. [OmniNetwork — API call (HTTP, Auth, Cache, Upload…)](#২১-omninetwork--api-call-http-auth-cache-upload)
22. [Migration — 0.3 থেকে 0.4](#migration--03-থেকে-04)

---

## ১. ইনস্টলেশন (All-in-One Flutter Plugin)

`omni_route` এখন একটি **All-in-One Flutter Plugin** (Android, iOS, macOS, Linux, Windows, Web)। শুধু এটি যোগ করলেই `flutter_bloc`, `omni_network`, `omni_network_flutter`, `shared_preferences`, `flutter_secure_storage` এবং নেটিভ `OmniNative` সব **অটো ইনস্টল** হয়ে যায় — আলাদা কোনো প্যাকেজ বা মাইগ্রেশন দরকার হয় না:

```yaml
dependencies:
  omni_route:
    git:
      url: https://github.com/juwelzan/omni_route.git
      ref: v0.4.0          # release tag — নতুন version এলে শুধু এটা বদলান
```

প্রয়োজন: Dart ≥ 3.12, Flutter ≥ 3.44 (`go_router` বা বাড়তি কোনো প্লাগিনের আর প্রয়োজন নেই)।

```dart
import 'package:omni_route/omni_route.dart'; // Routing, Bloc, Network, Inspector, Native সব এক ইমপোর্টেই!
```

> অ্যাডভান্সড নেটওয়ার্ক/ক্যাশ/অফলাইন কিউয়ের জন্য `package:omni_route/advanced.dart` এবং মক টেস্টের জন্য `package:omni_route/testing.dart` ব্যবহার করতে পারেন।

---

## ২. ৫ মিনিটে শুরু

```dart
import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  // Web-এ /#/students নয়, পরিষ্কার /students URL দেখাবে।
  // অবশ্যই runApp-এর আগে ডাকতে হবে। Android/iOS-এ এটা কিছুই করে না।
  OmniRoute.usePathUrls();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => OmniApp(
        // অ্যাপ খুললে প্রথমে কোন পেজ দেখাবে।
        initialRoute: '/students',

        // Global Bloc: পুরো অ্যাপের জন্য একবারই এখানে; পেজের Bloc পেজ থেকেই রেজিস্টার হয়।
        blocs: [
          // global: true → পুরো অ্যাপের জন্য একটাই instance।
          OmniBloc<AuthBloc>((_) => AuthBloc(), global: true),
        ],

        // Route টেবিল: OmniPage.screen দিয়ে পেজের নিজস্ব routePath সরাসরি ব্যবহার হয়।
        routes: [
          OmniPage.screen(const StudentScreen(), routes: [
            // '/students/:id' — child path-এ সামনে '/' অথবা পূর্ণ '/students/:id' দুটোই চলে।
            OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id'))),
          ]),
        ],

        // আপনার MaterialApp — OmniApp শুধু router-টা দেয়।
        builder: (context, router) => MaterialApp.router(routerConfig: router),
      );
}

class StudentScreen extends OmniStatelessWidget {
  const StudentScreen({super.key});

  // বাধ্যতামূলক: পেজের একক path; সব জায়গায় পেজটি চেনার জন্য ব্যবহার হয়।
  @override
  String get routePath => '/students';

  // এই screen-এর নিজস্ব Bloc — প্রথম পেজে ঢোকার সময় রেজিস্টার হয়, pop করলে বন্ধ।
  @override
  List<Provide> get provide => [Provide.bloc((_) => StudentBloc())];

  @override
  Widget build(BuildContext context) {
    final students = context.watch<StudentBloc>().state; // সাধারণ flutter_bloc
    return Scaffold(
      body: ListView(children: [
        for (final s in students)
          ListTile(
            title: Text(s.name),
            // Type দিয়ে navigation — URL string ভুল লেখার ঝুঁকি নেই; int সরাসরি চলে।
            onTap: () => OmniRoute.to<StudentDetailScreen>(path: {'id': s.id}),
          ),
      ]),
    );
  }
}
```

---

## ৩. কোন API কী কাজে — এক নজরে

| আপনি যা করতে চান | যেটা ব্যবহার করবেন |
|---|---|
| অ্যাপ সেটআপ (router, Bloc, guard একসাথে) | `OmniApp`, `OmniApp.material(...)` ও `OmniApp.cupertino(...)` (সরাসরি `config:` সহ) |
| সাধারণ (state ছাড়া) screen | `OmniStatelessWidget` |
| state সহ screen (`setState`, controller) | `OmniStatefulWidget` + `OmniState` |
| একটা URL-এ একটা screen বা সাধারণ `Widget` | `OmniPage` / `OmniPage.screen` (`blocs:`, `provide:`, `onExit:`, `title:`, `transition:`) |
| URL থেকে id, query পড়া | `OmniParams` (`p.pathInt('id')`, `p.query('tab')`, `context.params`, `params`) |
| অন্য পেজে যাওয়া / ফেরা | `OmniRoute.go / push / goPath / to<S>()` বা `screen.go(ctx)` / `context.push` |
| অ্যানিমেশন ছাড়া তাৎক্ষণিক যাওয়া | `transition: OmniPages.none` বা `animated: false` |
| পেজ-স্কোপড Bloc (প্রথম পেজে ঢোকার সময় রেজিস্টার হয়) | `OmniBloc((_) => MyBloc())` (screen `provide` বা `OmniPage(blocs:)`-এ) |
| গ্লোবাল Repository / Service ও Bloc | `OmniRepo((_) => Repo())` (`repositories:`) + `OmniBloc(..., global: true)` (`blocs:`) |
| আগে থেকেই পেজ/শেয়ার্ড ফ্যাক্টরি বা `OmniBloc.eager` | `OmniBloc.eager((c) => B(...))` বা `Provide.create` / `Provide.eager` |
| আগে থেকে তৈরি Bloc দেওয়া (OmniRoute বন্ধ করবে না) | `Provide.value(bloc)` |
| কয়েকটা route একই Bloc ভাগ করবে (detail + edit) | `OmniRouteGroup` (nested Navigator ছাড়াই) |
| সব child route-এর চারপাশে একই layout | `OmniShell` |
| Bottom navigation / tab, প্রতিটা tab নিজের stack রাখবে | `OmniStatefulShell` + `OmniBranch` |
| পেজ খোলার animation (fade, slide, scale…) বা নিজের transition | `OmniPages.adaptive`, `OmniPages.fadeSlide`, `OmniPages.transition(...)`, `OmniPages.custom(...)` |
| Login ছাড়া ঢুকতে না দেওয়া, role check | `OmniGuard` বা `OmniConfig(auth: OmniAuthConfig(...), publicScreens: ...)` |
| পেজ ছাড়ার আগে নিশ্চিত করা (unsaved form ইত্যাদি) | `OmniPage(..., onExit: (ctx) => ...)` |
| App resume/pause, screen দেখা যাচ্ছে কি না | `OmniLifecycle` mixin |
| কাস্টম Splash, Onboarding, Login/Signup ও Public রুট ফ্লো | `OmniApp(..., config: OmniConfig(...))` ও `context.flow` (৪.১) |
| keyboard বন্ধ, দুবার back-এ exit, portrait lock, font সীমা, ওভারলে | `OmniApp(dismissKeyboardOnTap:, doubleBackToExit:, orientations:, maxTextScale:, overlayBuilder:)` |
| Route ছাড়া (layout-এর ভিতরে) stateful screen বসানো | `OmniScreenHost` |
| Web-এ `#` ছাড়া URL | `OmniRoute.usePathUrls()` |
| Analytics / screen view tracking & Route ডায়াগনস্টিকস | `OmniApp(onNavigate:)` (`nav.kind`, `nav.timestamp`), `OmniRoute.paths`, `OmniApp.validateRoutes` |
| এখন কোন পেজে আছি / পুরো stack / reactive listenable | `OmniRoute.current`, `OmniRoute.stack`, `OmniRoute.currentListenable` |

---

## ৪. OmniApp — অ্যাপের মূল

`OmniApp` একবারই নেটিভ `OmniRouter` তৈরি করে (`routes` কম্পাইল করে Segment Trie
বানায়), `repositories` ও global `blocs` সবার উপরে রাখে, আর আপনার `MaterialApp.router` /
`CupertinoApp.router`-কে রেন্ডার করে। চাইলে সরাসরি শর্টকাট **`OmniApp.material(...)`** বা
**`OmniApp.cupertino(...)`** দিয়েও `builder:` লেখার ঝামেলা ছাড়াই শুরু করতে পারেন:

```dart
// ✅ সবচেয়ে কম কোডে: OmniApp.material (MaterialApp.router বিল্ট-ইন)
OmniApp.material(
  title: 'My App',
  theme: ThemeData.light(useMaterial3: true),
  darkTheme: ThemeData.dark(useMaterial3: true),
  themeModeBuilder: (c) => c.watch<ThemeBloc>().state ? ThemeMode.dark : ThemeMode.light,
  repositories: [
    OmniRepo((_) => AuthRepository(), dispose: (r) => r.dispose()),
  ],
  blocs: [
    OmniBloc((c) => AuthBloc(c.read<AuthRepository>()), global: true),
    OmniBloc((_) => ThemeBloc(), global: true),
  ],
  guards: [const AuthGuard()],
  routes: [ /* OmniPage, OmniShell, OmniStatefulShell, OmniRouteGroup */ ],
  appBuilder: (context, child) => OmniInspectorLauncher(inspector: inspector, child: child!),
)

// অথবা কাস্টম builder দিয়ে পুরো নিয়ন্ত্রণ:
OmniApp(
  // ── বাধ্যতামূলক ─────────────────────────────────────────
  routes: [ /* OmniPage, OmniShell, OmniStatefulShell, OmniRouteGroup */ ],
  builder: (context, router) => MaterialApp.router(
    routerConfig: router,      // ← এটা দিতেই হবে
    theme: ThemeData(...),     // বাকি সব আপনার মতো
  ),

  // ── ঐচ্ছিক ───────────────────────────────────────────────
  initialRoute: '/',            // শুরুর পেজ (deep link না থাকলে)
  resolveInitialRoute: null,    // async init-এর পর ডাইনামিক শুরুর রুট (/onboarding বনাম /dashboard)
  repositories: [ /* OmniRepo<...> */ ], // গ্লোবাল সার্ভিস ও রিপোজিটরি DI
  blocs: [ /* OmniBloc<...> */ ],        // Bloc factory আর global Bloc
  guards: [ /* OmniGuard */ ],           // সব route-এ চলবে এমন guard
  notFound: (context, state, error) => const NotFoundScreen(), // ভুল URL-এর পেজ

  transition: OmniPages.material, // page transition (`adaptive`, `none`, `fade`...) (১৭তম অংশ)
  setTitles: true,              // browser tab-এ screen-এর title বসাবে
  titleColor: null,             // recent-apps-এ অ্যাপের রঙ; null = theme-এর primary
  desktopBack: true,            // Desktop-এ Alt+← / Cmd+[ / mouse back
  escapeGoesBack: false,        // Desktop-এ Esc চাপলে back
  restorationScopeId: null,     // state restoration চালু করতে একটা id দিন

  onNavigate: (nav) {},         // প্রতিটা navigation-এর পর (nav.kind, nav.from, nav.to, nav.uri, nav.timestamp)
  logNavigation: false,         // true দিলে debug build-এ প্রতিটা navigation print হবে

  // অ্যাপ-লেভেল সুবিধা (সব ঐচ্ছিক, default-এ বন্ধ) — বিস্তারিত ৪.১ অংশে:
  lifecycle: null,              // পুরো অ্যাপের resume/pause hook
  onInit: null, initTimeout: null, splash: null, onInitError: null, // শুরুতে async কাজ + timeout + retry UI
  dismissKeyboardOnTap: false,  // বাইরে tap করলে keyboard বন্ধ
  doubleBackToExit: null,       // Android: দুবার back চাপলে বের হবে
  onExitWarning: null,          // প্রথম back-এ বার্তা দেখানো
  orientations: null,           // portrait / landscape lock
  minTextScale: null, maxTextScale: null, // font size-এর সীমা
  blocObserver: null,           // Bloc.observer
  onError: null,                // সব uncaught error (crash reporting)
  overlayBuilder: null,         // গ্লোবাল ওভারলে / ব্যানার / HUD

  // ঐচ্ছিক রাউটার কনফিগ:
  refreshListenable: null, navigatorKey: null, observers: null,
)
```

> 💡 `routes`, `guards`, `blocs`, `observers`, `notFound`, `refreshListenable`, `onNavigate`,
> `blocObserver`, `orientations` বদলালে **hot reload**-এই রাউট ট্রি ও লিসেনার সেফভাবে আপডেট ও রিকভার হয়
> (ভুল রুট ঠিক করলে আগের এরর স্ক্রিনও স্বয়ংক্রিয়ভাবে সেরে ওঠে)। শুধু `global: true` Bloc-এর ইনস্ট্যান্স নতুন করে
> বানাতে বা `initialRoute` বদলাতে **hot restart** দিন।
> এছাড়া `OmniApp.validateRoutes(routes)` দিয়ে স্টার্টআপ বা টেস্টে সব `routePath` আগেভাগেই যাচাই করা যায়।

**ভুল configuration:** কোনো path ভুল হলে, একই route দুবার থাকলে বা একই Bloc দুবার register করলে
অ্যাপ শুরুতেই পরিষ্কার error দেখাবে — পরে কোনো এক অজানা মুহূর্তে crash হবে না।

### ৪.১ অ্যাপ-লেভেল সুবিধা — যেগুলো আগে হাতে লিখতে হতো

নিচের প্রতিটা আগে `main()` বা root widget-এ নিজে লিখতে হতো। এখন `OmniApp`-এ একটা
parameter দিলেই হয়। সব ঐচ্ছিক — না দিলে আগের মতোই চলে।

```dart
// পুরো অ্যাপের lifecycle — WidgetsBindingObserver লিখতে হবে না
class AppLifecycle with OmniLifecycle {
  @override
  void onAppResumed(BuildContext context) =>
      context.read<AuthBloc>().add(TokenCheckRequested()); // global Bloc পড়া যায়

  @override
  void onAppPaused(BuildContext context) =>
      context.read<DraftBloc>().add(DraftSaved());
}

OmniApp.material(
  title: 'My App',
  // ① অ্যাপ-লেভেল lifecycle hook (১৩তম অংশের সব hook এখানে চলে)
  lifecycle: AppLifecycle(),

  // ② Splash + একাধিক কাস্টম Onboarding + Auth (Login/Signup/Home) + Public ভিজিট স্ক্রিন
  config: OmniConfig(
    splash: OmniSplash(
      screen: const MySplashScreen(),
      minDuration: const Duration(milliseconds: 500),
      onInit: (context) => context.read<SettingsBloc>().load(),
      timeout: const Duration(seconds: 10),
      onError: (context, error, stack, retry) => Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: retry, child: const Text('আবার চেষ্টা করুন')),
        ),
      ),
    ),
    onboarding: OmniOnboarding(
      screens: const [Step1Screen(), Step2Screen(), Step3Screen()],
      // onceUntilLoginScreen (ডিফল্ট): Login স্ক্রিনে ঢুকলেই অটো লোকাল DB-তে সেভ (কোনো ম্যানুয়াল DB কোড লাগবে না)
      // untilLoggedIn: সফল লগইন না করা পর্যন্ত প্রতিটি লঞ্চে দেখাবে
      // enabled: false দিয়ে চাইলে বন্ধ রাখা যায়
      mode: OmniOnboardingMode.onceUntilLoginScreen,
    ),
    auth: OmniAuthConfig(
      isAuthenticated: (context) => context.read<AuthBloc>().state is Authenticated,
      refreshStream: (context) => context.read<AuthBloc>().stream,
      homeRoute: '/home',
      loginScreen: const LoginScreen(),
      signupScreen: const SignupScreen(),
    ),
    publicScreens: const {
      '/about': AboutScreen(),
      '/terms': TermsScreen(),
    },
    publicRoutes: const ['/docs/*'],
  ),

  // ③ text field-এর বাইরে tap করলে keyboard বন্ধ
  dismissKeyboardOnTap: true,

  // ④ Android: প্রথম পেজে ২ সেকেন্ডের মধ্যে দুবার back চাপলে অ্যাপ বন্ধ
  doubleBackToExit: const Duration(seconds: 2),
  onExitWarning: (context) => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('বের হতে আবার back চাপুন')),
  ),

  // ⑤ শুধু portrait (OmniApp বন্ধ হলে আবার সব orientation)
  orientations: const [DeviceOrientation.portraitUp],

  // ⑥ বড় accessibility font-এ layout ভাঙবে না
  maxTextScale: 1.3,

  // ⑦ সব Bloc-এর event/state log (Bloc.observer = ... লিখতে হবে না)
  blocObserver: AppBlocObserver(),

  // ⑧ সব uncaught error এক জায়গায় — crash reporting-এর জন্য
  onError: (error, stack) => crashReporter.record(error, stack),
  ...
)
```

| Parameter | আগে হাতে যা লিখতে হতো | নোট |
|---|---|---|
| `OmniApp.material` / `.cupertino` / `OmniApp` | প্রতিবার `builder: (_, r) => MaterialApp.router(...)` | সবগুলোতে সরাসরি `config: OmniConfig(...)` বসানো যায় |
| `config` (`OmniConfig`) + `context.flow` | আলাদা `FutureBuilder`, `PageView`, Auth গার্ড ও প্রি-লগইন পাবলিক রুট চেক | `OmniSplash`, একাধিক স্ক্রিনের `OmniOnboarding` (`screens:`), `OmniAuthConfig` ও `publicScreens`/`publicPages`/`publicRoutes` |
| `OmniNative` | `device_info`, `wakelock`, keyboard hide, native cache আলাদা প্লাগিন | `OmniNative.getDeviceInfo()`, `hideKeyboard()`, `keepScreenOn()`, `clearNativeCache()` — বিল্ট-ইন নেটিভ প্লাগিনে রেডি |
| `repositories` (`OmniRepo`) | বাইরে আলাদা `MultiRepositoryProvider` র‍্যাপিং | গ্লোবাল ও পেজ Bloc-এর উপরে মাউন্ট হয় (`dispose:` সহ) |
| `lifecycle` | root widget-এ `WidgetsBindingObserver` + `addObserver`/`removeObserver` | context দিয়ে global Bloc পড়া যায় |
| `onInit` + `initTimeout` + `onInitError` + `resolveInitialRoute` | `FutureBuilder` + splash + timeout/retry + প্রথম ফ্রেমের redirect | `config:` বা সরাসরি `OmniApp` দুইভাবেই কাজ করে |
| `dismissKeyboardOnTap` | `GestureDetector(onTap: () => FocusScope.of(context).unfocus())` | text field-এ tap করলে focus থাকে; scroll করলে keyboard বন্ধ হয় না; text field-এর নিজস্ব `TapRegion` দিয়ে |
| `doubleBackToExit` | `PopScope` + সময় হিসাব + `SystemNavigator.pop()` | শুধু Android, শুধু প্রথম পেজে; বাকি পেজে back আগের মতো |
| `orientations` | `main()`-এ `SystemChrome.setPreferredOrientations` | রিবিল্ডে সিঙ্ক ও dispose হলে reset |
| `minTextScale` / `maxTextScale` | `MediaQuery` builder দিয়ে text scale clamp | dialog-সহ পুরো অ্যাপে |
| `blocObserver` | `main()`-এ `Bloc.observer = ...` | আগের observer রিবিল্ড/dispose-এ ফেরত |
| `onError` | `FlutterError.onError` + `PlatformDispatcher.onError` দুটো আলাদা | আগের handler-ও চলে; default reporting বন্ধ হয় না |

---

## ৫. Screen তৈরি

দুই ধরনের screen-এর API একদম একই রকম।

### Stateless Screen

```dart
class ProfileScreen extends OmniStatelessWidget {
  const ProfileScreen({super.key});

  // বাধ্যতামূলক: এই পেজের canonical routePath (খালি বা অবৈধ হলে error)।
  @override
  String get routePath => '/profile';

  // ঐচ্ছিক: browser tab / app switcher-এর title। না দিলে routePath থেকেই তৈরি হয় ('Profile')।
  @override
  String get title => 'আমার প্রোফাইল';

  // ঐচ্ছিক: প্রথম এই পেজে ঢোকার সময় BlocProvider রেজিস্টার হয়।
  @override
  List<Provide> get provide => [Provide.bloc((_) => ProfileBloc())];

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Profile'));
}
```

### Stateful Screen

```dart
class DashboardScreen extends OmniStatefulWidget {
  const DashboardScreen({super.key});

  @override
  String get routePath => '/dashboard';

  @override
  List<Provide> get provide => [Provide.bloc((_) => StatsBloc())];

  @override
  State<DashboardScreen> createState() => _DashboardState();
}

// OmniState: initState-সেফ routeState/params, safeSetState, onReady, onRouteChanged,
// এবং readBloc/watchBloc/go/push/pop/to শর্টকাট সহ।
class _DashboardState extends OmniState<DashboardScreen> {
  late final StatsBloc stats;

  @override
  void initState() {
    super.initState();
    // screen-এর Bloc ও routeState / params initState-এই নিরাপদে পাওয়া যায়।
    stats = readBloc<StatsBloc>();
  }

  @override
  void onReady(BuildContext context) {
    // প্রথম ফ্রেমের পর একবার (mounted থাকা অবস্থায়) চলে।
  }

  @override
  void onRouteChanged(OmniRouteState previous, OmniRouteState current) {
    // একই পেজে query বা extra বদলালে চলে।
  }

  @override
  Widget build(BuildContext context) {
    return Text('$routePath ($screenTitle) — ${routeState.uri}');
  }
}
```

| Member | কোথায় | কাজ |
|---|---|---|
| `routePath` | দুটোতেই (বাধ্যতামূলক) | পেজের একক path; route, metadata, `RouteSettings.name`, log ও navigation-এ ব্যবহার |
| `title` | দুটোতেই | browser tab / app-bar title (default `routePath` থেকে ফরম্যাট করা হয়) |
| `provide` | দুটোতেই | এই screen-এর Bloc তালিকা (`OmniBloc`, `Provide`, ...) — পেজে ঢুকলে রেজিস্টার হয় |
| `debugName` | দুটোতেই | class-এর নাম — **শুধু debug-এর জন্য** (release obfuscation-এ বদলে যায়) |
| `metadata` | দুটোতেই / `OmniState` | `OmniScreenMetadata` (`type`, `routePath`, `title`, `debugName`) |
| `routeState` / `params` | `OmniState` / `context` | `initState`-সেফ `OmniRouteState` ও `OmniParams` (`maybe*` ভার্সন সহ) |
| `readBloc` / `watchBloc` / `safeSetState` | `OmniState` | কম কোডে Bloc পড়া, শর্তসাপেক্ষ `setState` |
| `onReady` / `onRouteChanged` | `OmniState` | first-frame ও route-param পরিবর্তন হুক |
| `go` / `push` / `open` / `hosted` | `OmniScreen` ও `OmniState` | সরাসরি screen থেকেই navigate বা `OmniScreenHost`-এ র‍্যাপ |

> `OmniPage.screen(const DashboardScreen())` ব্যবহার করলে আলাদা করে path string বা builder লিখতে হয় না — screen-এর `routePath` থেকেই route তৈরি হয়।
> প্যারামিটারযুক্ত screen (`StudentDetailScreen(id: p.pathInt('id'))`)-এও `OmniPage(':id', (p) => ...)` আগের মতোই চলে।

---

## ৬. Route রেজিস্টার — OmniPage

```dart
routes: [
  // সাধারণ route
  OmniPage('/dashboard', (_) => const DashboardScreen()),

  // nested route: /students আর /students/:id
  OmniPage(
    '/students',
    (_) => const StudentScreen(),
    name: 'students',                       // ঐচ্ছিক: নাম দিয়ে navigation (goNamed)
    metadata: const {'section': 'school'},  // ঐচ্ছিক: নিজের তথ্য (guard, analytics)
    routes: [
      OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id'))),
      OmniPage(':id/edit', (p) => StudentEditScreen(id: p.pathInt('id'))),
    ],
  ),

  // শুধু এই route-এর guard (১২তম অংশ)
  OmniPage('/admin', (_) => const AdminScreen(), guards: [adminGuard]),

  // শুধু এই route-এর transition (১৭তম অংশ)
  OmniPage('/popup', (_) => const PopupScreen(), transition: OmniPages.none),

  // সাধারণ Flutter Widget-ও সরাসরি OmniPage-এ চলে (ইনলাইন Bloc, title, onExit সহ)
  OmniPage('/about', (_) => const AboutWidget(), title: 'About'),
  OmniPage(
    '/draft',
    (_) => const DraftWidget(),
    provide: [Provide<DraftBloc>.create((_) => DraftBloc())],
    onExit: (context) => confirmDiscard(context),
  ),
]
```

**Path-এর নিয়ম** (ভুল হলে অ্যাপ শুরুতেই error):

| নিয়ম | ঠিক | ভুল |
|---|---|---|
| top-level path `/` দিয়ে শুরু | `/students` | `students` |
| child path `/` ছাড়া | `':id'`, `'edit'` | `'/edit'` |
| ছোট হাতের অক্ষর | `/students` | `/Students` |
| শেষে `/` নয় | `/students` | `/students/` |
| `#`, `?`, `//` নয় | `/a/b` | `/a//b`, `/a?x=1` |
| parameter: `:নাম` (বা wildcard `*rest`) | `:id`, `*files` | `:1d` |
| একই URL দুবার নয় | — | `/a/:id` আর `/a/:slug` একসাথে |
| একই `name` দুবার নয় | — | দুটো route-এর `name: 'x'` |

> স্ট্যাটিক সেগমেন্ট সবসময় `:param`-এর আগে ম্যাচ হয় (যেমন `/users/new` আগে রেজিস্টার করা
> না থাকলেও `/users/:id`-কে ছাপিয়ে ম্যাচ হবে)।
>
> ⚠️ **Route list-এর type:** route গুলো `List<OmniPage>` টাইপের ভেরিয়েবলে রাখলে Dart
> screen-এর type হারিয়ে ফেলে, আর `OmniRoute.to<Screen>()` route খুঁজে পায় না।
> `List<OmniRouteBase>` ব্যবহার করুন (অথবা `OmniPage<MyScreen>(...)` লিখুন)।
>
> ```dart
> final List<OmniRouteBase> studentRoutes = [ OmniPage(...), OmniPage(...) ]; // ✅
> ```

---

## ৭. Route Parameter — OmniParams

`OmniPage`-এর builder-এ `p` হলো `OmniParams` — URL থেকে মান পড়ার সহজ উপায়।
সব মান আগে থেকেই decode করা থাকে।

```dart
// URL: /attendance/10?section=A&date=2026-11-15&late=true&sort=newest&tag=x&tag=y
OmniPage('/attendance/:class', (p) => AttendanceScreen(
  classNo:  p.pathInt('class'),             // 10      — path parameter (int)
  section:  p.query('section'),             // 'A'     — query (String?, না থাকলে null)
  page:     p.queryInt('page'),             // null    — query (int?)
  lateOnly: p.queryBool('late'),            // true    — true/false/1/0
  minScore: p.queryDouble('min'),           // null    — query (double?)
  sort:     p.queryEnum('sort', Sort.values), // Sort.newest — enum নাম দিয়ে
  tags:     p.queryAll('tag'),              // ['x','y'] — একই query একাধিকবার
  student:  p.extra<Student>(),             // push-এর সময় পাঠানো object
));
```

| Method | ফেরত দেয় | না থাকলে | ভুল মান হলে |
|---|---|---|---|
| `path(name)` | `String` | error page | — |
| `pathInt(name)` | `int` | error page | error page |
| `query(name)` | `String?` | `null` | — |
| `queryInt / queryDouble / queryBool` | `int? / double? / bool?` | `null` | error page |
| `queryEnum(name, values)` | `T?` | `null` | error page |
| `queryAll(name)` | `List<String>` | `[]` | — |
| `extra<T>()` | `T?` | `null` | error page |
| `uri` / `state` | পুরো `Uri` / `OmniRouteState` | — | — |

> ভুল মান (যেমন `/students/abc`-এ `pathInt`) অ্যাপ crash করায় না — not-found পেজ দেখায়।

**Bloc factory, `initState`, বা `build`-এ parameter লাগলে:** `OmniParams.of(context)` বা `context.params`
(`OmniParams.of(context)` subscribe করে না, তাই `initState`/Bloc factory-তেও নিরাপদ):

```dart
Provide<StudentBloc>.create(
  (context) => StudentBloc(OmniParams.of(context).pathInt('id')),
)
```

> ⚠️ `extra` URL-এ থাকে না — Web-এ refresh করলে হারিয়ে যায়।
> refresh-এর পরেও যা লাগবে, তা path বা query-তে রাখুন। গোপন তথ্য (token, password) কখনো URL-এ নয়।

---

## ৮. Navigation — OmniRoute ও BuildContext এক্সটেনশন

`OmniRoute`-এর সব method সরাসরি নেটিভ `OmniRouter`-এ কাজ করে — এবং `BuildContext` থেকেই
`context.go`, `context.push`, `context.pop`, `context.to<S>` ব্যবহার করা যায় (`OmniRouteContext`)।

```dart
// ── URL দিয়ে ─────────────────────────────────────────────
OmniRoute.go('/students/101?tab=info'); // পুরো stack বদলে এখানে যাও ("clear and go")
OmniRoute.push('/students/101');         // উপরে নতুন পেজ (back দিলে আগেরটায় ফিরবে)
OmniRoute.replace('/login');             // উপরের পেজটা বদলে দাও
OmniRoute.pop();                         // উপরের পেজ বন্ধ
OmniRoute.maybePop();                    // pop করা গেলে করবে, না গেলে false (crash নয়)
OmniRoute.canPop();                      // pop করা যাবে কি না

// ── অ্যানিমেশন ছাড়া বা আলাদা ট্রানজিশনে নেভিগেশন ────────────
OmniRoute.push('/fast', animated: false);                    // কোনো অ্যানিমেশন ছাড়াই তাৎক্ষণিক খোলা
OmniRoute.push('/sheet', transition: OmniPages.slideUp);     // শুধু এই কলের জন্য slideUp
context.go('/dashboard', animated: false);                   // context দিয়েও একইভাবে চলে

// ── ফলাফল ফেরত পাওয়া ───────────────────────────────────
final saved = await OmniRoute.push<bool>('/students/101/edit');
// edit পেজে: OmniRoute.pop(true); অথবা context.pop(true);

// ── Screen-এর Type দিয়ে (string ছাড়া; int/Enum সরাসরি) ───
OmniRoute.to<StudentDetailScreen>(path: {'id': 101}, query: {'tab': 'info'}); // go
OmniRoute.pushTo<StudentDetailScreen, bool>(path: {'id': 101});               // push
OmniRoute.replaceTo<LoginScreen>();                                           // replace
OmniRoute.locationOf<StudentDetailScreen>(path: {'id': 101}); // '/students/101'

// ── BuildContext এক্সটেনশন ─────────────────────────────────
context.params.pathInt('id');
context.pushTo<StudentEditScreen, bool>(path: {'id': 101});

// ── Route-এর নাম দিয়ে ───────────────────────────────────
OmniRoute.goNamed('students');
OmniRoute.pushNamed('student', path: {'id': 101});
OmniRoute.replaceNamed('login');

// ── open: duplicate ছাড়া ১ ফ্রেমে খোলা ──────────────────────
OmniRoute.open('/students/101');
// উপরেই থাকলে কিছু হয় না; stack-এ আগে থেকে থাকলে ১ ফ্রেমে সেখানে ফিরে আসে;
// না থাকলে push; stack-এ ১০টা (maxDepth) পেজ হয়ে গেলে go (stack নতুন করে)
OmniRoute.open('/cart', maxDepth: 6);
OmniRoute.openTo<StudentDetailScreen>(path: {'id': 101});

// ── একসাথে কয়েকটা পেজ ১ ফ্রেমে বন্ধ ─────────────────────────
await OmniRoute.popUntil('/students'); // '/students' উপরে না আসা পর্যন্ত ১ ফ্রেমে pop; না থাকলে false
await OmniRoute.popToRoot();           // প্রথম পেজে ফেরা (shell-এ বর্তমান tab-এর প্রথম পেজ)
// দুটোই PopScope উপেক্ষা করে সরাসরি ১ ফ্রেমে পপ সম্পন্ন করে

// ── অন্যান্য ─────────────────────────────────────────────
OmniRoute.refresh();           // বর্তমান পেজের guard আবার চালাও
OmniRoute.location;            // এখনকার URL (push করা পেজ সহ)
OmniRoute.currentListenable;   // ValueListenable<OmniRouteEntry> — মেনু/অ্যানালিটিক্সের জন্য
OmniRoute.router;              // নেটিভ OmniRouter ইঞ্জিন
```

| কখন কোনটা | |
|---|---|
| Menu / tab থেকে অন্য অংশে যাওয়া | `go` |
| তালিকা থেকে detail খোলা (back-এ ফিরবে) | `push` |
| Login সফল হলে login পেজ সরিয়ে home | `go` বা `replace` |
| Form থেকে ফলাফল নিয়ে ফেরা | `push<T>` + `pop(result)` |
| প্রথম পেজে back বাটন (crash এড়াতে) | `maybePop` |
| একই পেজ দুবার না জমিয়ে খোলা (swipe-back-এর জন্য ভালো) | `open` / `openTo<S>` |
| Form-এর কয়েক ধাপ পেরিয়ে তালিকায় ফেরা | `popUntil` |
| সব বন্ধ করে প্রথম পেজে | `popToRoot` |

> একাধিক `OmniApp` একসাথে থাকলে (যেমন desktop-এর কয়েকটা window) `OmniRoute.*` সবশেষে
> চালু হওয়া অ্যাপে কাজ করে। অন্যটার ভিতর থেকে `context.go(...)` ব্যবহার করুন।

---

## ৯. Bloc — কোথায় কোনটা

### ধাপ ১: Global Bloc আর Page Bloc আলাদা রাখুন

- **পুরো অ্যাপের Bloc (`global: true`)** শুধু `OmniApp(blocs: [...])`-এ থাকবে।
- **পেজ/স্ক্রিনের নিজস্ব Bloc** অ্যাপ শুরুতে রেজিস্টার করার দরকার নেই — সরাসরি screen-এর `provide` বা `OmniPage(blocs: [...])`-এ `OmniBloc((_) => MyBloc())` লিখে দিন। **অ্যাপ প্রথমবার ওই পেজে ঢোকার সময়ই** `BlocProvider` রেজিস্টার ও তৈরি হবে এবং পেজ থেকে বের হলে বন্ধ হয়ে যাবে।

```dart
OmniApp(
  blocs: [
    // পুরো অ্যাপের জন্য একটাই (login, theme)
    OmniBloc<AuthBloc>((_) => AuthBloc(), global: true, lazy: false),
    OmniBloc<ThemeBloc>((_) => ThemeBloc(), global: true),
  ],
  ...
)
```

- `global: true` → অ্যাপ চালু থাকা পর্যন্ত বাঁচে; সব জায়গা থেকে `context.read<AuthBloc>()` বা `readBloc<AuthBloc>()`।
- `OmniBloc.eager(...)` / `lazy: false` → পেজে ঢোকার সাথে সাথেই ইনস্ট্যান্স তৈরি হয় (সাধারণত প্রথম ব্যবহারের সময়)।
- `Bloc` আর `Cubit` দুটোই চলে: `OmniBloc((_) => CounterCubit())`,
  `Provide<CounterCubit>()`, `Provide.value(cubit)` — সব জায়গায় একই নিয়ম।

### ধাপ ২: Screen বা Page-এ Bloc ঘোষণা করুন

```dart
// সবচেয়ে সংক্ষিপ্ত উপায় — পেজে ঢুকলেই রেজিস্টার ও তৈরি হয়:
@override
List<Provide> get provide => [
  Provide.bloc((_) => StudentBloc()),                              // lazy page Bloc
  Provide.blocEager((_) => DashboardBloc()),                       // পেজে ঢুকতেই eager তৈরি
  Provide<StudentDetailBloc>.create((_) => StudentDetailBloc(id)), // প্যারামিটার সহ
  Provide.value(existingCartBloc),                               // আগে থেকে তৈরি — OmniRoute বন্ধ করবে না
];
```

### কোনটা কতক্ষণ বাঁচে

| ধরন | কোথায় লিখবেন | কখন তৈরি | কখন বন্ধ |
|---|---|---|---|
| Global | `OmniBloc(..., global: true)` | অ্যাপ শুরুতে / প্রথম ব্যবহারে | অ্যাপ বন্ধ হলে |
| Route Group | `OmniRouteGroup(provide:)` | group-এর কোনো route-এ ঢুকলে | group থেকে বেরোলে |
| Shell | `OmniShell(provide:)` | shell দেখালে | shell সরে গেলে |
| Page | screen-এর `provide` | পেজ খুললে | পেজ pop / replace হলে |
| Route-এর বাইরের Screen | screen-এর `provide` | screen বসালে | screen সরালে |
| বাইরের | `Provide.value(bloc)` | আপনি | **কখনো OmniRoute বন্ধ করে না** |

নিশ্চয়তা (সব test দিয়ে যাচাই করা):
- rebuild হলে Bloc আবার তৈরি হয় না
- উপরে নতুন পেজ push করলে নিচের পেজের Bloc বাঁচে
- লুকানো tab-এর Bloc বাঁচে
- প্রতিটা Bloc ঠিক একবার বন্ধ হয়
- global Bloc কোনো screen আবার `Provide` করতে পারে না (করলে error)

---

## ১০. Shell ও Tab

### OmniShell — কয়েকটা route-এর চারপাশে একই layout

```dart
OmniShell(
  // shell যতক্ষণ দেখা যায়, ততক্ষণ এই Bloc বাঁচে
  provide: const [Provide<InboxBloc>()],
  // child = ভিতরের route-এর পেজ
  builder: (context, state, child) => AppFrame(child: child),
  routes: [
    OmniPage('/inbox', (_) => const InboxScreen()),
    OmniPage('/inbox/:id', (p) => MessageScreen(id: p.path('id'))),
  ],
),
```

### OmniStatefulShell — Bottom Navigation (প্রতিটা tab নিজের stack রাখে)

```dart
OmniStatefulShell(
  builder: (context, state, shell) => Scaffold(
    body: shell, // বর্তমান tab (`OmniNavigationShell`)
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch, // tab বদল
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
      ],
    ),
  ),
  branches: [
    OmniBranch(routes: [OmniPage('/home', (_) => const HomeScreen())]),
    OmniBranch(routes: [OmniPage('/students', (_) => const StudentScreen())]),
  ],
),
```

tab বদলালে প্রতিটা tab-এর পেজের stack, scroll, `setState`-এর মান আর Bloc — সব থেকে যায়। প্রতিটা `OmniBranch`-এ নিজস্ব `provide:`, `initialLocation:`, `observers:`, ও `restorationScopeId:` দেওয়া যায়।

---

## ১১. Route Group

Nested route গুলো আলাদা আলাদা পেজ — তাই `/students/7/edit` পেজ তার parent
`/students/7`-এর Bloc পড়তে পারে না। কোনো **Nested Navigator ছাড়াই** (যাতে `Hero`,
`OmniSwipeBack`, আর `OmniExitGuard` ঠিকঠাক চলে) একই Bloc কয়েকটা route-এ ভাগ করতে `OmniRouteGroup`:

```dart
OmniPage('/students', (_) => const StudentListScreen(), routes: [
  OmniRouteGroup(
    // id বদলালে (অন্য student) পুরনো Bloc বন্ধ হয়ে নতুন তৈরি হবে
    scopeKey: (state) => state.pathParameters['id'],
    provide: [
      Provide<StudentBloc>.create(
        (context) => StudentBloc(OmniParams.of(context).pathInt('id')),
      ),
    ],
    routes: [
      OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id')), routes: [
        OmniPage('edit', (_) => const StudentEditScreen()), // একই StudentBloc
      ]),
    ],
  ),
]),
```

- group-এর কোনো route-এ ঢুকলে Bloc তৈরি
- detail ↔ edit যাওয়া-আসায় একই instance
- group-এর বাইরের পেজ উপরে push করলেও বাঁচে
- group থেকে বেরোলে (`go('/students')`, back) বন্ধ

---

## ১২. Guard — Login, Role, Permission

Guard ঠিক করে কোন পেজ দেখানো যাবে। `null` ফেরত = ঢুকতে দাও; একটা path ফেরত = সেখানে পাঠাও।

### Login guard (পুরো অ্যাপে)

```dart
class AuthGuard extends OmniGuard {
  const AuthGuard();

  // AuthBloc-এর state বদলালে (login/logout) guard আবার চলবে
  @override
  Stream<Object?> refresh(BuildContext context) => context.read<AuthBloc>().stream;

  @override
  String? redirect(BuildContext context, OmniRouteState state) {
    final loggedIn = context.read<AuthBloc>().state.isLoggedIn;
    final atLogin = state.matchedLocation == '/login';

    // login নেই → login পেজে, আর কোথায় যেতে চেয়েছিল তা মনে রাখো
    if (!loggedIn && !atLogin) {
      return Uri(path: '/login', queryParameters: {'from': state.uri.toString()}).toString();
    }
    // login হয়ে গেছে কিন্তু login পেজে → আগের জায়গায় ফেরত
    if (loggedIn && atLogin) return state.uri.queryParameters['from'] ?? '/';
    return null; // ঢুকতে দাও
  }
}

OmniApp(guards: const [AuthGuard()], ...);
```

### নির্দিষ্ট route-এ guard

```dart
final adminGuard = OmniGuard.fn(
  (context, state) => context.read<AuthBloc>().state.isAdmin ? null : '/denied',
  refresh: (context) => context.read<AuthBloc>().stream, // role বদলালে আবার চেক
);

OmniPage('/admin', (_) => const AdminScreen(), guards: [adminGuard]),
```

### metadata দিয়ে একটা guard-এ অনেক route

```dart
OmniPage('/reports', (_) => const ReportScreen(), metadata: const {'roles': ['admin', 'teacher']}),

final roleGuard = OmniGuard.fn((context, state) {
  final roles = state.metadata?['roles'] as List<String>?;
  if (roles == null) return null; // role দরকার নেই
  final mine = context.read<AuthBloc>().state.roles;
  return roles.any(mine.contains) ? null : '/denied';
});
```

নিয়ম:
- guard একের পর এক চলে; প্রথম যেটা path দেয়, সেটাই জেতে
- `async` guard চলে (`Future<String?>`); sync guard-এ কোনো বাড়তি delay নেই
- নিজের জায়গাতেই redirect করলে উপেক্ষা হয়; বড় loop হলে error পেজ (অসীম loop নয়)
- `OmniRoute.refresh()` দিয়ে হাতে guard আবার চালানো যায়
- guard-এ API call করবেন না — আগে থেকে load করা state (Bloc) পড়ুন

> 🔒 **Guard নিরাপত্তা নয়।** Guard শুধু UI-তে কী দেখাবে তা ঠিক করে। প্রতিটা permission
> আপনার backend-এও অবশ্যই যাচাই করতে হবে।

---

## ১৩. Lifecycle Hook — OmniLifecycle

`WidgetsBindingObserver`, `addObserver`, `removeObserver` — কিছুই লিখতে হবে না।
screen-এ `with OmniLifecycle` যোগ করে শুধু দরকারি hook override করুন।
register আর cleanup নিজে থেকেই হয়।

```dart
// Stateless screen-এ
class FeedScreen extends OmniStatelessWidget with OmniLifecycle {
  const FeedScreen({super.key});

  @override
  String get routePath => '/feed';

  // অ্যাপে ফিরে এলে নতুন data আনো
  @override
  void onAppResumed(BuildContext context) =>
      context.read<FeedBloc>().add(FeedRefreshed());

  @override
  Widget build(BuildContext context) => const FeedList();
}

// Stateful screen-এ — mixin যায় State-এ (widget-এ দিলে hook চলে না;
// debug build-এ একবার `OmniRouteException(lifecycleOnWidget)` দেখাবে)
class _PlayerState extends OmniState<PlayerScreen> with OmniLifecycle {
  // উপরে অন্য পেজ এলে, tab বদলালে বা pop হলে
  @override
  void onScreenHidden(BuildContext context) => player.pause();

  // আবার দেখা গেলে
  @override
  void onScreenVisible(BuildContext context) => player.resume();

  // অ্যাপ background-এ গেলে
  @override
  void onAppPaused(BuildContext context) => player.pause();

  @override
  Widget build(BuildContext context) => PlayerView(player);
}
```

| Hook | কখন ডাকা হয় | সাধারণ ব্যবহার |
|---|---|---|
| `onAppResumed` | অ্যাপ আবার সামনে এলে | data refresh, token check |
| `onAppInactive` | focus হারালে (call, app switcher) | timer থামানো |
| `onAppHidden` | অ্যাপ দেখা যাচ্ছে না | animation থামানো |
| `onAppPaused` | background-এ গেলে | draft save, media pause |
| `onAppDetached` | engine বন্ধ হওয়ার আগে | শেষ cleanup |
| `onAppLifecycleChanged(state)` | উপরের সবগুলোতে (আগে) | একসাথে সব দেখতে |
| `onScreenVisible` | screen দেখা যেতে শুরু করলে | screen-view analytics, video চালানো |
| `onScreenHidden` | screen ঢাকা পড়লে / tab বদলালে / pop হলে | video থামানো, timer থামানো |
| `onMemoryPressure` | মেমরি কম | cache খালি করা |
| `onMetricsChanged` | size, rotation, keyboard | layout হিসাব |
| `onBrightnessChanged(b)` | light/dark mode বদল | chart-এর রং |
| `onLocalesChanged(l)` | ভাষা বদল | ভাষা-নির্ভর data আবার আনা |
| `onTextScaleChanged` | font size বদল | — |

নিয়ম:
- hook `build`-এর বাইরে চলে — `setState` বা Bloc event পাঠানো নিরাপদ
- screen dispose হওয়ার পর কোনো hook চলে না
- push করলে আগে পুরনো পেজের `onScreenHidden`, তারপর নতুনটার `onScreenVisible`
- app/system hook ঢাকা পড়া পেজ আর লুকানো tab-এও যায়
- যে screen-এ mixin নেই, তার উপর কোনো প্রভাব বা খরচ নেই

---

## ১৪. Route-এর বাইরে Screen — OmniScreenHost

কখনো screen route ছাড়া সরাসরি layout-এ বসে (tablet master–detail, dialog)।

```dart
Row(children: [
  // Stateless: নিজে থেকেই নিজের Bloc তৈরি করে
  const Expanded(child: StudentListScreen()),

  // Stateful: .hosted() বা OmniScreenHost দিয়ে মুড়ে দিন
  Expanded(child: const DashboardScreen().hosted()),
])
```

stateful screen মুড়তে ভুলে গেলে পরিষ্কার `screenNotHosted` error আসে (কী করতে হবে সহ)।

---

## ১৫. Web — পরিষ্কার URL

```dart
void main() {
  OmniRoute.usePathUrls(); // runApp-এর আগে
  runApp(const MyApp());
}
```

পাওয়া যায়: `https://example.com/students/101`, browser back/forward, refresh,
সরাসরি URL খোলা, tab-এ title, আর `/students/` → `/students` নিজে থেকেই।
এছাড়া **`OmniRoute.replace(...)`**, **`AuthGuard` রিডাইরেক্ট**, এবং **`go(..., replaceHistory: true)`** /
**`OmniRoute.neglect(...)`** ওয়েবে `window.history.replaceState` ব্যবহার করে — ফলে Login → Home-এ যাওয়ার পর
ব্রাউজারের Back বোতামেও আর Login বা চলে যাওয়া স্ক্রিনে ফেরা যায় না।

**⚠️ Server-কে বলতে হবে অজানা path-এ `index.html` দিতে** — নাহলে refresh-এ 404:

```nginx
# Nginx
location / { try_files $uri $uri/ /index.html; }
```

```apache
# Apache (.htaccess)
FallbackResource /index.html
```

Subdirectory-তে (`example.com/myapp/`) deploy করলে:

```bash
flutter build web --base-href /myapp/
```

Firebase, Netlify, Vercel, GitHub Pages-এর setting: [doc/web.md](doc/web.md)।

---

## ১৬. Deep Link

OS থেকে link এলে `OmniRouter` সেটা খোলে, আর আপনার guard-ও চলে
(login না থাকলে login পেজ → login-এর পর linked পেজ)।
এর জন্য platform-এ সেটআপ লাগে:

- **Android App Links:** `AndroidManifest.xml`-এ `autoVerify` intent-filter + `/.well-known/assetlinks.json`
- **iOS Universal Links:** Associated Domains (`applinks:example.com`) + `/.well-known/apple-app-site-association`

পুরো ধাপ আর test command: [doc/platforms.md](doc/platforms.md#deep-links)।

---

## ১৭. Platform সেটিং

### Page transition

```dart
OmniApp(transition: OmniPages.material, ...)                // default — প্রতিটা platform-এর নিজস্ব animation
OmniApp(transition: OmniPages.adaptive, ...)                // Web-এ instant `none`, Apple-এ `cupertino`, অন্যত্র `material`
OmniApp(transition: OmniPages.cupertino, ...)               // সব জায়গায় iOS-এর মতো slide + swipe-back
OmniApp(transition: OmniPages.none, ...)                    // animation নেই — শূন্য ফ্রেমে ওপেন
OmniPage('/x', builder, transition: OmniPages.none)         // শুধু একটা route-এ animation বন্ধ
OmniRoute.push('/x', animated: false);                      // যেকোনো navigation কল-এ তাৎক্ষণিক খোলা
OmniRoute.push('/sheet', transition: OmniPages.slideUp);    // কল-এর সময় আলাদা transition
```

#### Built-in animation (smooth আর দ্রুত)

```dart
// পুরো অ্যাপে একটা animation — যে screen-এই যান, একই রকম smooth
OmniApp(transition: OmniPages.fadeSlide, ...)

// শুধু একটা route-এ আলাদা animation
OmniPage('/students/:id/edit', builder, transition: OmniPages.slideUp)
```

| `OmniPages.` | দেখতে কেমন | কোথায় মানায় |
|---|---|---|
| `fade` | আস্তে আস্তে দেখা যায় | tab-এর মতো অংশ বদল, web |
| `slide` | ডান দিক থেকে ঢোকে (RTL ভাষায় বাম দিক থেকে), নিচের পেজ একটু সরে | তালিকা → detail |
| `slideUp` | নিচ থেকে উপরে ওঠে | নতুন তৈরি / edit form, sheet |
| `scale` | ৯২% থেকে বড় হয়ে fade-in | ছবি / card খোলা |
| `fadeScale` | ৯৬% থেকে হালকা zoom + fade | detail, dialog-এর মতো পেজ |
| `fadeSlide` | fade-in-এর সাথে একটু উপরে ওঠে | আধুনিক, হালকা default |

সব built-in খোলে **২৫০ms**-এ আর বন্ধ হয় **২০০ms**-এ, `easeOutCubic` curve-এ।
শুধু opacity আর transform ব্যবহার করে (GPU-তে চলে, প্রতি frame-এ layout হিসাব হয় না),
তাই দুর্বল ফোনেও smooth।

#### সময় আর curve নিজে ঠিক করা

```dart
OmniApp(
  transition: OmniPages.transition(
    OmniTransition.slide,                          // কোন animation
    duration: const Duration(milliseconds: 200),   // খোলার সময়
    reverseDuration: const Duration(milliseconds: 160), // বন্ধের সময়
    curve: Curves.easeOutQuart,                    // গতির ধরন
  ),
  ...
)
```

#### নিজের animation (transition builder)

```dart
// Flutter-এর transitionsBuilder-এর মতোই signature
final rotateIn = OmniPages.custom(
  (context, animation, secondaryAnimation, child) => RotationTransition(
    turns: animation.drive(Tween(begin: 0.95, end: 1.0)),
    child: FadeTransition(opacity: animation, child: child),
  ),
  duration: const Duration(milliseconds: 300),
);

OmniPage('/promo', (_) => const PromoScreen(), transition: rotateIn);

// Dialog-এর মতো পেজ: পিছনের পেজ দেখা যাবে, বাইরে tap করলে বন্ধ
OmniPage('/filter', (_) => const FilterScreen(), transition: OmniPages.custom(
  (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  opaque: false,
  barrierColor: Colors.black54,
  barrierDismissible: true,
));
```

### Dialog আর Bottom sheet — route হিসেবে

দরকার হলে dialog বা sheet-ও একটা URL পায়, আর `push<T>` দিয়ে খুলে ফলাফল ফেরত নেওয়া যায়:

```dart
OmniPage('/confirm', (_) => const ConfirmScreen(),
  transition: OmniPages.dialog(),                 // পিছনের পেজ দেখা যায়; বাইরে tap করলে বন্ধ
),
OmniPage('/pick-class', (_) => const PickClassScreen(),
  transition: OmniPages.bottomSheet(showDragHandle: true, isScrollControlled: true),
),

// Screen নিজেই dialog/sheet-এর ভেতরটা বানায়
class ConfirmScreen extends OmniStatelessWidget {
  const ConfirmScreen({super.key});
  @override
  String get routePath => '/confirm';
  @override
  String get title => 'Confirm';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('মুছে ফেলবেন?'),
    actions: [
      TextButton(onPressed: () => OmniRoute.pop(false), child: const Text('না')),
      FilledButton(onPressed: () => OmniRoute.pop(true), child: const Text('হ্যাঁ')),
    ],
  );
}

// ব্যবহার — pop(true) দিলে true আসে; বাইরে tap বা back করলে null
final ok = await OmniRoute.push<bool>('/confirm');
if (ok ?? false) deleteStudent();
```

| Option | মানে |
|---|---|
| `dialog(barrierColor:, barrierDismissible:)` | পিছনের অন্ধকার রঙ (ডিফল্ট `black54`); বাইরে tap করলে বন্ধ হবে কি না (ডিফল্ট হ্যাঁ) |
| `bottomSheet(showDragHandle:, isScrollControlled:)` | উপরে টানার handle; অর্ধেকের বেশি উঁচু হতে পারবে কি না |

> 💡 **দ্রুত রাখার টিপস:** animation-এ `animation.drive(...)` ব্যবহার করুন
> (প্রতি frame-এ নতুন object তৈরি হয় না); blur বা `ClipPath`-এর মতো ভারী effect এড়িয়ে চলুন।
>
> ⚠️ **Android predictive back animation** শুধু `material`-এ থাকে। custom animation-এ back বাটন
> আর system back ঠিকই কাজ করে। custom animation-এ swipe-back চাইলে নিচের **Swipe back** দেখুন।

### Swipe back ও predictive back — কিনারা থেকে টেনে পেজ বন্ধ (0.2.5; ৮টা style 0.2.6; Android predictive back 0.3.1)

<!-- GIF: docs/swipe_back_zoom.gif (push → অর্ধেক টেনে ছেড়ে দেওয়া → পুরো টেনে zoom-out pop) -->
![Swipe back zoom](docs/swipe_back_zoom.gif)

আগে custom animation (`fade`, `slide`, `custom`…) দিলে swipe-back থাকত না। এখন যেকোনো animated
পেজে swipe-back আলাদা layer হিসেবে যোগ করা যায়। এটা ডিফল্টে **বন্ধ**, তাই পুরনো অ্যাপ আগের মতোই চলে।
নিচে `p` মানে কতটা টানা হয়েছে (০ = ছোঁয়া হয়নি, ১ = পুরো বন্ধ)।

| Style | কী হয় |
|---|---|
| `none` | gesture নেই (ডিফল্ট) |
| `slide` | iOS-এর মতো: পেজ আঙুলের সাথে ১:১ সরে, কিনারায় হালকা ছায়া; নিচের পেজ -৩০% থেকে ভেসে আসে |
| `zoom` | ১ → ০.৮২ ছোট হয়, আঙুলের ৪৫% সরে, কোনা গোল (সর্বোচ্চ ২৮), p > ০.৭৫ হলে মিলিয়ে যায়; নিচের পেজ বদলায় না |
| `zoomCenter` | জায়গায় দাঁড়িয়ে মাঝখানে ০.৭৫ পর্যন্ত ছোট হয়, p = ০.৫ থেকে মিলিয়ে যায় — পেজ যেন স্ক্রিনের ভেতরে পড়ে যায় |
| `zoomToEdge` | যেদিকে টানছেন সেই কিনারার দিকে ০.৭ পর্যন্ত ছোট হয়, ২৫% সরে — যেন পাশে ঠেলে বের করা |
| `zoomFollow` | আঙুল যেখানে, সেখানকে কেন্দ্র করে ০.৮ পর্যন্ত ছোট হয়, আঙুলের ৬০% সরে — যেন একটা card হাতে ধরা |
| `zoomCard` | `zoom`-এর মতো (০.৮৫) + চারপাশে নরম ছায়া; নিচের পেজ প্রথমে একটু অন্ধকার, খোলার সাথে উজ্জ্বল হয় |
| `zoomParallax` | দুটো পেজই zoom: উপরেরটা `zoom`, নিচেরটা ০.৯৪ → ১ বড় হয় (পিছনে background রঙ, কালো কিনারা নেই) |
| `zoomTilt` | `zoom` + দরজার মতো হালকা 3D ঘোরা (`maxTilt`, ডিফল্ট ০.২৫ rad) |

```dart
// ১) পুরো অ্যাপে: সব animated পেজে (fade, slide, transition(...), custom(...))
OmniApp(
  transition: OmniPages.fade,
  swipeBack: OmniSwipeBack.zoomCard,
  swipeBackStyle: const OmniSwipeBackStyle(minScale: 0.85, maxRadius: 24),
  ...
)

// ২) শুধু একটা page type-এ (অ্যাপের ডিফল্ট বন্ধ থাকলেও কাজ করে)
OmniPages.transition(OmniTransition.fade, swipeBack: OmniSwipeBack.zoomTilt);
OmniPages.custom(myBuilder, swipeBack: OmniSwipeBack.zoomFollow);

// ৩) কোনো পেজে বন্ধ রাখা (অ্যাপের ডিফল্ট চালু থাকলেও)
OmniPages.transition(OmniTransition.slideUp, swipeBack: OmniSwipeBack.none);

// ৪) নিজের মতো সংখ্যা — null রাখলে প্রতিটা style-এর নিজের ডিফল্ট
const OmniSwipeBackStyle(
  minScale: 0.88,        // পুরো টানলে কত ছোট হবে
  maxRadius: 20,         // কোনার সর্বোচ্চ গোলভাব (px)
  slideFactor: 0.45,     // আঙুলের দূরত্বের কত অংশ পেজ সরবে
  fadeStart: 0.75,       // কতটা টানার পর মিলিয়ে যেতে শুরু করবে
  maxTilt: 0.2,          // zoomTilt-এ সর্বোচ্চ ঘোরা (radian) — ছোট রাখুন
  shadow: true,          // চলমান পেজের চারপাশে ছায়া
  dimBelow: true,        // নিচের পেজ অন্ধকার থেকে উজ্জ্বল
  backgroundColor: Colors.black, // zoomParallax-এ নিচের পেজের পিছনে
  edgeWidth: 28,         // কিনারার কতটা জায়গা থেকে শুরু (safe area বড় হলে সেটা)
  edges: {OmniSwipeEdge.left},   // শুধু বাম কিনারা
  closeThreshold: 0.5,   // অর্ধেকের বেশি টানলে বন্ধ
  flickVelocity: 1.0,    // দ্রুত টানলে (screen-width/second) কম টানলেও বন্ধ
);

// ৫) তৈরি preset
OmniSwipeBackStyle.subtle();   // কম zoom, tilt নেই
OmniSwipeBackStyle.dramatic(); // বেশি zoom, ছায়া, dim
```

```dart
// ৬) তৈরি transition — reference আচরণ: খোলার সময় হালকা zoom-in + fade, টানলে zoom-out
OmniApp(transition: OmniPages.swipeZoom, ...)
```

#### Android predictive back (Android 14+, system-এর back gesture)

Android-এ gesture navigation চালু থাকলে স্ক্রিনের কিনারা system-এর — অ্যাপের নিজের কিনারা-strip সেখানে
প্রায় কখনো gesture পায় না। তাই system-এর back gesture-ও একই zoom style-এ চালাতে:

```dart
OmniApp(
  swipeBack: OmniSwipeBack.zoomCard, // in-app কিনারা swipe (3-button navigation / iOS)
  predictiveBack: true,              // Android-এর system back gesture-ও একই style-এ
  ...
)
```

`android/app/src/main/AndroidManifest.xml`-এ `<application>`-এ এটা দিতে হবে, তারপর **পুরো rebuild**
(hot restart যথেষ্ট নয়) — না দিলে Android 14+ gesture-এর progress পাঠায় না, back শুধু সাধারণ pop করে:

```xml
<application
    android:enableOnBackInvokedCallback="true"
    ...>
```

- আঙুলের সাথে পেজ zoom-out হয়; ছেড়ে দিলে (commit) পেজ বন্ধ, ফিরিয়ে নিলে (cancel) আগের জায়গায় ফেরে।
- `swipeBack: none` হলেও `predictiveBack: true` দিলে system gesture-এ `zoom` style চলে; কোনো পেজে
  `swipeBack: OmniSwipeBack.none` দিলে সেই পেজে দুটোই বন্ধ (সাধারণ pop)।
- Android-এ `material`/`cupertino`/`adaptive` পেজও তখন `OmniPages.swipeZoom` হয়ে যায়, যাতে gesture অনুসরণ করে;
  iOS-এ সেগুলো আগের মতোই থাকে (নিজস্ব swipe-back সহ)।
- back **বাটন** চাপলে (gesture নয়) আগের মতোই সাধারণ pop।
- debug-এ "manifest flag নেই" সতর্কতা দেওয়া হয় না — Android flag না থাকলে অ্যাপ কোনো সংকেতই পায় না, তাই
  নির্ভরযোগ্যভাবে ধরা যায় না।

**কীভাবে কাজ করে**
- বাম বা ডান কিনারা থেকে শুরু করতে হয়; ভেতরের দিকে টানলে বন্ধ হয়, উল্টো দিকে কিছু হয় না।
- ছেড়ে দিলে: অর্ধেকের বেশি টানা হলে বা জোরে flick করলে পেজ বন্ধ, নইলে `easeOutBack` দিয়ে ফিরে আসে।
- কিনারার জায়গায় tap করলে নিচের বাটন ঠিকই tap পায়।
- প্রথম পেজে, `PopScope(canPop: false)`-এ, `fullscreenDialog`-এ, অন্য animation চলার সময় gesture চলে না।
- বন্ধ হয় `OmniRouter` দিয়ে, তাই `OmniRoute.stack`, log আর `onScreenHidden/onScreenVisible` ঠিক থাকে।
- system-এ "animation কমাও" চালু থাকলে gesture থাকে, কিন্তু যেকোনো style-এর বদলে সাধারণ slide।
- শুধু `Transform`, `Opacity`, `ClipRRect` আর ছায়া — blur বা `BackdropFilter` নেই, GPU-তে হালকা।
- না টানা অবস্থায় পেজের চারপাশে কোনো বাড়তি widget থাকে না (শুধু কিনারার listener)।
- নিচের পেজের effect (`slide`-এর parallax, `zoomParallax`) তখনই হয় যখন নিচের পেজটাও
  animated page type-এর (`OmniPages.fade` ইত্যাদি); `material`/`cupertino` পেজ নিচে থাকলে সেটা স্থির থাকে।
- example অ্যাপের Settings-এ সব ৮টা style বদলে চালিয়ে দেখা যায়।

> 💡 swipe-back-এর জন্য পিছনে একটা পেজ থাকা দরকার। সব জায়গায় `OmniRoute.open(...)` দিয়ে খুললে
> পিছনে পেজ থাকে, অথচ একই পেজ দুবার জমে না (অধ্যায় ৮ দেখুন)।

### Back বাটন

| Platform | Back | কে সামলায় |
|---|---|---|
| Android | system back, `PopScope` মানে | Flutter |
| iOS | বাম কিনারা থেকে swipe | Flutter |
| Windows / Linux | Alt+←, mouse back বাটন | OmniRoute (`desktopBack`) |
| macOS | Cmd+[, Cmd+←, mouse back | OmniRoute (`desktopBack`) |
| Web | browser back/forward | browser |

`PopScope(canPop: false)` দিয়ে back আটকানো সব platform-এ কাজ করে।

### State Restoration (Android অ্যাপ মেরে ফেললেও একই জায়গায় ফেরা)

```dart
OmniApp(
  restorationScopeId: 'router',
  builder: (context, router) => MaterialApp.router(
    restorationScopeId: 'app', // এটাও দিতে হবে
    routerConfig: router,
  ),
  ...
)
```

ফিরে আসে: পেজের stack, বেছে নেওয়া tab, `Restorable*` widget state।
ফেরে না: Bloc-এর state (Bloc নতুন করে তৈরি হয় — দরকারি data নিজে save করুন)।

---

## ১৮. Debugging ও Analytics

```dart
OmniRoute.current;           // উপরের পেজ: location, routePath, name, screen, metadata
OmniRoute.currentListenable; // ValueListenable<OmniRouteEntry> — রুট পরিবর্তনে সরাসরি আপডেট
OmniRoute.stack;             // নিচ থেকে উপর পর্যন্ত সব পেজ (shell, push সহ)
OmniRoute.state;             // নেটিভ OmniRouteState
OmniRoute.paths;             // রেজিস্ট্রার করা সব routePath-এর তালিকা
OmniApp.validateRoutes(routes); // স্টার্টআপ বা টেস্টে ডুপ্লিকেট/ভুল path আগেই যাচাই
```

```dart
OmniApp(
  // প্রতিটা navigation-এর পর একবার (initial, go, push, replace, pop, refresh, redirect)
  onNavigate: (nav) {
    // nav.kind, nav.from, nav.to, nav.uri, nav.timestamp
    analytics.logScreenView('${nav.to.routePath} (${nav.kind.name})', nav.uri.toString());
  },
  // debug build-এ console-এ সুন্দর করে সাজানো log (নিচে দেখুন)
  logNavigation: true,
  ...
)
```

### Log দেখতে কেমন (`logger` package, 0.3.1)

OmniRoute-এর নিজের সব log ([`logger`](https://pub.dev/packages/logger) package দিয়ে) একই ধাঁচে আসে —
প্রতিটা ঘটনা একটা বাক্সে, উপরে সময় আর অ্যাপ চালুর পর কতক্ষণ, বাঁয়ে level-এর emoji
(💡 তথ্য, ⚠️ সতর্কতা, ⛔ error), আর `from`/`to` এক লাইনে মিলিয়ে সাজানো:

```text
┌────────────────────────────────────────────────────────────────────────
│ 10:42:07.311 (+0:00:05.402070)
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ 💡 OmniRoute · navigation
│ 💡 from  /students             StudentListScreen
│ 💡 to    /students/7           StudentDetailScreen
│ 💡 uri   /students/7?tab=info
└────────────────────────────────────────────────────────────────────────
```

- `from` — আগের পেজ (প্রথমবার `(app start)`), `to` — নতুন পেজ, শেষে screen-এর class।
- `uri` লাইন শুধু query (`?tab=...`) থাকলে আসে।
- guard নিজের পেজেই redirect করলে ⚠️ `OmniRoute · guard` সতর্কতা আসে।
- শুধু debug build-এ; release build-এ কিছুই print হয় না।

নিজের মতো format বা অন্য জায়গায় (file, crash reporter) পাঠাতে `OmniRoute.logger` বদলে দিন:

```dart
import 'package:logger/logger.dart';

OmniRoute.logger = Logger(
  printer: SimplePrinter(),   // এক লাইনের ছোট log
  // output: MyFileOutput(),  // নিজের LogOutput
);
```

Observer লাগলে: `OmniApp(observers:)` (root), `OmniShell(observers:)`,
`OmniBranch(observers:)`। (`OmniRouteGroup` নেস্টেড `Navigator` ব্যবহার করে না, তাই সেখানে আলাদা observer লাগে না।)

---

## ১৯. Error ও সমাধান

সব error `OmniRouteException` — এতে `code`, `message` আর সমাধানের `hint` থাকে।

| Error / সমস্যা | কারণ | সমাধান |
|---|---|---|
| `invalidRoutePath ... lowercase` | path-এ বড় হাতের অক্ষর | ছোট হাতের লিখুন |
| `duplicateRoute` | একই URL বা একই `name` দুবার | একটার নাম/path বদলান |
| `emptyRoutePath` / `invalidRoutePath` | `routePath` খালি বা নিয়ম ভাঙা | বৈধ lowercase path দিন (যেমন `'/home'`) |
| `missingBlocFactory` | Bloc register করা হয়নি | screen `provide`/`OmniPage(blocs:)`-এ `OmniBloc((_) => X())` দিন বা `OmniApp(blocs:)`-এ যোগ করুন |
| `duplicateBlocRegistration` | একই Bloc দুবার | একটা সরান |
| `unsupportedConfiguration: X is global` | global Bloc screen-এ আবার `Provide` | `Provide` সরিয়ে `context.read<X>()` |
| `screenNotHosted` | route ছাড়া stateful screen | `OmniScreenHost(screen: ...)` |
| `notInitialized` | `OmniApp` তৈরির আগে navigation | পরে navigate করুন বা `context.go` |
| `missingRoute: No OmniPage builds X` | screen-এর route নেই, বা `List<OmniPage>` টাইপ | route যোগ করুন / `List<OmniRouteBase>` |
| `X is used by several routes` | একই screen কয়েকটা route-এ | path বা `goNamed` দিয়ে navigate |
| `invalidParameter` | URL-এ ভুল মান | not-found পেজ দেখায় (crash নয়) |
| `redirectLoop` | guard ৫ বারের বেশি loop-এ ঘুরছে | error পেজ দেখায় (অসীম loop এড়ায়) |
| `lifecycleOnWidget` | `OmniStatefulWidget`-এ `with OmniLifecycle` (hook চলে না) | mixin-টা `OmniState`-এ দিন |
| Web-এ refresh করলে 404 | server fallback নেই | ১৫তম অংশ |
| child route parent-এর Bloc পায় না | nested route আলাদা পেজ | `OmniRouteGroup` |
| Bloc/রুট/গার্ড বদল | হট-রিলোড ও আপডেট | `routes`, `guards`, `blocs`, `observers`, `onNavigate` হট-রিলোডে সিঙ্ক হয়; শুধু `global: true` instance বদলাতে বা `initialRoute` বদলাতে hot restart দিন |

---

## ২০. সম্পূর্ণ উদাহরণ

[`example/lib/main.dart`](example/lib/main.dart) ও [`example/bin/demo.dart`](example/bin/demo.dart)-এ একটি সম্পূর্ণ রিয়েল-এপিআই ও রাউটিং অ্যাপ আছে:

- `OmniApp.material` + `themeModeBuilder` + `appBuilder` (`OmniInspectorLauncher`) + `onNavigate` (`nav.kind`)
- Login + Auth guard (login-এর পর আগের পেজে ফেরে)
- Bottom tab (`OmniStatefulShell`) — Dashboard, Students, API & AI (`OmniShell`), Settings
- Dashboard: `OmniStatefulWidget` + `OmniLifecycle` + `.hosted()` `OmniStatelessWidget`
- Student list → detail → edit (`OmniRouteGroup`, `onExit` কনফার্মেশন ও `slideUp`)
- রিয়েল পাবলিক API তুলনা (`Normal` বনাম `Modified` Endpoint + Decoder + `Result`), `OmniApiHub` (JSONPlaceholder, DummyJSON, Open-Meteo, PokéAPI), লাইভ Postman WebSocket Echo RPC, ও Multi-Model AI
- `404 Warning` ও `500 Error` সহ আলাদা কালার্ড টার্মিনাল বক্স এবং ইন-অ্যাপ ১-ক্লিক কপি ও Talker-স্টাইল লগ ইনস্পেক্টর

```bash
cd example
flutter run -d macos    # বা chrome, iOS simulator, Android
dart run bin/demo.dart  # টার্মিনালে রিয়েল পাবলিক API ও আলাদা কালার্ড লগ ডেমো
flutter test            # পুরো UI + API ফ্লো টেস্ট
```

---

## ২১. OmniNetwork — API call (HTTP, Auth, Cache, Upload…)

OmniNetwork হলো এই repo-র **আলাদা** networking package — OmniRoute ছাড়াও একা ব্যবহার করা যায়
(Flutter বা কোনো state management লাগে না)। ভিতরে HTTP-র কাজ করে [Dio](https://pub.dev/packages/dio)।

> **সম্পূর্ণ ব্যবহার গাইড (বাংলা):** [packages/omni_network/doc/guide.bn.md](packages/omni_network/doc/guide.bn.md) — install থেকে production পর্যন্ত, OmniRoute-এর সাথে পুরো অ্যাপ, test, নিরাপত্তা আর FAQ।

| Package | কী কাজে | কখন লাগবে |
|---|---|---|
| `omni_network` | HTTP client — get/post, typed model, auth, retry, cache, upload/download, pagination | সবসময় |
| `omni_network_flutter` | token নিরাপদে সংরক্ষণ (Keychain/Keystore), অ্যাপের ভিতরে network inspector | Flutter অ্যাপে |
| `omni_network_ws` | WebSocket আর Server-Sent Events (live data) | real-time দরকার হলে |
| `omni_network_openapi` | OpenAPI/Swagger থেকে model আর endpoint তৈরির CLI | backend-এর OpenAPI spec থাকলে |

> অবস্থা: pub.dev-এ publish হয়নি — নিচের মতো `git` দিয়ে যোগ করুন।

একই GitHub repo-র `packages/` ফোল্ডার থেকে, প্রতিটা package-এর নিজের release tag দিয়ে:

```yaml
dependencies:
  omni_network:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network
      ref: omni_network-v0.1.1
  omni_network_flutter:          # Flutter অ্যাপে (ঐচ্ছিক)
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network_flutter
      ref: omni_network_flutter-v0.1.0
  omni_network_ws:               # WebSocket / SSE (ঐচ্ছিক)
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network_ws
      ref: omni_network_ws-v0.1.0
dev_dependencies:
  omni_network_openapi:          # code generator (ঐচ্ছিক)
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network_openapi
      ref: omni_network_openapi-v0.1.0
```

```dart
import 'package:omni_network/omni_network.dart';          // সাধারণ ব্যবহার
import 'package:omni_network/advanced.dart';              // offline queue, circuit breaker, cURL…
import 'package:omni_network/testing.dart';               // OmniMock (test-এ)
```

### ২১.১ এক নজরে — কোন কাজে কোনটা

| আপনি যা করতে চান | যেটা ব্যবহার করবেন |
|---|---|
| client তৈরি | `OmniNetwork(baseUrl: ..., enableLogging: true)` |
| proxy / SSL pin / HTTP/2 / mTLS / DoH | `OmniNetwork(proxy: ..., pinnedSha256: [...], enableHttp2: true, dnsOverHttps: ...)` |
| একটা object / GraphQL আনা | `api.get<User>(...)`, `api.graphql<User>(...)` |
| তালিকা আনা | `api.getList<User>('/users', decoder: User.fromJson)` |
| data / form / gzip পাঠানো | `api.post(..., compress: true)`, `api.postForm(...)`, `put / patch / delete` |
| status code / header-ও লাগবে | `api.getResponse<T>(...)` (আর `postResponse`…) |
| error সামলানো | `on OmniNetworkException catch (e)` বা `.asResult()` |
| login token / JWT / API Key / Basic / HMAC | `OmniAuth`, `Tokens.fromJwt(...)`, `ApiKeyAuth`, `BasicAuth`, `HmacSignerAuth` |
| অ্যাপ বন্ধ করে খুললেও login থাকবে | `OmniAuth(storage: SecureTokenStorage())` |
| ব্যর্থ GET আবার চেষ্টা | `OmniNetwork(retry: const RetryPolicy())` |
| response cache (RAM / Disk) | `OmniNetwork(cache: OmniCache(store: FileCacheStore(...)))` + `api.clearCache()` |
| backend-এর `{ "data": ... }` খোলস খোলা | `responseAdapter: const EnvelopeResponseAdapter()` |
| endpoint একবার লিখে বারবার ব্যবহার | `Endpoint.get(...)` (`{id}` / `:id`) + `api.call(...)` |
| পাতায় পাতায় তালিকা (infinite scroll) | `api.paginate<T>(...)` + `OmniPagedListView<T>` (`omni_network_flutter`) |
| UI-তে loading / data / error | `api.watch<T>(...)` + `OmniRequestBuilder<T>` (`omni_network_flutter`) |
| ফাইল upload / download + SHA-256 | `UploadFile.fromFile`, `downloadToFile(..., resume: true, expectedSha256: ...)` |
| request বাতিল | `OmniCancelToken`, `api.cancelAll()` |
| প্রতিটা request-এ header যোগ / interceptor | `api.setHeader(...)`, `OmniInterceptor.inline(...)` |
| offline অবস্থায় request জমিয়ে পরে পাঠানো | `OfflineQueue(..., store: FileQueueStore(...))` (advanced) |
| metrics ও slow request ট্র্যাক | `api.metrics`, `slowRequestThreshold:` + `onSlowRequest:`, `api.logStream` |
| backend ছাড়াই test / record & replay | `OmniMock`, `RecordingTransport` (testing) |
| অ্যাপের ভিতরে সব call দেখা ও HAR export | `OmniInspector` + **"Copy HAR"** / `toHarJson()` (`omni_network_flutter`) |
| live data | `OmniWebSocket`, `SseConnection` (omni_network_ws) |

### ২১.২ Client তৈরি — একবারই (এক লাইনে প্রো-কনফিগসহ)

```dart
// পুরো অ্যাপে একটা client রাখুন (প্রতি request-এ নতুন বানাবেন না)
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',  // সব path এর সাথে জুড়বে
  enableLogging: true,                     // terminal-এ পুরো response ছাপাবে (অ্যাপ চলার সময়ও on/off করা যায়)
  timeout: const Duration(seconds: 30),    // মোট সময়সীমা; চাইলে connectTimeout/sendTimeout/receiveTimeout আলাদা
  headers: {'Accept-Language': 'bn'},      // সব request-এ যাবে (পরে api.setHeader/removeHeader দিয়ে বদলানো যায়)
  decoders: {User: User.fromJson},         // একবার দিলে get<User>()-এ বারবার decoder: লিখতে হয় না
  // প্রয়োজনে এক লাইনেই প্রো ফিচার:
  // proxy: '192.168.0.105:8888',
  // pinnedSha256: ['sha256/...'],
  // enableHttp2: true,
  // dnsOverHttps: DnsOverHttpsResolver.cloudflareEndpoint,
  // maxConcurrentRequests: 8,
  // slowRequestThreshold: const Duration(seconds: 2),
  // onSlowRequest: (uri, elapsed) => print('Slow: $uri ($elapsed)'),
);

// অথবা আগের Dio instance থাকলে এক লাইনেই র‍্যাপ করুন:
// final api = OmniNetwork.fromDio(existingDio, enableLogging: true);

// অ্যাপ বন্ধের সময়
await api.close();
```

### ২১.৩ Data আনা — typed model

`decoder` = JSON map থেকে আপনার class বানানোর function (সাধারণত `fromJson`)।
JSON হাতে parse করতে হয় না; বড় JSON mobile/desktop-এ আলাদা isolate-এ decode হয়, তাই UI আটকায় না।

```dart
class User {
  User({required this.id, required this.name});
  factory User.fromJson(Map<String, dynamic> json) =>
      User(id: json['id'] as int, name: json['name'] as String);
  final int id;
  final String name;
}

// একটা object
final user = await api.get<User>('/users/10', decoder: User.fromJson);

// তালিকা
final users = await api.getList<User>('/users', decoder: User.fromJson);

// query parameter → /users?page=2&q=ana
final page2 = await api.getList<User>('/users',
    decoder: User.fromJson, query: {'page': 2, 'q': 'ana'});

// decoder না দিলে কাঁচা JSON
final raw = await api.get<Map<String, dynamic>>('/stats');

// status code, header সহ পুরো response
final res = await api.getResponse<User>('/users/10', decoder: User.fromJson);
print('${res.statusCode} ${res.data.name}');
```

### ২১.৪ Data পাঠানো (JSON, Gzip, Form ও GraphQL)

```dart
// body-তে Map/List দিলে নিজে থেকেই JSON হয়ে যায়
final created = await api.post<User>('/users',
    body: {'name': 'Ana'}, decoder: User.fromJson);

// বড় payload gzip কম্প্রেস করে পাঠানো (IO) ও URL-encoded form POST:
await api.post<void>('/events', body: events, compress: true);
await api.postForm<void>('/token', fields: {'grant_type': 'refresh_token'});

// GraphQL query / mutation সরাসরি:
final me = await api.graphql<User>(
  '/graphql',
  query: r'query Me { viewer { id name } }',
  dataKey: 'viewer',
  decoder: User.fromJson,
);

await api.put<void>('/users/10', body: {'name': 'Ana B.'});    // পুরো বদল
await api.patch<void>('/users/10', body: {'name': 'Ana C.'});  // আংশিক বদল
await api.delete<void>('/users/10');                           // মুছে ফেলা
```

### ২১.৫ প্রতিটা call-এর ঐচ্ছিক setting

```dart
await api.get<User>('/me',
  decoder: User.fromJson,
  query: {'expand': 'roles'},             // ?expand=roles
  headers: {'X-Trace': traceId},          // শুধু এই call-এ বাড়তি header
  timeout: const Duration(seconds: 5),    // শুধু এই call-এর সময়সীমা
  auth: false,                            // এই call-এ token পাঠাবে না (যেমন login)
  retry: RetryPolicy.none,                // এই call-এ retry বন্ধ
  cache: CachePolicy.networkFirst,        // এই call-এর cache নিয়ম
  cancelToken: token,                     // পরে token.cancel() দিয়ে বাতিল
);
```

### ২১.৬ Error সামলানো

সব ব্যর্থতা `OmniNetworkException` — সহজ check সহ। `message`-এ কখনো token থাকে না, তাই ব্যবহারকারীকে দেখানো নিরাপদ।

```dart
try {
  final user = await api.get<User>('/users/10', decoder: User.fromJson);
} on OmniNetworkException catch (e) {
  if (e.isOffline) {
    showMessage('ইন্টারনেট সংযোগ নেই');      // network নেই বা timeout
  } else if (e.isUnauthorized) {
    goToLogin();                               // 401
  } else if (e.statusCode == 404) {
    showMessage('পাওয়া যায়নি');
  } else if (e.isCancelled) {
    // ব্যবহারকারী বাতিল করেছে — কিছু দেখানোর দরকার নেই
  } else {
    showMessage(e.message);
  }
}
```

`try/catch` ছাড়া — `Result` দিয়ে:

```dart
final result = await api.get<User>('/users/10', decoder: User.fromJson).asResult();
switch (result) {
  case Ok(:final value): showUser(value);          // সফল
  case Err(:final error): showMessage(error.message); // ব্যর্থ
}
```

### ২১.৭ Login আর Token — স্বয়ংক্রিয়

প্রতিটা client-এর একটা token manager আছে: `api.auth`। login-এর পর একবার token দিন —
এরপর প্রতিটা request-এ নিজে থেকেই `Authorization: Bearer ...` যায়।

```dart
final api = OmniNetwork(
  baseUrl: 'https://api.example.com/v1',
  auth: OmniAuth(
    // token শেষ হওয়ার আগে (বা 401 এলে) নতুন token কীভাবে আনবে
    refresh: (tokens, api) async {
      final r = await api.post<Map<String, dynamic>>('/auth/refresh',
          body: {'refresh_token': tokens.refresh}, auth: false);
      return Tokens(
        access: r['access_token'] as String,
        refresh: r['refresh_token'] as String?,
        expiresIn: Duration(seconds: r['expires_in'] as int),
      );
    },
    // refresh ব্যর্থ হলে বা logout() ডাকলে — একবারই
    onLogout: () => OmniRoute.go('/login'),
  ),
);

// login
final res = await api.post<Map<String, dynamic>>('/auth/login',
    body: {'email': email, 'password': password},
    auth: false);                                  // login call-এ token লাগে না
await api.auth.login(Tokens(
  access: res['access_token'] as String,
  refresh: res['refresh_token'] as String?,
  expiresIn: Duration(seconds: res['expires_in'] as int),
));

api.auth.isLoggedIn;        // true
api.auth.changes;           // signedIn / signedOut stream — guard-এর refresh-এ দিন
await api.auth.logout();    // token মুছে ফেলা
```

OmniAuth নিজে যা সামলায়:
- **মেয়াদ শেষের আগেই refresh**, আর server 401 দিলে আবার refresh
- **একসাথে একটাই refresh** — অনেক call একসাথে আটকালে refresh একবার চলে, তারপর সব call আবার যায়
- **refresh ব্যর্থ হলে** একবারই sign out — token মুছে `onLogout`
- **অসীম loop নেই** — প্রতিটা 401 মানেই logout নয়

**OmniRoute guard-এর সাথে জোড়া:**

```dart
final authGuard = OmniGuard.fn(
  (context, state) =>
      !api.auth.isLoggedIn && state.matchedLocation != '/login' ? '/login' : null,
  refresh: (_) => api.auth.changes, // login/logout হলে guard আবার চলবে
);
```

**অ্যাপ বন্ধ করে খুললেও login থাকবে** (Flutter, `omni_network_flutter`):

```dart
auth: OmniAuth(
  storage: SecureTokenStorage(), // iOS/macOS Keychain, Android Keystore, Windows/Linux secret store
  refresh: ...,
),
```

অন্য কোথাও থেকে token আসলে: `OmniNetwork(baseUrl: url, token: () => myToken)`।

এছাড়া JWT থেকে সরাসরি মেয়াদ পড়তে `Tokens.fromJwt(jwtAccess, refresh: refreshToken)`, এবং অন্যান্য auth-এর জন্য `ApiKeyAuth` (header বা `inQuery: true`), `BasicAuth`, ও `HmacSignerAuth` রয়েছে।

### ২১.৮ Terminal log — আলাদা কালার্ড বক্স, স্ট্যাটাস ম্যাচিং ও লাইভ কন্ট্রোল

```dart
final api = OmniNetwork(
  baseUrl: url,
  enableLogging: true,
  logOptions: const LogOptions(
    summary: true,   // স্ট্যাটাস ব্যাজ, স্পিড (⚡ FAST) ও JSON আকৃতি দেখাবে
    separate: true,  // Request, Status Header ও JSON Body আলাদা কালার্ড বক্সে প্রিন্ট করবে
  ),
);

// অ্যাপ চলার সময়েও যেকোনো সময় অন/অফ বা রং বদলানো যায়:
api.enableLogging = false;   // পুরো log বন্ধ/চালু
api.logResponse = true;      // false করলে শুধু response body প্রিন্ট বন্ধ থাকে
api.logColors = null;        // true/false বা null (auto-detect)
```

`separate: true` ব্যবহার করলে প্রতিটি কল আলাদা কালার-কোডেড বক্সে ছাপা হয় (JSON বডির প্রতি লাইনে অতিরিক্ত ইমোজি ছাড়াই):

```text
┌────────────────────────────────────────────────────────────
│ 2026-11-27 12:18:55.967
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ 📡 http-request · GET  https://jsonplaceholder.typicode.com/users/2
└────────────────────────────────────────────────────────────
┌────────────────────────────────────────────────────────────
│ 2026-11-27 12:18:56.002 (+35 ms)
├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
│ 💡 http-response · 200 OK · SUCCESS
│ GET  https://jsonplaceholder.typicode.com/users/2
│ ⚡ FAST (35 ms) · 509 B · NETWORK
│ 📦 Body: JSON Object (8 keys: id, name, username, email, …)
└────────────────────────────────────────────────────────────
┌────────────────────────────────────────────────────────────
│ {
│   "id": 2,
│   "name": "Ervin Howell",
│   "access_token": "***"
│ }
└────────────────────────────────────────────────────────────
```

- **আলাদা ও স্ট্যাটাস-ম্যাচড রঙ**:
  - `📡 http-request`: ম্যাজেন্টা বর্ডার (`38;5;171`)
  - **Success (`2xx`)**: সবুজ বর্ডার ও হেডার (`38;5;40`) + সবুজ বর্ডার্ড সিনট্যাক্স-কালার্ড JSON (`key` সায়ান, `string` হলুদ, `number` বেগুনি, `bool/null` গোলাপি)
  - **Redirect (`3xx`)**: নীল (`38;5;39`)
  - **Warning (`4xx`, যেমন 404)**: কমলা/অ্যাম্বার (`38;5;214`) বর্ডার ও `⚠️ http-warning` হেডার + কমলা বডি বক্স
  - **Error (`5xx` বা অফলাইন)**: লাল (`38;5;196`) বর্ডার + লাল ব্যাকগ্রাউন্ডে সাদা বোল্ড ব্যানার (`⛔ http-error`) + লাল এরর বডি বক্স
- **প্ল্যাটফর্ম অটো-ডিটেকশন**: `colors: null` দিলে Android, macOS Desktop, Linux Desktop, Chrome DevTools ও CLI-তে স্বয়ংক্রিয়ভাবে ANSI কালার চালু থাকে; iOS-এ `os_log` `ESC`-কে `\^[` করে ফেলায় ডিফল্ট প্লেইন থাকে (চাইলে `logColors = true` বা `FORCE_COLOR=1` দিয়ে ফোর্স করা যায়)।
- **পুরো response** ছাপা হয় — ৫০০–১০০০+ লাইন হলেও কোনো কিছু কাটা হয় না; ১৬০ অক্ষরের লম্বা লাইন `↪` দিয়ে পরের লাইনে চলে যায়।
- password, token, cookie, API key সবসময় `***` — কখনো log-এ আসে না।
- release build-এ নিজে থেকেই বন্ধ (`logInRelease: true` দিয়ে চালানো যায়); `api.logStream` ও `MultiLogSink([PrettyLogSink(), inspector.sink('api')])` দিয়ে একই সাথে টার্মিনাল ও ইনস্পেক্টরে পাঠানো যায়।

### ২১.৯ Retry আর Cache

```dart
final api = OmniNetwork(
  baseUrl: url,
  // ব্যর্থ হলে আবার চেষ্টা — default-এ শুধু GET/HEAD (POST কখনো ভুল করে দুবার যায় না)
  retry: const RetryPolicy(
    maxAttempts: 3,                                  // প্রথম চেষ্টা সহ মোট
    baseDelay: Duration(milliseconds: 300),          // প্রতিবার বাড়ে (backoff + jitter)
  ),
  // response cache — default-এ HTTP-র নিয়ম মানে (ETag, 304)
  cache: OmniCache(),
);

// নির্দিষ্ট call-এ cache নিয়ম
await api.get<User>('/me', decoder: User.fromJson, cache: CachePolicy.cacheFirst);
```

| `CachePolicy.` | কাজ |
|---|---|
| `standard` | HTTP-র নিয়ম (fresh হলে cache, পুরনো হলে ETag দিয়ে যাচাই) |
| `cacheFirst` | cache থাকলে সেটাই, না থাকলে network |
| `staleWhileRevalidate` | cache সাথে সাথে, পিছনে নতুন করে আনা |
| `networkFirst` | আগে network, ব্যর্থ হলে cache (offline-এ কাজে লাগে) |
| `refresh` | network থেকে এনে cache হালনাগাদ |
| `noCache` | cache ব্যবহার নয় |

> login করা অবস্থার response default-এ cache হয় না (অন্য user-এর data দেখানোর ঝুঁকি এড়াতে)।

### ২১.১০ Backend-এর response format একবার বলে দিন

অনেক backend পাঠায় `{ "success": true, "data": {...} }`। প্রতিটা call-এ `data` বের না করে:

```dart
final api = OmniNetwork(
  baseUrl: url,
  responseAdapter: const EnvelopeResponseAdapter(
    dataKey: 'data',      // আসল data কোথায়
    errorKey: 'message',  // error বার্তা কোথায়
  ),
);
final user = await api.get<User>('/me', decoder: User.fromJson); // সরাসরি User
```

### ২১.১১ Endpoint — একবার লিখুন, সব জায়গায় ব্যবহার

```dart
abstract final class Api {
  static final user = Endpoint.get<User>('/users/:id', decoder: User.fromJson); // {id} বা :id দুটিই চলে
  static final users = Endpoint.getList<User>('/users', decoder: User.fromJson);
  static final createUser = Endpoint.post<User>('/users', decoder: User.fromJson);
}

final u = await api.call(Api.user, path: {'id': 10});        // {id}/:id বসে যায় (encode সহ)
final list = await api.call(Api.users, query: {'page': 1});
final created = await api.call(Api.createUser, body: {'name': 'Ana'});
```

### ২১.১২ Pagination ও Flutter `OmniPagedListView<T>`

```dart
final pager = api.paginate<User>('/users',
  decoder: User.fromJson,
  itemsKey: 'items',                        // তালিকা JSON-এর কোন key-তে
  strategy: const PagePagination(pageSize: 20), // ?page=1&limit=20
);

pager.changes.listen((_) {}); // যেকোনো পরিবর্তনের broadcast stream
await pager.next();           // পরের পাতা (একসাথে দুবার ডাকলেও একবারই load)
pager.items;                  // এ পর্যন্ত সব item
pager.hasMore;                // আরও আছে কি না
await pager.refresh();        // pull-to-refresh: শুরু থেকে
await pager.close();
```

Flutter-এ `omni_network_flutter` থেকে সরাসরি অটো ইনফিনিট-স্ক্রল ও পুল-টু-রিফ্রেশ লিস্ট:

```dart
OmniPagedListView<User>(
  pager: pager,
  itemBuilder: (context, user, index) => ListTile(title: Text(user.name)),
);
```

| Strategy | Backend যেমন |
|---|---|
| `PagePagination()` | `?page=2&limit=20` |
| `OffsetPagination()` | `?offset=40&limit=20` |
| `CursorPagination(nextCursorKey: 'next_cursor')` | `?cursor=abc` |
| `LinkHeaderPagination()` | response-এর `Link` header (GitHub-এর মতো) |

### ২১.১৩ UI-তে Loading / Data / Error ও `OmniRequestBuilder<T>`

```dart
final me = api.watch<User>('/me', decoder: User.fromJson); // নিজে থেকেই load শুরু

// omni_network_flutter-এ এক লাইনের reactive widget:
OmniRequestBuilder<User>(
  controller: me,
  emptyBuilder: (_) => const Text('কোনো তথ্য নেই'),
  builder: (context, user, isRefreshing) => Text(user.name),
);

await me.refresh();  // আবার আনা
await me.close();    // screen বন্ধ হলে
```

Plain Dart `me.stream`-ও চাইলে `StreamBuilder`, Bloc বা Riverpod-এ ব্যবহার করা যায়।
state গুলো: `RequestIdle`, `RequestLoading` (আগের data সহ), `RequestSuccess`, `RequestEmpty`, `RequestError`।
তালিকার জন্য `api.watchList<T>(...)`।

### ২১.১৪ Upload আর Download — `fromFile`, `If-Range` ও SHA-256

```dart
// upload (multipart) — ফাইল পাথ থেকে সরাসরি স্ট্রিম (RAM বাঁচায়, IO):
final avatarFile = await UploadFile.fromFile('file', '/path/to/me.png');
await api.upload<void>('/avatar',
  files: [avatarFile], // বা UploadFile.fromBytes(...)
  fields: {'caption': 'আমার ছবি'},
  onProgress: (sent, total) => print('$sent / $total'),
);

// download — memory-তে (ঐচ্ছিক SHA-256 যাচাইসহ)
final pdf = await api.downloadBytes(
  '/report.pdf',
  expectedSha256: 'b26d48a5...',
  onProgress: (got, total) => print('$got / $total'),
);

// download — সরাসরি ফাইলে (Web ছাড়া); ETag/Last-Modified `.part.meta` + If-Range রিজিউম ও SHA-256 চেক
await api.downloadToFile(
  '/big.zip',
  '/path/to/big.zip',
  resume: true,
  expectedSha256: 'b26d48a5...',
);
```

### ২১.১৫ Request বাতিল

```dart
final token = OmniCancelToken();
api.get<User>('/slow', decoder: User.fromJson, cancelToken: token);
token.cancel();     // শুধু এটা বাতিল (retry-ও হবে না)
api.cancelAll();    // চলমান সব request বাতিল (যেমন logout-এ)
```

### ২১.১৬ Interceptor — ক্লাস বা ইনলাইন ফাংশন

```dart
final api = OmniNetwork(
  baseUrl: url,
  interceptors: [
    OmniInterceptor.inline(
      onRequest: (r) => r.withHeader('X-App-Version', '1.4.0'),
      onError: (r, e) => crashReporter.log('${r.method} ${r.path}: ${e.message}'),
    ),
  ],
);
```

বড় কাজের জন্য চাইলে `OmniInterceptor` সাবক্লাসও করতে পারেন।

### ২১.১৭ Offline Queue, Disk Cache, Metrics ও Circuit Breaker (`advanced.dart`)

```dart
import 'package:omni_network/advanced.dart';

// ডিস্কে টিকে থাকা cache ও offline queue:
final cache = OmniCache(store: FileCacheStore(directory: '/path/to/cache'));
final queue = OfflineQueue(
  client: api,
  store: FileQueueStore(directory: '/path/to/queue'), // অ্যাপ রিস্টার্ট হলেও FIFO কিউ হারায় না
);
final r = await queue.sendOrQueue(
  const OmniRequest.post('/attendance', body: {'student': 7, 'present': true}),
);
if (r is Queued) showMessage('Offline — পরে পাঠানো হবে');
await queue.flush(); // সংযোগ ফিরলে (জমা request আবার পাঠাও)

// runtime telemetry ও slow-request ট্র্যাকিং:
print(api.metrics); // totalRequests, successCount, failureCount, cacheHitRate, averageLatency

// একটা server বারবার ব্যর্থ হলে কিছুক্ষণ request পাঠানো বন্ধ রাখা
final api2 = OmniNetwork(baseUrl: url, circuitBreaker: CircuitBreaker(failureThreshold: 5));
```

- DELETE-এর মতো ধ্বংসাত্মক request নিজে থেকে queue হয় না (`allowDestructive: true` দিতে হয়)
- queue-তে token বা password কখনো সংরক্ষিত হয় না; idempotency key দিয়ে দ্বিতীয়বার পাঠানো এড়ানো হয়

**cURL:** `api.toCurl(request)` (secret লুকানো) আর `parseCurl('curl ...')` — bug report শেয়ারে কাজে লাগে।

### ২১.১৮ Backend ছাড়াই Test — OmniMock ও RecordingTransport

```dart
import 'package:omni_network/testing.dart';

final mock = OmniMock()
  ..get('/users/{id}', (req) => MockResponse.json({'id': int.parse(req.pathParams['id']!), 'name': 'Ana'}))
  ..post('/users', (req) => MockResponse.json({'id': 1, 'name': 'Ana'}, status: 201))
  ..get('/slow', (_) => MockResponse.json({}, delay: const Duration(seconds: 2)));

final api = OmniNetwork(baseUrl: 'https://test', transport: mock); // আসল internet লাগে না

mock.failNext();                                   // পরের call-এ network error
final calls = mock.callsTo(HttpMethod.get, '/users/{id}'); // কোন call গেছে যাচাই

// আসল API ট্রাফিক redact করে রেকর্ড ও পরে অফলাইনে রিপ্লে:
final recorder = RecordingTransport(DioTransport());
final fixtures = recorder.toJson();
final replayTransport = RecordingTransport.replayJson(fixtures);
```

### ২১.১৯ অ্যাপের ভিতরে Talker-স্টাইল Network & App Inspector ও ১-ক্লিক কপি (`omni_network_flutter`)

```dart
final inspector = OmniInspector();          // release build-এ নিজে থেকেই বন্ধ
final api = OmniNetwork(
  baseUrl: url,
  enableLogging: inspector.enabled,
  logSink: MultiLogSink([PrettyLogSink(), inspector.sink('api')]), // terminal + inspector
);
inspector.attachClient(api); // HTTP, WebSocket ও AI কল একসাথে সংগ্রহ করে

// চাইলে Route ও Bloc লগও একই টাইমলাইনে পাঠানো যায়:
inspector.logRoute('/dashboard -> /api', subtitle: 'uri: /api');
inspector.logBloc('bloc-transition', 'ThemeBloc -> dark', kind: InspectorLogKind.blocTransition);

OmniApp.material(
  routes: routes,
  appBuilder: (context, child) => OmniInspectorLauncher(
    inspector: inspector,
    initialTab: InspectorTab.logs, // HTTP, Route, Bloc, WS, AI সব আলাদা কালার্ড কার্ডে
    child: child!,
  ),
);

// চাইলে কোড থেকেও HAR 1.2 JSON বা Markdown বাগ রিপোর্ট নেওয়া যায়:
final har = inspector.toHarJson();
final md = inspector.toMarkdownReport();
```

- **Talker-স্টাইল `All Logs` টাইমলাইন**: `http-request`, `http-response`, `http-warning`, `http-error`, `route`, `bloc-create`, `bloc-event`, `bloc-transition`, `ws-in`/`ws-out`, ও `ai-response` আলাদা কালার্ড কার্ড, ট্যাগ কাউন্ট চিপ এবং লাইভ `Search...` সহ।
- **প্রতি কার্ডে ১-ক্লিক কপি**: প্রতিটি লগ/API কার্ড থেকেই ১ ট্যাপে পুরো API JSON রেসপন্স কপি করা যায়; ডিটেইল ভিউতে সিনট্যাক্স-হাইলাইটেড JSON, **`Copy Full Response`**, **`Copy Full Log`**, **`Copy as cURL`**, **`Copy HAR`** ও AppBar-এ **`Copy all logs`** রয়েছে।
- inspector শুধু লুকানো (redacted) data পায় — token কখনো UI, HAR বা clipboard-এ যায় না।

### ২১.২০ Live data — WebSocket আর SSE (`omni_network_ws`)

```dart
import 'package:omni_network_ws/omni_network_ws.dart';

// Server-Sent Events — normal request-এর মতোই auth, log, refresh চলে
final sse = SseConnection(api, '/events');
sse.events.listen((e) => print('${e.event}: ${e.data}'));
await sse.close();

// WebSocket — বিচ্ছিন্ন হলে নিজে থেকেই আবার যুক্ত হয় (backoff সহ)
final ws = OmniWebSocket(
  Uri.parse('wss://api.example.com/live'),
  headers: () async => {'authorization': 'Bearer $token'}, // প্রতিবার connect-এ নতুন token
  onOpen: (socket) => socket.sendJson({'subscribe': 'prices'}),
);
ws.jsonMessages.listen(print);
await ws.close();
```

> Browser-এ WebSocket handshake header পাঠানো যায় না (browser-এর নিয়ম) —
> `OmniWebSocket.supportsHandshakeHeaders` অথবা `api.ws(..., wsWebAuthMode: WsWebAuthMode.queryParam())` ব্যবহার করুন।
> সরাসরি `package:omni_network/omni_network.dart` থেকেই এখন `api.ws(...)` আর `api.sse(...)` ব্যবহার করা যায় (`omni_network_ws` backward compatibility-র জন্য re-export করে)।

### ২১.২০ক OmniApiHub, Multi-AI ও Unified Chat

```dart
// ১. সব microservice + environment + AI এক Hub-এ কনফিগার
final hub = OmniApiHub(
  activeEnvironment: 'prod',
  environments: {
    'prod': const OmniEnvironment(
      name: 'prod',
      variables: {'core': 'https://api.example.com', 'ws': 'wss://ws.example.com'},
    ),
  },
  services: {
    'core': const ServiceConfig.fromVar(
      baseUrlVar: 'core',
      wsUrlVar: 'ws',
      rateLimit: RateLimit(maxRequests: 20, per: Duration(seconds: 1)),
    ),
  },
  ai: AiConfig(
    defaultModel: 'smart',
    providers: {
      'openai': OpenAiProvider(apiKey: () => openAiKey),
      'gemini': GeminiProvider(apiKey: () => geminiKey),
      'claude': AnthropicProvider(apiKey: () => claudeKey),
      'ollama': OllamaProvider(),
    },
    routes: const {
      'smart': AiModelRoute([
        AiTarget('claude', model: 'claude-3-7-sonnet-latest'),
        AiTarget('openai', model: 'gpt-4o'),
      ]),
    },
    maxSessionBudgetUsd: 1.00,
  ),
);

// ২. Multi-AI (ask, stream+tools, streamObject, PII guardrail, semantic cache, RAG ও voice/image)
final reply = await hub.ai.ask('Flutter-এ cache কী কাজে লাগে?');
final structured = await hub.ai.generateObject('Summary দাও', decoder: Summary.fromJson);
final health = await hub.healthCheckAll();

// ৩. Human + @ai হাইব্রিড চ্যাট (search, E2EE ChatCipher সহ) ও Flutter UI উইজেট
final room = hub.chat().room('support_1')..attachAiAssistant(hub.primary.aiThread('bot'));
// Flutter UI: OmniChatView(room: room), OmniAiChatView(thread: ...), OmniModelPicker(...)
```

### ২১.২১ OpenAPI থেকে code তৈরি (`omni_network_openapi`)

```bash
dart run omni_network_openapi -i openapi.yaml -o lib/api.g.dart
```

```dart
import 'api.g.dart';
final pets = await api.call(PetStoreApi.listPets, query: {'limit': 10});
```

model (`fromJson`/`toJson`), enum আর typed `Endpoint` তৈরি হয়; যা পারে না (Swagger 2, বাইরের `$ref`)
তা চুপচাপ বাদ না দিয়ে warning দেয়।

### ২১.২২ নিরাপত্তা আর Platform

- token/password কখনো log, error message বা offline queue-তে নয়
- অন্য server-এ redirect হলে credential বাদ; HTTPS → HTTP redirect প্রত্যাখ্যান
- retry আর cache default-এ বন্ধ; চালু করলেও নিরাপদ নিয়মে
- certificate যাচাই কখনো বন্ধ করা হয় না

| | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| Core HTTP, auth, GraphQL, cache, metrics | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅² |
| `downloadToFile` / `FileCacheStore` / `FileQueueStore` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ (`downloadBytes` ব্যবহার করুন) |
| `proxy` / `pinnedSha256` / mTLS / DoH / `compress` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌³ |

1. macOS-এ `com.apple.security.network.client` entitlement লাগে।
2. Web-এ server-কে CORS অনুমতি দিতে হবে — এটা browser-এর নিয়ম, Dart code দিয়ে এড়ানো যায় না।
3. Web-এ browser নিজে থেকেই proxy, TLS, DNS ও `Content-Encoding` পরিচালনা করে।

আরও বিস্তারিত (ইংরেজিতে): [packages/omni_network/README.md](packages/omni_network/README.md),
[packages/omni_network/doc/advanced.md](packages/omni_network/doc/advanced.md)।

---

## Migration — 0.3 থেকে 0.4

`0.4.0` থেকে `go_router` ডিপেন্ডেন্সি সম্পূর্ণ সরিয়ে নেটিভ `OmniRouter` (Segment Trie ইঞ্জিন) চালু করা হয়েছে:

- **`pubspec.yaml`**: `go_router` ডিপেন্ডেন্সি ও সব `import 'package:go_router/go_router.dart';` সরান।
- **`pageType` → `transition`**: `OmniApp(transition:)` ও `OmniPage(..., transition:)`, সাথে প্রতি নেভিগেশন কলেও `animated: false` বা `transition:` ওভাররাইড।
- **`StatefulShellBranch` / `StatefulNavigationShell`** → `OmniBranch` / `OmniNavigationShell`।
- **`GoRouterState` / `GoRouter` / `RouteBase`** → `OmniRouteState` / `OmniRouter` / `OmniRouteBase`।
- **সাধারণ `Widget` ও `GoRoute(...)`**: এখন সরাসরি `OmniPage('/path', (_) => MyWidget())`-এই ব্যবহার করা যায় (সাথে ইনলাইন `provide:`, `title:`, `onExit:`)।
- **`0.2` → `0.3` থেকে আপগ্রেড**: `AnyBloc` → `OmniAnyBloc`, `OmniState`-এ `OmniLifecycle`, `OmniSwipeBackStyle`-এ `flickVelocity`/`settleCurve`।

---

## License

MIT — [LICENSE](LICENSE) দেখুন।
