# OmniRoute — সম্পূর্ণ বাংলা ইউজার গাইড (প্রতিটি প্যারামিটার ও ব্যবহারসহ)

এই গাইডে `omni_route` (`0.4.0`)-এর প্রতিটি ক্লাস, মেথড ও **প্রতিটি প্যারামিটার** আলাদাভাবে ব্যাখ্যা করা হয়েছে:
কোন প্যারামিটার ভেতরে **কীভাবে কাজ করে**, বাস্তব প্রজেক্টে **কী কাজে লাগে**, এবং **কীভাবে ব্যবহার করবেন** (ব্যবহারের বর্ণনা ও উদাহরণসহ)।

> - দ্রুত শুরুর জন্য: [মূল README](../README.md)
> - আর্কিটেকচার ও গভীর টেকনিক্যাল নোট (ইংরেজি): [architecture.md](architecture.md), [web.md](web.md), [platforms.md](platforms.md), [migration.md](migration.md)
> - নেটওয়ার্ক ও API কলের পূর্ণাঙ্গ বাংলা গাইড: [omni_network বাংলা গাইড](../packages/omni_network/doc/guide.bn.md)

---

## সূচিপত্র

1. [ইনস্টলেশন ও বেসিক সেটআপ](#১-ইনস্টলেশন-ও-বেসিক-সেটআপ)
2. [OmniApp — অ্যাপের রুট কনফিগারেশন](#২-omniapp--অ্যাপের-রুট-কনফিগারেশন)
   - [২.১ কোর রাউটিং ও ডিপেনডেন্সি ইনজেকশন প্যারামিটার](#২১-কোর-রাউটিং-ও-ডিপেনডেন্সি-ইনজেকশন-প্যারামিটার)
   - [২.২ প্ল্যাটফর্ম UX ও নেভিগেশন কন্ট্রোল প্যারামিটার](#২২-প্ল্যাটফর্ম-ux-ও-নেভিগেশন-কন্ট্রোল-প্যারামিটার)
   - [২.৩ স্টার্টআপ, লাইফসাইকেল, এনালিটিক্স ও এরর প্যারামিটার](#২৩-স্টার্টআপ-লাইফসাইকেল-এনালিটিক্স-ও-এরর-প্যারামিটার)
   - [২.৪ OmniApp.material ও OmniApp.cupertino অতিরিক্ত প্যারামিটার](#২৪-omniappmaterial-ও-omniappcupertino-অতিরিক্ত-প্যারামিটার)
   - [২.৫ OmniApp.validateRoutes স্ট্যাটিক মেথড](#২৫-omniappvalidateroutes-স্ট্যাটিক-মেথড)
3. [OmniPage — রুট ও পেজ ডিক্লেয়ারেশন](#৩-omnipage--রুট-ও-পেজ-ডিক্লেয়ারেশন)
4. [Navigation API — OmniRoute, BuildContext এক্সটেনশন ও OmniScreen শর্টকাট](#৪-navigation-api--omniroute-buildcontext-এক্সটেনশন-ও-omniscreen-শর্টকাট)
5. [OmniParams ও OmniRouteState — রুট ডেটা ও প্যারামিটার পড়া](#৫-omniparams-ও-omniroutestate--রুট-ডেটা-ও-প্যারামিটার-পড়া)
6. [OmniRepo, OmniBloc ও Provide — DI ও Bloc স্কোপিং](#৬-omnirepo-omnibloc-ও-provide--di-ও-bloc-স্কোপিং)
7. [Shell ও Tab — OmniShell, OmniStatefulShell, OmniBranch, OmniNavigationShell](#৭-shell-ও-tab--omnishell-omnistatefulshell-omnibranch-omninavigationshell)
8. [OmniRouteGroup — নেস্টেড Navigator ছাড়া শেয়ার্ড Bloc](#৮-omniroutegroup--নেস্টেড-navigator-ছাড়া-শেয়ার্ড-bloc)
9. [OmniGuard — লগইন, রোল ও রিডাইরেক্ট গার্ড](#৯-omniguard--লগইন-রোল-ও-রিডাইরেক্ট-গার্ড)
10. [Screen ও Lifecycle — OmniScreen, OmniStatelessWidget, OmniStatefulWidget, OmniState, OmniScreenHost, OmniLifecycle](#১০-screen-ও-lifecycle--omniscreen-omnistatelesswidget-omnistatefulwidget-omnistate-omniscreenhost-omnilifecycle)
11. [Animation ও Swipe Back — OmniPages, OmniTransition, OmniSwipeBack, OmniSwipeBackStyle](#১১-animation-ও-swipe-back--omnipages-omnitransition-omniswipeback-omniswipebackstyle)
12. [Debugging, Terminal Color Log ও In-App Inspector](#১২-debugging-terminal-color-log-ও-in-app-inspector)

---

## ১. ইনস্টলেশন ও বেসিক সেটআপ

`pubspec.yaml`-এ `omni_route` (এবং চাইলে API ও ইনস্পেক্টরের জন্য `omni_network` + `omni_network_flutter`) যোগ করুন:

```yaml
dependencies:
  omni_route:
    git:
      url: https://github.com/juwelzan/omni_route.git
      ref: v0.4.0

  omni_network:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network
      ref: omni_network-v0.1.1

  omni_network_flutter:
    git:
      url: https://github.com/juwelzan/omni_route.git
      path: packages/omni_network_flutter
      ref: omni_network_flutter-v0.1.0
```

ওয়েবে `#` ছাড়া পরিষ্কার URL চাইলে `main()`-এ `runApp`-এর আগে একবার `OmniRoute.usePathUrls()` কল করুন:

```dart
void main() {
  OmniRoute.usePathUrls();
  runApp(const MyApp());
}
```

---

## ২. OmniApp — অ্যাপের রুট কনফিগারেশন

`OmniApp` আপনার পুরো অ্যাপের কেন্দ্রীয় রুট উইজেট। এটি ভেতরে একটি `OmniRouteRegistry` তৈরি করে সব `routes`-কে স্টার্টআপে **Segment Trie**-তে কম্পাইল করে (`O(segments)` সময়), গ্লোবাল `repositories` ও `blocs` মাউন্ট করে, গার্ড রিফ্রেশ স্ট্রিম শোনে, প্ল্যাটফর্ম ফিচার চালু করে এবং নেটিভ `OmniRouter` ইঞ্জিন চালায়।

আপনি তিনভাবে `OmniApp` ব্যবহার করতে পারেন:
- **`OmniApp(...)`**: যখন নিজে কাস্টম `builder: (context, router) => ...` দিয়ে নিজের মতো `MaterialApp.router` বা কাস্টম রুট উইজেট বানাবেন।
- **`OmniApp.material(...)`**: সব MaterialApp সেটিংসসহ রেডিমেড কনস্ট্রাক্টর — বারবার `builder:` লেখার ঝামেলা নেই।
- **`OmniApp.cupertino(...)`**: iOS-স্টাইল `CupertinoApp.router` রেডিমেড কনস্ট্রাক্টর।

---

### ২.১ কোর রাউটিং ও ডিপেনডেন্সি ইনজেকশন প্যারামিটার

#### ১. `routes` (`List<OmniRouteBase>`, আবশ্যক)
- **কীভাবে কাজ করে:** স্টার্টআপে `OmniApp` এই তালিকার সব `OmniPage`, `OmniRouteGroup`, `OmniShell` ও `OmniStatefulShell` পড়ে একটি ফাস্ট Segment Trie বানায়। ডুপ্লিকেট `routePath`, ডুপ্লিকেট `name`, বা ভুল প্যাটার্ন থাকলে রানটাইমের আগেই স্পষ্ট `OmniRouteException` থ্রো করে। Hot Reload-এ তালিকা বদলালে নতুন রুট ও গার্ড আপডেট হয়।
- **কী কাজে লাগে:** অ্যাপের সব স্ক্রিন, নেস্টেড রুট, ট্যাব এবং শেল লেআউট এক জায়গায় ডিক্লেয়ার করতে।
- **ব্যবহার:** হোম, ডিটেইল ও প্রোফাইল রুট রেজিস্টার করা হচ্ছে:

```dart
OmniApp.material(
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
    OmniPage('/users/:id', (p) => UserDetailScreen(id: p.pathInt('id'))),
    OmniPage.screen(const ProfileScreen()),
  ],
)
```

#### ২. `builder` (`Widget Function(BuildContext context, OmniRouter router)`, মূল `OmniApp`-এ আবশ্যক)
- **কীভাবে কাজ করে:** `OmniApp` গ্লোবাল প্রোভাইডার, গার্ড রিফ্রেশ ও লাইফসাইকেল স্কোপের নিচে `builder(context, router)` কল করে। এখান থেকে পাওয়া `router` অবজেক্ট সরাসরি `MaterialApp.router(routerConfig: router)` বা `CupertinoApp.router(routerConfig: router)`-এ বসাতে হয়।
- **কী কাজে লাগে:** যখন `MaterialApp` বা `CupertinoApp`-এ বিশেষ কোনো কাস্টমাইজেশন বা তৃতীয় কোনো রুট উইজেট (`FluentApp` বা কাস্টম Wrapper) র‍্যাপ করতে চান।
- **ব্যবহার:** `OmniApp`-এ কাস্টম `builder` দিয়ে `MaterialApp.router` চালানো হচ্ছে:

```dart
OmniApp(
  routes: routes,
  builder: (context, router) => MaterialApp.router(
    title: 'My App',
    routerConfig: router,
  ),
)
```

#### ৩. `repositories` (`List<OmniRepoEntry> = const []`)
- **কীভাবে কাজ করে:** গ্লোবাল `blocs`-এর **উপরে** `MultiRepositoryProvider` হিসেবে মাউন্ট হয়। ফলে যেকোনো গ্লোবাল বা পেজ Bloc তৈরি করার সময় `context.read<MyRepo>()` করে সার্ভিসটি পাওয়া যায়। `OmniApp` আনমাউন্ট হলে `dispose` কলব্যাক থাকলে স্বয়ংক্রিয়ভাবে রিসোর্স বন্ধ করে।
- **কী কাজে লাগে:** `OmniNetwork` ক্লায়েন্ট, `AuthRepository`, লোকাল ডাটাবেস বা শেয়ার্ড সার্ভিস পুরো অ্যাপে ইনজেক্ট করতে।
- **ব্যবহার:** `AuthRepository` রেজিস্টার করে সেটি থেকে `AuthBloc` তৈরি করা হচ্ছে:

```dart
OmniApp.material(
  repositories: [
    OmniRepo((_) => AuthRepository(), dispose: (r) => r.dispose()),
  ],
  blocs: [
    OmniBloc((c) => AuthBloc(c.read<AuthRepository>()), global: true),
  ],
  routes: routes,
)
```

#### ৪. `blocs` (`List<OmniBlocEntry> = const []`)
- **কীভাবে কাজ করে:** এখানে `OmniBloc(..., global: true)` দিলে অ্যাপ শুরুতেই `OmniRouter`-এর উপরে গ্লোবাল `BlocProvider` তৈরি হয়ে আজীবন বেঁচে থাকে। আর `global: false` (ডিফল্ট) দিলে ফ্যাক্টরি হিসেবে রেজিস্টার হয়ে থাকে—যখন কোনো স্ক্রিন `Provide<B>()` চায়, তখন ওই স্ক্রিনের লাইফসাইকেল অনুযায়ী তৈরি ও `close()` হয়।
- **কী কাজে লাগে:** অথেনটিকেশন, থিম, নোটিফিকেশন কাউন্টারের মতো গ্লোবাল Bloc চালাতে অথবা শেয়ার্ড ফ্যাক্টরি রাখতে।
- **ব্যবহার:** একটি গ্লোবাল `ThemeCubit` এবং একটি রুট-ভিত্তিক `CartBloc` ফ্যাক্টরি রেজিস্টার করা হচ্ছে:

```dart
OmniApp.material(
  blocs: [
    OmniBloc((_) => ThemeCubit(), global: true),
    OmniBloc((c) => CartBloc(c.read<CartRepo>())),
  ],
  routes: routes,
)
```

#### ৫. `initialRoute` (`String = '/'`)
- **কীভাবে কাজ করে:** অ্যাপ চালুর সময় প্ল্যাটফর্ম থেকে কোনো ডিপ লিংক বা ওয়েব URL না থাকলে এই পাথে প্রথমে ন্যাভিগেট করে। যদি প্ল্যাটফর্ম কোনো ডিপ লিংক দেয় (যেমন `/orders/42`), ডিপ লিংক প্রাধান্য পায়।
- **কী কাজে লাগে:** অ্যাপ খোলার প্রথম স্ক্রিন `/dashboard`, `/splash` বা `/home` হিসেবে নির্ধারণ করতে।
- **ব্যবহার:** অ্যাপ খোলার সাথে সাথে `/dashboard` দেখানো হচ্ছে:

```dart
OmniApp.material(
  initialRoute: '/dashboard',
  routes: routes,
)
```

#### ৬. `resolveInitialRoute` (`FutureOr<String?> Function(BuildContext context)? = null`)
- **কীভাবে কাজ করে:** `onInit` শেষ হওয়ার ঠিক পরে (রুট স্টার্ট হওয়ার আগেই) কল হয় এবং `splash` স্ক্রিন চলাকালীন কাজ করে। এখান থেকে নতুন রুট স্ট্রিং (যেমন `'/onboarding'`) রিটার্ন করলে প্রথম ফ্রেমেই ফ্লিকার ছাড়া সেই রুটে অ্যাপ চালু হয়। `null` দিলে `initialRoute` (বা ডিপ লিংক) বজায় থাকে।
- **কী কাজে লাগে:** স্টার্টআপে টোকেন চেক বা অনবোর্ডিং ফ্ল্যাগ পড়ে `/login`, `/onboarding` নাকি `/dashboard`-এ যাবে তা ঠিক করতে।
- **ব্যবহার:** অনবোর্ডিং শেষ কি না দেখে ডাইনামিক শুরুর রুট নির্বাচন করা হচ্ছে:

```dart
OmniApp.material(
  splash: (_) => const SplashView(),
  onInit: (context) => context.read<PrefsRepo>().load(),
  resolveInitialRoute: (context) async {
    final seen = context.read<PrefsRepo>().onboardingSeen;
    return seen ? '/dashboard' : '/onboarding';
  },
  routes: routes,
)
```

#### ৭. `transition` (`OmniPageType = OmniPages.material` / `.cupertino`-এ `OmniPages.cupertino`)
- **কীভাবে কাজ করে:** অ্যাপের সব `OmniPage`-এর ডিফল্ট পেজ ট্রানজিশন নির্ধারণ করে। কোনো নির্দিষ্ট রুট (`OmniPage(transition:)`), রুট গ্রুপ (`OmniRouteGroup(transition:)`) বা কল (`context.push(..., transition:)` / `animated: false`) আলাদাভাবে ওভাররাইড না করলে এটিই ব্যবহৃত হয়।
- **কী কাজে লাগে:** পুরো অ্যাপে একরকম ফ্লুইড অ্যানিমেশন (`fadeSlide`, `adaptive`, `swipeZoom`) দিতে।
- **ব্যবহার:** প্ল্যাটফর্ম অনুযায়ী স্মুথ অ্যানিমেশন (`adaptive`) সেট করা হচ্ছে:

```dart
OmniApp.material(
  transition: OmniPages.adaptive,
  routes: routes,
)
```

#### ৮. `guards` (`List<OmniGuard> = const []`)
- **কীভাবে কাজ করে:** প্রতিটি নেভিগেশনে (প্রথম রুট থেকে শুরু করে `go`, `push`, `replace`, ব্রাউজার ব্যাক বা গার্ড রিফ্রেশে) ক্রমানুসারে চলে। প্রথম যে গার্ড নন-নাল স্ট্রিং রিটার্ন করে, সেখানে রিডাইরেক্ট হয়। সব গার্ড সিনক্রোনাস হলে কোনো অতিরিক্ত ফ্রেম অপেক্ষা ছাড়াই সাথে সাথে রুট বদলায়।
- **কী কাজে লাগে:** লগইন ছাড়া প্রাইভেট পেজ ব্লক করা, মেইনটেন্যান্স মোড দেখানো বা ভেরিফিকেশন চেক করা।
- **ব্যবহার:** পুরো অ্যাপের জন্য `AuthGuard` যুক্ত করা হচ্ছে:

```dart
OmniApp.material(
  guards: const [AuthGuard()],
  routes: routes,
)
```

#### ৯. `refreshListenable` (`Listenable? = null`)
- **কীভাবে কাজ করে:** এই `Listenable` (যেমন `ChangeNotifier` বা `ValueNotifier`) প্রতিবার `notifyListeners()` ফায়ার করলে `OmniRouter` বর্তমান রুট ও সব গার্ড পুনরায় মূল্যায়ন করে। প্রয়োজন হলে স্বয়ংক্রিয়ভাবে রিডাইরেক্ট করে।
- **কী কাজে লাগে:** ব্লক ছাড়া অন্য কোনো `ChangeNotifier`-ভিত্তিক অথ/সেটিংস স্টেট বদলালে গার্ড রি-রান করাতে (উল্লেখ্য: `OmniGuard.refresh` স্ট্রিম ব্যবহার করলে এটি লাগেও না)।
- **ব্যবহার:** একটি `AuthNotifier` পরিবর্তন হলেই রুট রিফ্রেশ করা হচ্ছে:

```dart
OmniApp.material(
  refreshListenable: authNotifier,
  guards: [
    OmniGuard.fn((_, s) => authNotifier.loggedIn ? null : '/login'),
  ],
  routes: routes,
)
```

#### ১০. `notFound` (`Widget Function(BuildContext, OmniRouteState, Object?)? = null`)
- **কীভাবে কাজ করে:** কোনো অজানা URL হিট হলে, `OmniParams` পার্সিংয়ে ভুল হলে (যেমন `/users/abc` যেখানে `id` হওয়ার কথা `int`), অথবা গার্ড লুপে পড়লে `defaultOmniErrorBuilder`-এর বদলে এই বিল্ডার রেন্ডার হয়।
- **কী কাজে লাগে:** ব্র্যান্ডের সাথে মানানসই কাস্টম 404 বা এরর পেজ দেখাতে।
- **ব্যবহার:** কাস্টম ৪0৪ পেজ ও হোমে ফেরার বাটন দেখানো হচ্ছে:

```dart
OmniApp.material(
  notFound: (context, state, error) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => context.go('/'),
        child: Text('পেজ "${state.uri}" পাওয়া যায়নি'),
      ),
    ),
  ),
  routes: routes,
)
```

#### ১১. `navigatorKey` (`GlobalKey<NavigatorState>? = null`)
- **কীভাবে কাজ করে:** রুট `Navigator`-এ এই কী যুক্ত হয়। না দিলে `OmniApp` ভেতরে নিজেই একটি কী তৈরি ও সংরক্ষণ করে রাখে।
- **কী কাজে লাগে:** ডায়ালগ, স্ন্যাকবার বা `OmniShell`-এর ভেতরের পেজকে সরাসরি রুট নেভিগেটরে খুলতে (`parentNavigatorKey: rootNavKey`)।
- **ব্যবহার:** একটি রুট নেভিগেটর কী শেল ও পেজে শেয়ার করা হচ্ছে:

```dart
final rootNavKey = GlobalKey<NavigatorState>();

OmniApp.material(
  navigatorKey: rootNavKey,
  routes: routes,
)
```

#### ১২. `observers` (`List<NavigatorObserver>? = null`)
- **কীভাবে কাজ করে:** রুট `Navigator`-এ অবজার্ভার তালিকা পাস করে, যেন প্রতিটি `didPush`, `didPop`, `didReplace` ইভেন্টে অবজার্ভার ফায়ার হয়। Hot Reload-এ বদলালে রুট নেভিগেটর অবজার্ভার লিস্টও আপডেট হয়।
- **কী কাজে লাগে:** Firebase Analytics `FirebaseAnalyticsObserver`, `RouteObserver` বা কাস্টম অডিট টুল যুক্ত করতে।
- **ব্যবহার:** ফ্লাটারের একটি `RouteObserver` যুক্ত করা হচ্ছে:

```dart
final routeObserver = RouteObserver<ModalRoute<void>>();

OmniApp.material(
  observers: [routeObserver],
  routes: routes,
)
```

---

### ২.২ প্ল্যাটফর্ম UX ও নেভিগেশন কন্ট্রোল প্যারামিটার

#### ১৩. `setTitles` (`bool = true`)
- **কীভাবে কাজ করে:** সক্রিয় পেজের `OmniPage.title`, `metadata['title']` অথবা `OmniScreen.title` থেকে বর্তমান পেজের টাইটেল নিয়ে ওয়েবের ব্রাউজার ট্যাব এবং Android/Desktop/iOS টাস্ক-সুইচারের নাম অটো-আপডেট করে।
- **কী কাজে লাগে:** ওয়েবে ব্রাউজার ট্যাবে "Students", "Settings" ইত্যাদি ডাইনামিকভাবে দেখাতে।
- **ব্যবহার:** টাইটেল অটো-আপডেট চালু/বন্ধ করা:

```dart
OmniApp.material(
  setTitles: true, // false দিলে ব্রাউজার ট্যাবের শিরোনাম রুট পরিবর্তনে বদলাবে না
  routes: routes,
)
```

#### ১৪. `titleColor` (`Color? = null`)
- **কীভাবে কাজ করে:** `SystemChrome.setApplicationSwitcherDescription`-এ `title`-এর সাথে প্রাথমিক রঙ পাস করে।
- **কী কাজে লাগে:** Android-এর Recent Apps / Task Switcher হেডারে ব্র্যান্ড কালার দেখাতে।
- **ব্যবহার:** টাস্ক-সুইচারের ব্যাকগ্রাউন্ড রঙ নীল সেট করা:

```dart
OmniApp.material(
  setTitles: true,
  titleColor: const Color(0xFF1565C0),
  routes: routes,
)
```

#### ১৫. `swipeBack` (`OmniSwipeBack = OmniSwipeBack.none`)
- **কীভাবে কাজ করে:** কাস্টম বা `OmniPages.transition(...)` অ্যানিমেশনযুক্ত পেজে বাঁ বা ডান কিনারা থেকে আঙুল টেনে পেজ বন্ধ করার জেসচার লেয়ার যোগ করে। ডিফল্ট `none`।
- **কী কাজে লাগে:** `fade`, `slideUp`, `scale` ইত্যাদি কাস্টম ট্রানজিশন ব্যবহার করেও iOS-এর মতো কিনারা থেকে সোয়াইপ করে পেজ ব্যাক করার সুবিধা দিতে।
- **ব্যবহার:** পুরো অ্যাপে জুমিং সোয়াইপ-ব্যাক চালু করা:

```dart
OmniApp.material(
  transition: OmniPages.fadeSlide,
  swipeBack: OmniSwipeBack.zoomCard,
  routes: routes,
)
```

#### ১৬. `swipeBackStyle` (`OmniSwipeBackStyle = const OmniSwipeBackStyle()`)
- **কীভাবে কাজ করে:** `swipeBack` জেসচারের স্কেল, কর্নার রেডিয়াস, টিল্ট, শ্যাডো, কিনারার প্রস্থ এবং ফ্লিক ভেলোসিটি নিয়ন্ত্রণ করে। চাইলে `.subtle()` বা `.dramatic()` প্রিসেটও ব্যবহার করা যায়।
- **কী কাজে লাগে:** সোয়াইপ-ব্যাক অ্যানিমেশনকে নিজের ডিজাইন অনুযায়ী সূক্ষ্ম বা নাটকীয় করে তুলতে।
- **ব্যবহার:** সূক্ষ্ম সোয়াইপ স্টাইল ও কেবল বাম কিনারা সক্রিয় করা:

```dart
OmniApp.material(
  swipeBack: OmniSwipeBack.zoom,
  swipeBackStyle: const OmniSwipeBackStyle.subtle(
    edges: {OmniSwipeEdge.left},
  ),
  routes: routes,
)
```

#### ১৭. `predictiveBack` (`bool = false`)
- **কীভাবে কাজ করে:** Android-এ `material`, `cupertino` বা `adaptive` পেজগুলোকে ভেতর থেকে প্রেডিক্টিভ-ব্যাক ট্র্যাকারসহ পাতলা জুম পেজে আপগ্রেড করে, যাতে Android সিস্টেম ব্যাক জেসচারের সাথে পেজ প্রগ্রেস সিঙ্ক হয়।
- **কী কাজে লাগে:** Android 13/14+ ডিভাইসে নেটিভ প্রেডিক্টিভ ব্যাক প্রিভিউ অনুভূতি আনতে।
- **ব্যবহার:** Android-এ প্রেডিক্টিভ ব্যাক অন করা:

```dart
OmniApp.material(
  predictiveBack: true,
  routes: routes,
)
```

#### ১৮. `desktopBack` (`bool = true`)
- **কীভাবে কাজ করে:** macOS, Windows ও Linux-এ `Alt+Left`, `Cmd+[` (macOS), ব্রাউজার-ব্যাক কী এবং মাউসের সাইড ব্যাক বাটনে সাড়া দিয়ে স্বয়ংক্রিয়ভাবে `maybePop()` চালায়। টেক্সট ফিল্ডে ফোকাস থাকলে শর্টকাট নিরাপদভাবে কাজ করে।
- **কী কাজে লাগে:** ডেস্কটপ অ্যাপে নেটিভ ব্যাক শর্টকাট ও মাউস ব্যাক বাটন সাপোর্ট দিতে।
- **ব্যবহার:** ডেস্কটপ ব্যাক শর্টকাট সক্রিয় রাখা (ডিফল্ট `true`):

```dart
OmniApp.material(
  desktopBack: true,
  routes: routes,
)
```

#### ১৯. `escapeGoesBack` (`bool = false`)
- **কীভাবে কাজ করে:** ডেস্কটপে `Escape` কী চাপলে যদি কোনো ডায়ালগ বা বটমশিট খোলা না থাকে তবে `maybePop()` করে আগের পেজে ফিরে যায়। ডায়ালগ খোলা থাকলে আগে ডায়ালগ বন্ধ হয়।
- **কী কাজে লাগে:** ডেস্কটপ অ্যাপে কিবোর্ড-প্রথম ইউজারদের জন্য `Esc` দিয়ে দ্রুত ব্যাক হওয়ার সুবিধা দিতে।
- **ব্যবহার:** `Escape` দিয়ে পেজ ব্যাক চালু করা:

```dart
OmniApp.material(
  escapeGoesBack: true,
  routes: routes,
)
```

#### ২০. `restorationScopeId` (`String? = null`)
- **কীভাবে কাজ করে:** রুট `Navigator` ও `Router`-কে State Restoration বাকেট দেয়। OS মেমোরি বাঁচাতে অ্যাপ ব্যাকগ্রাউন্ডে কিল করলে পুনরায় খোলার সময় নেভিগেশন স্ট্যাক রিস্টোর করতে ব্যবহৃত হয়।
- **কী কাজে লাগে:** Android/iOS-এ ব্যাকগ্রাউন্ডে অ্যাপ বন্ধ হয়ে গেলে ফিরে এসে ব্যবহারকারী যে স্ক্রিনে ছিলেন সেখানেই নিয়ে যেতে।
- **ব্যবহার:** অ্যাপ ও রুট নেভিগেটরের জন্য রিস্টোরেশন আইডি সেট করা:

```dart
OmniApp.material(
  restorationScopeId: 'omni_app_root',
  routes: routes,
)
```

#### ২১. `dismissKeyboardOnTap` (`bool = false`)
- **কীভাবে কাজ করে:** স্ক্রিনের কোথাও ট্যাপ করলে যেকোনো সক্রিয় ফোকাস (`FocusManager.instance.primaryFocus`) আনফোকাস করে দেয় (তবে টেক্সট ফিল্ড বা বোতামে ট্যাপ করলে নষ্ট হয় না)।
- **কী কাজে লাগে:** ফর্ম স্ক্রিনে ইউজার বাইরে ট্যাপ করলেই কিবোর্ড সুন্দরভাবে নামিয়ে দিতে।
- **ব্যবহার:** বাইরে ট্যাপ করলে কিবোর্ড হাইড করা:

```dart
OmniApp.material(
  dismissKeyboardOnTap: true,
  routes: routes,
)
```

#### ২২. `doubleBackToExit` (`Duration? = null`)
- **কীভাবে কাজ করে:** Android-এর রুট পেজে এসে প্রথমবার ব্যাক বাটন চাপলে অ্যাপ বের না হয়ে `onExitWarning` কল করে; নির্ধারিত সময়ের (`Duration`) মধ্যে দ্বিতীয়বার ব্যাক চাপলে অ্যাপ এক্সিট হয়।
- **কী কাজে লাগে:** ভুল করে একবার ব্যাক বাটন চেপে যেন ব্যবহারকারী অ্যাপ থেকে বের হয়ে না যায়।
- **ব্যবহার:** ২ সেকেন্ডের মধ্যে দুবার ব্যাক চাপলে বের হওয়া:

```dart
OmniApp.material(
  doubleBackToExit: const Duration(seconds: 2),
  onExitWarning: (context) => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('বের হতে আবার ব্যাক চাপুন')),
  ),
  routes: routes,
)
```

#### ২৩. `onExitWarning` (`void Function(BuildContext context)? = null`)
- **কীভাবে কাজ করে:** `doubleBackToExit` সক্রিয় থাকা অবস্থায় প্রথম ব্যাক প্রেসটি ইন্টারসেপ্ট হলে ঠিক একবার এই কলব্যাক ফায়ার হয়।
- **কী কাজে লাগে:** "Press back again to exit" জাতীয় টোস্ট বা স্ন্যাকবার দেখাতে।
- **ব্যবহার:** উপরে ২২ নং উদাহরণ দেখুন।

#### ২৪. `orientations` (`List<DeviceOrientation>? = null`)
- **কীভাবে কাজ করে:** মাউন্ট হওয়ার সময় `SystemChrome.setPreferredOrientations` সেট করে এবং অ্যাপ আনমাউন্ট হলে পূর্বের অবস্থায় ফিরিয়ে দেয়।
- **কী কাজে লাগে:** পুরো অ্যাপ কেবল পোর্ট্রেট বা ল্যান্ডস্কেপে লক রাখতে।
- **ব্যবহার:** অ্যাপকে শুধু পোর্ট্রেট মোডে সীমাবদ্ধ করা:

```dart
OmniApp.material(
  orientations: const [DeviceOrientation.portraitUp],
  routes: routes,
)
```

#### ২৫. `minTextScale` (`double? = null`) ও ২৬. `maxTextScale` (`double? = null`)
- **কীভাবে কাজ করে:** সিস্টেমের `MediaQuery.textScaler`-কে `minTextScale` এবং `maxTextScale`-এর মধ্যে ক্ল্যাম্প করে দেয়, যাতে খুব বড় বা খুব ছোট সিস্টেম ফন্টে লেআউট ভেঙে না যায়।
- **কী কাজে লাগে:** অ্যাক্সেসিবিলিটি বজায় রেখেও UI ওভারফ্লো ঠেকাতে।
- **ব্যবহার:** টেক্সট স্কেল ০.৮৫ থেকে ১.৩০-এর মধ্যে সীমিত রাখা:

```dart
OmniApp.material(
  minTextScale: 0.85,
  maxTextScale: 1.30,
  routes: routes,
)
```

---

### ২.৩ স্টার্টআপ, লাইফসাইকেল, এনালিটিক্স ও এরর প্যারামিটার

#### ২৭. `lifecycle` (`OmniLifecycle? = null`)
- **কীভাবে কাজ করে:** গ্লোবাল `blocs`-এর নিচে একটি `OmniAppLifecycleScope` বসিয়ে পুরো অ্যাপের ফোরগ্রাউন্ড/ব্যাকগ্রাউন্ড/মেমোরি প্রেসার ইভেন্টে আপনার `OmniLifecycle` অবজেক্টের হুকগুলো চালায়।
- **কী কাজে লাগে:** অ্যাপ ব্যাকগ্রাউন্ডে গেলে সেশন লক করা বা ফিরে এলে ডেটা রিফ্রেশ করা।
- **ব্যবহার:** পুরো অ্যাপের জন্য একটি লাইফসাইকেল হ্যান্ডলার যুক্ত করা:

```dart
class AppLifecycle with OmniLifecycle {
  @override
  void onAppResumed(BuildContext context) {
    debugPrint('অ্যাপ আবার ফোরগ্রাউন্ডে এসেছে');
  }
}

OmniApp.material(
  lifecycle: AppLifecycle(),
  routes: routes,
)
```

#### ২৮. `onInit` (`Future<void> Function(BuildContext context)? = null`)
- **কীভাবে কাজ করে:** অ্যাপ শুরুতেই গ্লোবাল রিপোজিটরি/ব্লকের নিচে এই async কাজটি একবার চালায়। এটি শেষ না হওয়া পর্যন্ত `splash` উইজেট দেখায় (অথবা `splash` না দিলে রুট তৈরি হওয়ার আগে অপেক্ষা করে)। রিট্রাই করা হলে পুনরায় চলে।
- **কী কাজে লাগে:** ডাটাবেস খোলা, ডিস্ক থেকে টোকেন লোড করা বা রিমোট কনফিগ ফেচ করা।
- **ব্যবহার:** স্টোরেজ থেকে সেভ করা সেশন লোড করা:

```dart
OmniApp.material(
  onInit: (context) => context.read<SessionRepo>().restoreSession(),
  splash: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
  routes: routes,
)
```

#### ২৯. `initTimeout` (`Duration? = null`)
- **কীভাবে কাজ করে:** `onInit` যদি নির্দিষ্ট `Duration`-এর বেশি সময় নেয়, তবে `TimeoutException` তৈরি করে স্টার্টআপ আটকে যাওয়া থামায়। `onInitError` দেওয়া থাকলে রিট্রাই স্ক্রিনে পাঠায়; না থাকলে `onError`/`FlutterError`-এ রিপোর্ট করে অ্যাপ চালু করে।
- **কী কাজে লাগে:** নেটওয়ার্ক স্লো হলে স্প্ল্যাশ স্ক্রিন অনন্তকাল ঝুলে থাকা বন্ধ করতে।
- **ব্যবহার:** স্টার্টআপ ইনিশিয়ালাইজেশনে সর্বোচ্চ ৮ সেকেন্ড টাইমআউট সেট করা:

```dart
OmniApp.material(
  onInit: (c) => c.read<RemoteConfig>().fetch(),
  initTimeout: const Duration(seconds: 8),
  splash: (_) => const SplashScreen(),
  onInitError: (context, err, _, retry) => RetryScreen(error: err, onRetry: retry),
  routes: routes,
)
```

#### ৩০. `splash` (`WidgetBuilder? = null`)
- **কীভাবে কাজ করে:** `onInit` বা `resolveInitialRoute` চলাকালীন এই বিল্ডারের উইজেট স্ক্রিনে দেখায় (এবং `MaterialApp`-এর বাইরে থাকলেও স্বয়ংক্রিয়ভাবে `Directionality` নিশ্চিত করে)।
- **কী কাজে লাগে:** ব্র্যান্ডের লোগো বা লোডিং স্পিনার দেখানো যতক্ষণ না স্টার্টআপ ডেটা লোড হচ্ছে।
- **ব্যবহার:** উপরে ২৯ নং উদাহরণ দেখুন।

#### ৩১. `onInitError` (`Widget Function(BuildContext context, Object error, StackTrace stackTrace, VoidCallback retry)? = null`)
- **কীভাবে কাজ করে:** `onInit` (বা `resolveInitialRoute`) এরর বা টাইমআউট করলে এই বিল্ডার রেন্ডার হয়। এর চতুর্থ আর্গুমেন্ট `retry()` ফাংশনটি কল করলে পুরো `onInit` + `resolveInitialRoute` সিকোয়েন্স পুনরায় শুরু হয়।
- **কী কাজে লাগে:** অফলাইন বা সার্ভার এররে ক্র্যাশ না করে সুন্দর রিট্রাই স্ক্রিন দেখাতে।
- **ব্যবহার:** এরর মেসেজ ও রিট্রাই বাটন দেখানো:

```dart
onInitError: (context, error, stack, retry) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: retry,
        child: Text('লোড ব্যর্থ: $error — আবার চেষ্টা করুন'),
      ),
    ),
  ),
)
```

#### ৩২. `onNavigate` (`void Function(OmniNavigation navigation)? = null`)
- **কীভাবে কাজ করে:** যখনই সক্রিয় টপ পেজ বা তার URI/কী বদলায় (অ্যাপ স্টার্ট, `go`, `push`, `replace`, `pop`, `refresh`, বা `redirect`), তখনই `OmniNavigation` অবজেক্টসহ এই কলব্যাক ফায়ার হয়।
- **কী কাজে লাগে:** Analytics স্ক্রিন-ভিউ ট্র্যাকিং এবং ইন-অ্যাপ ইন্সপেক্টরে রুট লগ (`inspector.logRoute`) পাঠাতে।
- **ব্যবহার:** `navigation.kind`, `from`, `to` ও `uri` দিয়ে এনালিটিক্স ও ইনস্পেক্টর লগ করা হচ্ছে:

```dart
OmniApp.material(
  onNavigate: (nav) {
    debugPrint('${nav.kind.name}: ${nav.from?.location} -> ${nav.to.location}');
    inspector.logRoute('${nav.kind.name}: ${nav.to.location}');
  },
  routes: routes,
)
```

#### ৩৩. `logNavigation` (`bool = false`)
- **কীভাবে কাজ করে:** `kDebugMode`-এ প্রতিটি নেভিগেশন `OmniRoute.logger`-এ `from`, `to`, ও থাকলে `uri` বক্স আকারে প্রিন্ট করে। রিলিজ বিল্ডে স্বয়ংক্রিয়ভাবে কিছুই ছাপে না।
- **কী কাজে লাগে:** ডেভেলপমেন্টের সময় কনসোলে কোন রুট থেকে কোন রুটে যাচ্ছে এবং কোন স্ক্রিন ক্লাস তৈরি হলো তা তাৎক্ষণিক দেখতে।
- **ব্যবহার:** ডিবাগে নেভিগেশন লগ চালু করা:

```dart
OmniApp.material(
  logNavigation: true,
  routes: routes,
)
```

#### ৩৪. `blocObserver` (`BlocObserver? = null`)
- **কীভাবে কাজ করে:** অ্যাপ মাউন্ট হলে `Bloc.observer`-এ এই অবজার্ভার বসায় এবং অ্যাপ আনমাউন্ট হলে আগের অবজার্ভারটি রিস্টোর করে (যাতে একাধিক অ্যাপ বা টেস্ট নিরাপদ থাকে)।
- **কী কাজে লাগে:** সব Bloc ইভেন্ট, ট্রানজিশন ও ক্র্যাশ এক জায়গায় লগ করা বা `OmniInspector.logBloc`-এ পাঠানো।
- **ব্যবহার:** কাস্টম BlocObserver যুক্ত করা:

```dart
OmniApp.material(
  blocObserver: MyAppBlocObserver(),
  routes: routes,
)
```

#### ৩৫. `onError` (`void Function(Object error, StackTrace stack)? = null`)
- **কীভাবে কাজ করে:** `FlutterError.onError` ও `PlatformDispatcher.instance.onError` হুক করে আনকট এররগুলো এই হ্যান্ডলারে পাঠায় এবং আনমাউন্টে আগের হ্যান্ডলার ফিরিয়ে দেয়।
- **কী কাজে লাগে:** Firebase Crashlytics, Sentry বা লোকাল লগে অপ্রত্যাশিত এরর পাঠাতে।
- **ব্যবহার:** সব অপ্রত্যাশিত এরর ক্যাচ করে লগ করা:

```dart
OmniApp.material(
  onError: (error, stack) => crashReporter.record(error, stack),
  routes: routes,
)
```

#### ৩৬. `overlayBuilder` (`TransitionBuilder? = null`)
- **কীভাবে কাজ করে:** `OmniApp.material`/`OmniApp.cupertino`-তে `MaterialApp`/`CupertinoApp`-এর `builder`-এর ভেতরে (অর্থাৎ `Theme`, `Navigator`, `Directionality`-এর ভেতরে) অ্যাপের চারপাশে একটি ওভারলে র‍্যাপ করে (`appBuilder` দিলে তার বাইরে বসে)। আর মূল `OmniApp(...)`-এ `builder`-কে র‍্যাপ করে।
- **কী কাজে লাগে:** গ্লোবাল নেটওয়ার্ক ব্যানার, ফ্লোটিং ডিবাগ বাটন বা টোস্ট ওভারলে পুরো অ্যাপের উপরে বসাতে।
- **ব্যবহার:** `MaterialApp`-এর ভেতরে `OmniInspectorLauncher` যুক্ত করা:

```dart
OmniApp.material(
  overlayBuilder: (context, child) => OmniInspectorLauncher(
    inspector: inspector,
    initialTab: InspectorTab.logs,
    child: child!,
  ),
  routes: routes,
)
```

---

### ২.৪ `OmniApp.material` ও `OmniApp.cupertino` অতিরিক্ত প্যারামিটার

`OmniApp.material(...)` ও `OmniApp.cupertino(...)` সাধারণ `OmniApp`-এর সব প্যারামিটার ছাড়াও ফ্লাটারের রুট অ্যাপের প্যারামিটারগুলো সরাসরি নেয়:

| প্যারামিটার | ধরন | কীভাবে কাজ করে ও কী কাজে লাগে |
|---|---|---|
| `title` | `String = ''` | OS টাস্ক-সুইচার ও ব্রাউজার ট্যাবের ডিফল্ট শিরোনাম (যখন পেজের নিজস্ব `title` থাকে না)। |
| `theme` | `ThemeData?` / `CupertinoThemeData?` | লাইট মোডের থিম কালার, ফন্ট ও কম্পোনেন্ট স্টাইল। |
| `darkTheme` | `ThemeData?` (Material) | ডার্ক মোডের থিম। |
| `highContrastTheme` / `highContrastDarkTheme` | `ThemeData?` (Material) | উচ্চ কন্ট্রাস্ট অ্যাক্সেসিবিলিটি থিম। |
| `themeMode` | `ThemeMode?` (Material) | স্ট্যাটিক `ThemeMode.system` / `light` / `dark`। |
| `themeModeBuilder` | `ThemeMode? Function(BuildContext)?` (Material) | সরাসরি `ThemeCubit` বা `context.watch<ThemeBloc>()` থেকে ডাইনামিক `ThemeMode` পড়ার জন্য (থাকলে `themeMode`-কে ওভাররাইড করে)। |
| `color` | `Color?` | OS টাস্ক-সুইচারের প্রাথমিক রঙ। |
| `locale`, `localizationsDelegates`, `supportedLocales` | `Locale?` ... | বহুভাষী সাপোর্ট ও ডেট/নাম্বার ফরম্যাটিং (ডিফল্ট `Locale('en', 'US')`)। |
| `debugShowCheckedModeBanner` | `bool = true` | উপরের ডান কোনায় লাল "DEBUG" ব্যানার দেখানো বা লুকানো (`false`)। |
| `scaffoldMessengerKey` | `GlobalKey<ScaffoldMessengerState>?` (Material) | `BuildContext` ছাড়াই যেকোনো জায়গা থেকে গ্লোবাল `SnackBar` দেখানোর জন্য। |
| `shortcuts` ও `actions` | `Map<...>` | অ্যাপ-জুড়ে কাস্টম কিবোর্ড শর্টকাট ও Intent অ্যাকশন। |
| `scrollBehavior` | `ScrollBehavior?` | ওয়েব/ডেস্কটপে মাউস ও টাচ ড্র্যাগ স্ক্রলিং বা বাউন্স ফিজিক্স বদলানোর জন্য। |
| `appBuilder` | `TransitionBuilder?` | `MaterialApp.router(builder: ...)`-এর জায়গায় সরাসরি কাজ করে (`overlayBuilder`-ও দেওয়া থাকলে `overlayBuilder(context, appBuilder(context, child))` আকারে চেইন হয়)। |

**`themeModeBuilder` ও `appBuilder`-এর একসাথে ব্যবহার:**
```dart
OmniApp.material(
  title: 'OmniApp Demo',
  theme: ThemeData.light(useMaterial3: true),
  darkTheme: ThemeData.dark(useMaterial3: true),
  themeModeBuilder: (c) => c.watch<ThemeCubit>().state,
  appBuilder: (context, child) => OmniInspectorLauncher(
    inspector: inspector,
    initialTab: InspectorTab.logs,
    child: child!,
  ),
  routes: routes,
)
```

---

### ২.৫ `OmniApp.validateRoutes` স্ট্যাটিক মেথড

```dart
static List<String> validateRoutes(
  List<OmniRouteBase> routes, {
  GlobalKey<NavigatorState>? rootNavigatorKey,
})
```
- **কীভাবে কাজ করে:** UI রান না করেই সব `routes`-কে Trie-তে কম্পাইল করে ডুপ্লিকেট `routePath`, ডুপ্লিকেট `name`, বা অবৈধ প্যারামিটার সিনট্যাক্স খুঁজে বের করে এবং সব বৈধ ফুল পাথের তালিকা রিটার্ন করে।
- **কী কাজে লাগে:** ইউনিট টেস্টে (`flutter test`) বা `main()`-এ আগেভাগেই রুট কনফিগারেশন যাচাই করতে।
- **ব্যবহার:**

```dart
void main() {
  final paths = OmniApp.validateRoutes(appRoutes);
  debugPrint('রেজিস্টার্ড রুট (${paths.length}টি): $paths');
}
```

---

## ৩. OmniPage — রুট ও পেজ ডিক্লেয়ারেশন

`OmniPage<S extends Widget>` দুটি কনস্ট্রাক্টর দেয়:
- **`OmniPage(path, (p) => ...)`**: ডাইনামিক প্যারামিটার (`:id`, `?tab=`) যুক্ত পেজ বা যেকোনো `Widget`-এর জন্য।
- **`OmniPage.screen(const MyScreen(), ...)`**: কোনো `OmniScreen`-এর নিজস্ব `routePath` স্বয়ংক্রিয়ভাবে ব্যবহার করে রিপিট কোড শূন্যে নামিয়ে আনে।

#### ১. `path` (`String` পজিশনাল / `OmniPage.screen`-এ `String? path`)
- **কীভাবে কাজ করে:** রুট পাথ বা রিলেটিভ সেগমেন্ট (`'/'`, `'/students'`, `':id'`, `'edit'`, `'*rest'`)। `OmniPage.screen`-এ না দিলে স্বয়ংক্রিয়ভাবে `screen.routePath` নেয়। নেস্টেড রুটের সাথে প্যারেন্ট পাথ যোগ হয়ে ফুল পাথ তৈরি হয়।
- **কী কাজে লাগে:** কোন URL-এ কোন স্ক্রিন দেখাবে তা নির্ধারণ করতে।
- **ব্যবহার:**

```dart
OmniPage('/students', (_) => const StudentsScreen(), routes: [
  OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id'))),
])
```

#### ২. `screenBuilder` (`S Function(OmniParams p)`) / `screen` (`S`)
- **কীভাবে কাজ করে:** রুট ম্যাচ হলে ডিকোড করা `OmniParams p` দিয়ে স্ক্রিন তৈরি করে। প্যারামিটারে ভুল টাইপ দিলে এখানেই ক্যাচ হয়ে `notFound` এরর পেজ দেখায়।
- **কী কাজে লাগে:** কনস্ট্রাক্টরে প্যারামিটার পাস করে `OmniScreen` বা সাধারণ `StatelessWidget`/`StatefulWidget` তৈরি করতে।
- **ব্যবহার:**

```dart
OmniPage<ProductScreen>(
  '/products/:id',
  (p) => ProductScreen(productId: p.pathInt('id'), tab: p.query('tab')),
)
```

#### ৩. `name` (`String? = null`)
- **কীভাবে কাজ করে:** রুটের একটি অনন্য ডাকনাম সংরক্ষণ করে (`Trie`/রেজিস্ট্রিতে ইউনিক থাকতে হয়)। পরে URL মুখস্থ না করেই `goNamed`/`pushNamed` করা যায়।
- **কী কাজে লাগে:** দীর্ঘ URL পরিবর্তন হলেও নামের মাধ্যমে নিরাপদ নেভিগেশন বজায় রাখতে।
- **ব্যবহার:**

```dart
OmniPage('/orders/:id/invoice', (p) => InvoiceScreen(...), name: 'invoice');
// কল করা:
OmniRoute.pushNamed('invoice', path: {'id': 99});
```

#### ৪. `title` (`String? = null`)
- **কীভাবে কাজ করে:** পেজের শিরোনাম। না দিলে `metadata?['title']`, তাও না থাকলে `OmniScreen.title` ব্যবহার করে।
- **কী কাজে লাগে:** ব্রাউজার ট্যাব ও Android অ্যাপ সুইচারে নির্দিষ্ট নাম দেখাতে।
- **ব্যবহার:**

```dart
OmniPage('/checkout', (_) => const CheckoutScreen(), title: 'চেকআউট')
```

#### ৫. `transition` (`OmniPageType? = null`)
- **কীভাবে কাজ করে:** এই নির্দিষ্ট রুটের জন্য `OmniApp(transition:)` ওভাররাইড করে। (তবে কল করার সময় `animated: false` বা `transition:` দিলে কলেরটা প্রাধান্য পায়)।
- **কী কাজে লাগে:** কোনো নির্দিষ্ট পেজকে ডায়ালগ (`OmniPages.dialog()`), বটমশিট (`OmniPages.bottomSheet()`), বা নিচ থেকে স্লাইড (`OmniPages.slideUp`) হিসেবে দেখাতে।
- **ব্যবহার:**

```dart
OmniPage(
  '/filters',
  (_) => const FilterSheet(),
  transition: OmniPages.bottomSheet(showDragHandle: true, isScrollControlled: true),
)
```

#### ৬. `guards` (`List<OmniGuard> = const []`)
- **কীভাবে কাজ করে:** অ্যাপের গ্লোবাল গার্ডের পর এই রুট (ও এর নেস্টেড চাইল্ড রুট) খোলার সময় চলে। এর রিফ্রেশ স্ট্রিমও `GuardRefresh` দ্বারা শোনা হয়।
- **কী কাজে লাগে:** শুধু `/admin` বা বিশেষ পেজের জন্য রোল বা পেমেন্ট ভেরিফিকেশন চেক বসাতে।
- **ব্যবহার:**

```dart
OmniPage('/admin', (_) => const AdminScreen(), guards: const [AdminOnlyGuard()])
```

#### ৭. `provide` (`List<OmniBlocEntry> = const []`) ও ৮. `blocs` (`List<OmniBlocEntry> = const []`)
- **কীভাবে কাজ করে:** দুটোই পেজ লেভেলের স্কোপড Bloc ডিক্লেয়ার করে (কোডে দুটো মার্জ হয়)। পেজ স্ট্যাকে ঢুকলে `BlocProvider` তৈরি হয়, আর পেজ পপ বা রিপ্লেস হয়ে চলে গেলে স্বয়ংক্রিয়ভাবে `close()` হয়। সাধারণ `Widget` স্ক্রিনেও এটা সরাসরি কাজ করে! (আর `OmniBloc((_) => MyBloc())` দিলে আগে `OmniApp(blocs:)`-এ রেজিস্টারও লাগে না।)
- **কী কাজে লাগে:** সাধারণ `Widget` বা `OmniScreen`-কে সরাসরি রুটে বসেই পেজ-স্কোপড Bloc দিতে।
- **ব্যবহার:**

```dart
OmniPage(
  '/cart',
  (_) => const CartWidget(),
  blocs: [OmniBloc((c) => CartBloc(c.read<CartRepo>()))],
)
```

#### ৯. `onExit` (`FutureOr<bool> Function(BuildContext context)? = null`)
- **কীভাবে কাজ করে:** ইউজার ব্যাক বাটন, সোয়াইপ বা `maybePop` দিয়ে এই পেজ ছাড়তে চাইলে আগে `onExit(context)` কল হয়। `true` দিলে পেজ বন্ধ হয়, `false` দিলে পেজে থেকে যায়।
- **কী কাজে লাগে:** ফর্মে আনসেভড ডেটা থাকলে "Save না করে বের হবেন?" কনফার্মেশন ডায়ালগ দেখাতে।
- **ব্যবহার:**

```dart
OmniPage(
  '/profile/edit',
  (_) => const EditProfileScreen(),
  onExit: (context) => confirmDiscardChanges(context),
)
```

#### ১০. `routes` (`List<OmniRouteBase> = const []`)
- **কীভাবে কাজ করে:** এই পেজের অধীনে চাইল্ড রুট (`OmniPage` বা `OmniRouteGroup`) যুক্ত করে। `'/students'`-এর চাইল্ড `':id'` হলে ফুল পাথ হয় `'/students/:id'`, আর ব্রাউজার বা `pop` চাপলে প্যারেন্ট রুটে ফেরার ন্যাভিগেশন স্ট্যাক পায়।
- **কী কাজে লাগে:** মাস্টার-ডিটেইল ও হায়ারার্কিক্যাল রুট গঠন বানাতে।
- **ব্যবহার:** উপরে ১ নং উদাহরণ দেখুন।

#### ১১. `metadata` (`Map<String, dynamic>? = null`)
- **কীভাবে কাজ করে:** রুটের সাথে যেকোনো কাস্টম ডেটা যুক্ত করে যা `OmniRouteState.metadata`, `OmniRouteEntry.metadata` এবং `OmniGuard.redirect`-এ পড়া যায়।
- **কী কাজে লাগে:** রুটে `{'requiresRole': 'admin', 'analyticsGroup': 'checkout'}` জাতীয় ট্যাগ রাখতে।
- **ব্যবহার:**

```dart
OmniPage('/billing', (_) => const BillingScreen(), metadata: const {'role': 'owner'})
```

#### ১২. `parentNavigatorKey` (`GlobalKey<NavigatorState>? = null`)
- **কীভাবে কাজ করে:** যদি রুটটি কোনো `OmniShell` বা `OmniStatefulShell` ট্যাবের ভেতর থাকে, তবে এটি দিয়ে দিলে পেজটি শেলের ভেতরের নেভিগেটরে না খুলে নির্দিষ্ট প্যারেন্ট/রুট নেভিগেটরে (যেমন বটম-বার ঢেকে ফুল-স্ক্রিনে) খুলবে।
- **কী কাজে লাগে:** ট্যাব শেলের ভেতর থেকে কোনো পেজ বা ডায়ালগ বটম ন্যাভবার লুকিয়ে ফুল-স্ক্রিনে ওপেন করতে।
- **ব্যবহার:**

```dart
OmniPage('/player', (_) => const FullscreenPlayer(), parentNavigatorKey: rootNavKey)
```

---

## ৪. Navigation API — `OmniRoute`, `BuildContext` এক্সটেনশন ও `OmniScreen` শর্টকাট

নেভিগেশনের প্রতিটি মেথড তিনটি জায়গাতেই সমানভাবে আছে:
1. গ্লোবাল স্ট্যাটিক কল: `OmniRoute.go(...)`, `OmniRoute.to<S>(...)`, `OmniRoute.push(...)` — `BuildContext` ছাড়াই Bloc বা সার্ভিস থেকেও কাজ করে।
2. কনটেক্সট এক্সটেনশন: `context.go(...)`, `context.to<S>(...)`, `context.push(...)` — একাধিক `OmniApp` থাকলে নিকটস্থ অ্যাপকে টার্গেট করে।
3. `OmniState`-এর ভেতরে সরাসরি: `go(...)`, `to<S>(...)`, `pushTo<S>(...)`, `pop()`।

### কমন নেভিগেশন মেথড ও প্যারামিটার

| মেথড | কীভাবে কাজ করে ও কী কাজে লাগে |
|---|---|
| `go(location, {extra, animated = true, transition})` | বর্তমান স্ট্যাক প্রতিস্থাপন করে `location`-এ যায়। (যেমন লগইনের পর `/dashboard`-এ যাওয়া)। |
| `push<T>(location, {extra, animated = true, transition})` | স্ট্যাকের উপরে নতুন পেজ তোলে; `await context.push<bool>(...)` দিয়ে ফিরে আসা রেজাল্ট নেওয়া যায়। |
| `replace(location, {extra, animated = true, transition})` | স্ট্যাকের গভীরতা না বাড়িয়ে শুধু টপ পেজটি বদলে দেয়। |
| `open<T>(location, {extra, maxDepth = 10, animated = true, transition})` | ডুপ্লিকেট-ফ্রি স্মার্ট নেভিগেশন: ইতিমধ্যে টপে থাকলে কিছু করে না; স্ট্যাকের নিচে থাকলে সেখানেই ফিরে যায়; `maxDepth` পার হলে `go` করে; নাহলে `push` করে। |
| `pop<T>([result])` | উপরের পেজটি বন্ধ করে এবং চাইলে প্যারেন্টে `result` ফেরত দেয়। |
| `maybePop<T>([result])` / `canPop()` | `canPop()` চেক করে পপ করা সম্ভব হলেই পপ করে (`true` রিটার্ন করে), রুট পেজে নিরাপদ (`false`)। |
| `popUntil(location)` / `popToRoot()` | নির্দিষ্ট `location` (যেমন `'/home'`) বা অ্যাক্টিভ স্ট্যাক/ট্যাবের রুট পর্যন্ত একবারে সব পেজ পপ করে। |
| `refresh()` | বর্তমান লোকেশনের উপর সব গার্ড ও রিডাইরেক্ট সাথে সাথে পুনরায় চালায়। |
| `to<S>` / `pushTo<S>` / `replaceTo<S>` / `openTo<S>` | URL স্ট্রিং না লিখে টাইপ-সেফ স্ক্রিন ক্লাস দিয়ে নেভিগেট করে (`path:`, `query:` সহ)। |
| `goNamed` / `pushNamed` / `replaceNamed` | `OmniPage(name:)` ব্যবহার করে নেমড রাউটিং। |
| `goPath` / `pushPath` / `openPath` / `replacePath` | ক্যানোনিকাল পাথ প্যাটার্ন (যেমন `'/students/:id'`) + `path: {'id': 5}` দিয়ে নেভিগেট করা। |

#### নেভিগেশন মেথডের প্রতিটি প্যারামিটার:
- **`location` (`String`) / `routePath` (`String`) / `name` (`String`)**: গন্তব্য রুট বা লোকেশন।
- **`path` (`Map<String, Object?> = const {}`)**: পাথের `:id`-এর মতো জায়গায় মান বসায় (যেমন `path: {'id': 101}` → `/students/101`)।
- **`query` (`Map<String, Object?> = const {}`)**: `?tab=grades&sort=asc` ইত্যাদি URL query তৈরি করে (`null` ভ্যালু স্বয়ংক্রিয়ভাবে বাদ দেয়)।
- **`extra` (`Object? = null`)**: মেমোরিতে থাকা যেকোনো অবজেক্ট পাস করে (যেমন পূর্ণ `User` মডেল)। *সতর্কতা:* ব্রাউজার রিফ্রেশ করলে `extra` হারিয়ে যায়, তাই আইডি URL-এ রাখাই উত্তম।
- **`maxDepth` (`int = 10`, কেবল `open`/`openTo`/`openPath`-এ)**: পুশ স্ট্যাক এই সংখ্যার সমান বা বড় হয়ে গেলে মেমোরি বাঁচাতে `push`-এর বদলে `go` করে স্ট্যাক রিসেট করে।
- **`animated` (`bool = true`)**: `false` দিলে পেজটি কোনো ট্রানজিশন অ্যানিমেশন ও ফ্রেম অপেক্ষা ছাড়াই সাথে সাথে (`OmniPages.none`) খুলে যায়।
- **`transition` (`OmniPageType? = null`)**: কেবল এই একটি নেভিগেশনের জন্য পেজের ডিফল্ট অ্যানিমেশন বদলে দেয় (যেমন `transition: OmniPages.slideUp`)।

**ব্যবহারের উদাহরণ:**
```dart
// ১. অ্যানিমেশন ছাড়াই সাথে সাথে টাইপ-সেফ নেভিগেশন
context.pushTo<StudentDetailScreen>(
  path: {'id': 101},
  query: {'tab': 'marks'},
  animated: false,
);

// ২. ডুপ্লিকেট ছাড়া স্মার্ট ওপেন, সর্বোচ্চ স্ট্যাক ৫টি পেজ
await context.open('/notifications', maxDepth: 5);

// ৩. কেবল এই কলের জন্য ভিন্ন ট্রানজিশন
OmniRoute.push('/preview', transition: OmniPages.fadeScale);
```

### রুট ইন্সপেকশন ও URL হেল্পারসমূহ

- **`OmniRoute.current`**: বর্তমান উপরের পেজের `OmniRouteEntry` (`location`, `routePath`, `name`, `screen`, `metadata`)।
- **`OmniRoute.currentListenable`**: `ValueListenable<OmniRouteEntry>` — রুট বদলালে সরাসরি UI আপডেট করতে `ValueListenableBuilder`-এ ব্যবহার করুন।
- **`OmniRoute.stack`**: নিচ থেকে উপর পর্যন্ত অ্যাক্টিভ স্ট্যাকের সব পেজের `List<OmniRouteEntry>`।
- **`OmniRoute.paths`**: অ্যাপে রেজিস্ট্রার করা সব ফুল `routePath`-এর তালিকা।
- **`OmniRoute.hasRoute('/students/10')`**: এই URL ম্যাচ করবে কি না (`bool`) যাচাই করে।
- **`OmniRoute.locationFor` / `locationNamed` / `locationOf<S>`**: কোনো নেভিগেশন না করেই শুধু ফরম্যাট করা URL স্ট্রিং (যেমন শেয়ার বাটন বা টেস্টের জন্য) রিটার্ন করে।
- **`context.params` / `context.routeState` / `context.routePath` / `context.bloc<B>()`**: যেকোনো চাইল্ড উইজেট থেকে শর্টকাটে প্যারামিটার ও Bloc পড়ার জন্য।

---

## ৫. `OmniParams` ও `OmniRouteState` — রুট ডেটা ও প্যারামিটার পড়া

`OmniParams` হলো `OmniRouteState`-এর টাইপ-সেফ র‍্যাপার। প্রতিটি মান আগে থেকেই URL-ডিকোড করা থাকে এবং ভুল টাইপ দিলে অ্যাপ ক্র্যাশ না করে `notFound` এরর পেজ দেখায়।

| মেথড / প্রোপার্টি | কীভাবে কাজ করে | উদাহরণ (ধরি URL `/users/7?age=25&rate=4.5&active=true&sort=newest&tag=a&tag=b`) |
|---|---|---|
| `OmniParams.of(context)` / `.maybeOf(context)` | কনটেক্সট থেকে রুট প্যারামিটার পড়ে (`initState`-এও সম্পূর্ণ নিরাপদ, rebuild সাবস্ক্রাইব করে না)। | `OmniParams.of(context).pathInt('id')` |
| `p.path(name)` | প্রয়োজনীয় পাথ প্যারামিটার `String` দেয় (না থাকলে এরর পেজ)। | `p.path('id')` → `'7'` |
| `p.pathInt(name)` | পাথ প্যারামিটার `int`-এ পার্স করে (নম্বর না হলে এরর পেজ)। | `p.pathInt('id')` → `7` |
| `p.query(name)` | ঐচ্ছিক query `String?` দেয়। | `p.query('tab')` → `null` |
| `p.queryInt(name)` | ঐচ্ছিক query `int?` পার্স করে। | `p.queryInt('age')` → `25` |
| `p.queryDouble(name)` | ঐচ্ছিক দশমিক query `double?` পার্স করে। | `p.queryDouble('rate')` → `4.5` |
| `p.queryBool(name)` | `'true'`, `'1'`, `'false'`, `'0'` (case-insensitive) থেকে `bool?` দেয়। | `p.queryBool('active')` → `true` |
| `p.queryEnum(name, values)` | enum নামের সাথে ম্যাচ করে `T?` দেয়। | `p.queryEnum('sort', Sort.values)` → `Sort.newest` |
| `p.queryAll(name)` | পুনরাবৃত্ত সব query মানের তালিকা `List<String>` দেয়। | `p.queryAll('tag')` → `['a', 'b']` |
| `p.extra<T>()` | নেভিগেশনের সাথে পাঠানো `extra` অবজেক্ট টাইপ-চেক করে রিটার্ন করে। | `p.extra<Student>()` |
| `p.uri` / `p.state` | সম্পূর্ণ `Uri` এবং মূল `OmniRouteState` (`matchedLocation`, `metadata`, `pageKey`, `error`)। | `p.uri.toString()` |

**`OmniRouteState`-এর নিজস্ব হেল্পারসমূহ:**
- `OmniRouteState.of(context)` / `maybeOf(context)`: প্যারামিটার বা query বদলালে উইজেট রি-বিল্ড করায় (রিঅ্যাক্টিভ)।
- `OmniRouteState.readOf(context)` / `readMaybeOf(context)`: কোনো সাবস্ক্রিপশন ছাড়াই একবার পড়ে (`initState`-এর জন্য নিরাপদ)।

---

## ৬. `OmniRepo`, `OmniBloc` ও `Provide` — DI ও Bloc স্কোপিং

### `OmniRepo<T>` (`OmniApp(repositories:)`-এর জন্য)

#### `OmniRepo(create, {lazy = true, dispose})` ও `OmniRepo.value(value)`
- **`create` (`T Function(BuildContext)`):** সার্ভিস বা রিপোজিটরি তৈরির ফ্যাক্টরি।
- **`lazy` (`bool = true`):** `true` থাকলে প্রথমবার `context.read<T>()` কল না হওয়া পর্যন্ত তৈরি হয় না। `false` দিলে অ্যাপ শুরুতেই তৈরি হয়।
- **`dispose` (`void Function(T instance)?`):** `OmniApp` আনমাউন্ট হলে ক্লিনআপ চালায় (যেমন `client.close()` বা ডিস্ক স্টোর বন্ধ)।
- **`OmniRepo.value(existingInstance)`:** আগে থেকেই তৈরি অবজেক্ট পাস করে (যেমন `main()`-এ তৈরি করা `OmniNetwork`); `OmniRoute` এটি ডিস্পোজ করে না।

**ব্যবহার:**
```dart
repositories: [
  OmniRepo.value(apiClient),
  OmniRepo((c) => UserRepo(c.read<OmniNetwork>()), lazy: false, dispose: (r) => r.dispose()),
]
```

### `OmniBloc<B>` ও `Provide<B>`

| কনস্ট্রাক্টর / হেল্পার | `global` | `lazy` | কোথায় ও কীভাবে কাজ করে |
|---|---|---|---|
| `OmniBloc((c) => MyBloc(), global: true)` | `true` | `true` | `OmniApp(blocs:)`-এ বসে। অ্যাপ জুড়ে একটিই ইনস্ট্যান্স বেঁচে থাকে। |
| `OmniBloc((c) => MyBloc())` | `false` | `true` | `OmniApp(blocs:)`, `OmniPage(blocs:)`, `Provide` বা `OmniRouteGroup`-এ বসে; প্রথম ব্যবহারে তৈরি ও স্কোপ ছাড়লে `close()` হয়। |
| `OmniBloc.eager((c) => MyBloc(), global: ...)` | ঐচ্ছিক | `false` | প্রথম রিডের অপেক্ষা না করে স্কোপ/অ্যাপ মাউন্ট হওয়ার সাথে সাথেই তৈরি হয় (যেমন পেজ ঢুকতেই ডেটা লোড)। |
| `OmniBloc.forPage((c) => MyBloc(), lazy: true)` | `false` | `true` | `OmniScreen.provide` লিস্টের ভেতরে টাইপ উল্লেখ ছাড়াই ফ্যাক্টরি ডিক্লেয়ার করার শর্টহ্যান্ড। |
| `Provide<MyBloc>({lazy: true})` | `false` | `true` | `OmniApp(blocs:)`-এ আগে রেজিস্টার করা ফ্যাক্টরি খুঁজে এই পেজের জন্য আলাদা ইনস্ট্যান্স তৈরি করে। |
| `Provide.create((c) => ...)` / `Provide.eager(...)` | `false` | `true`/`false` | নির্দিষ্ট স্ক্রিনেই তৈরি করে (যেমন `OmniParams.of(c).pathInt('id')` পড়ে)। |
| `Provide.bloc((c) => ...)` / `Provide.blocEager(...)` | `false` | `true`/`false` | `Provide` লিস্টের মধ্যে স্বয়ংক্রিয় টাইপ ইনফারেন্সসহ পেজ-স্কোপড ও অটো-রেজিস্টার্ড শর্টহ্যান্ড (`<MyBloc>` লেখার প্রয়োজন নেই)। |
| `Provide.value(existingBloc)` | — | — | বাইরে তৈরি ব্লক রুট পেজে সরবরাহ করে; রুট পপ হলে `OmniRoute` এটিকে `close()` করে **না**। |

---

## ৭. Shell ও Tab — `OmniShell`, `OmniStatefulShell`, `OmniBranch`, `OmniNavigationShell`

### `OmniShell` (শেয়ার্ড লেআউট, একটাই নেভিগেটর স্ট্যাক)
- **`builder` (`Widget Function(BuildContext, OmniRouteState, Widget child)`):** চাইল্ড রুট `child`-এর চারপাশে `AppBar`, `NavigationDrawer` বা বটম বার আঁকে।
- **`routes` (`List<OmniRouteBase>`):** এই শেলের ভেতরে চলবে এমন সব চাইল্ড রুট।
- **`provide` (`List<OmniBlocEntry> = const []`):** এই শেলের স্থায়িত্বকাল পর্যন্ত বেঁচে থাকা Bloc।
- **`navigatorKey` (`GlobalKey<NavigatorState>?`):** শেলের ভেতরের নেভিগেটরের নিজস্ব কী।
- **`parentNavigatorKey` (`GlobalKey<NavigatorState>?`):** কোনো নেস্টেড শেল বা রুট নেভিগেটরের কী।
- **`observers` (`List<NavigatorObserver> = const []`):** কেবল এই শেলের ভেতরের নেভিগেটরের অবজার্ভার।
- **`guards` (`List<OmniGuard> = const []`):** এই শেলের ভেতরের প্রতিটি রুটে প্রযোজ্য গার্ড।

### `OmniStatefulShell`, `OmniBranch`, `OmniNavigationShell` (পৃথক ট্যাব স্ট্যাক ও স্টেট সংরক্ষণ)
প্রতিটি ট্যাবের নিজস্ব স্ক্রল পজিশন, স্ট্যাক এবং Bloc অটুট রাখে (ভেতরে `IndexedStack`)।
- **`OmniStatefulShell` প্যারামিটার:**
  - `builder` (`Widget Function(BuildContext, OmniRouteState, OmniNavigationShell shell)`): `shell` নিজেই উইজেট (বডিতে বসাবেন) এবং কন্ট্রোলার (`shell.currentIndex`, `shell.goBranch(...)`, `shell.branchCount`)।
  - `branches` (`List<OmniBranch>`): প্রতিটি ট্যাবের শাখা।
  - `provide` (`List<OmniBlocEntry>`): পুরো ট্যাবড শেল জুড়ে শেয়ার্ড Bloc।
  - `parentNavigatorKey`: আউটার নেভিগেটর কী।
  - `restorationScopeId`: কোন ট্যাব সক্রিয় ও কোন ট্যাবে কতদূর নেভিগেট করা আছে তা রিস্টোর করে।
  - `guards`: শেলের সব ট্যাবের রুটে প্রযোজ্য গার্ড।
- **`OmniBranch` প্যারামিটার:**
  - `routes`: এই ট্যাবের ভেতরের রুট তালিকা (আবশ্যক)।
  - `initialLocation` (`String?`): ট্যাবে প্রথমবার এলে কোন রুট খুলবে (না দিলে প্রথম রুট)।
  - `provide` (`List<OmniBlocEntry>`): কেবল এই ট্যাবের আজীবন Bloc।
  - `navigatorKey` (`GlobalKey<NavigatorState>?`): ট্যাবের নিজস্ব নেভিগেটরের কী।
  - `observers` (`List<NavigatorObserver>`): ট্যাবের নিজস্ব অবজার্ভার।
  - `restorationScopeId` (`String?`): ট্যাব স্ট্যাকের রিস্টোরেশন আইডি।
- **`OmniNavigationShell.goBranch(int index, {bool initialLocation = false})`:**
  - `index` নং ট্যাবে স্যুইচ করে। `initialLocation: true` দিলে ট্যাবটি আবার তার মূল রুট পেজে রিসেট হয়ে যায় (যেমন অ্যাক্টিভ ট্যাবে আবার ট্যাপ করলে হোমে ফেরা)।

**ব্যবহার:**
```dart
OmniStatefulShell(
  restorationScopeId: 'main_tabs',
  builder: (context, state, shell) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'হোম'),
        NavigationDestination(icon: Icon(Icons.api), label: 'API ল্যাব'),
      ],
    ),
  ),
  branches: [
    OmniBranch(routes: [OmniPage.screen(const HomeScreen())]),
    OmniBranch(routes: [OmniPage.screen(const ApiLabScreen())]),
  ],
)
```

---

## ৮. `OmniRouteGroup` — নেস্টেড Navigator ছাড়া শেয়ার্ড Bloc

কয়েকটি সম্পর্কিত রুট (যেমন বিস্তারিত দেখা + এডিট করা) একই Bloc শেয়ার করবে, অথচ কোনো নতুন `Navigator` বা `Shell` বানাতে চান না—তার জন্য `OmniRouteGroup`:
- **`routes` (`List<OmniRouteBase>`, আবশ্যক):** এই গ্রুপের অন্তর্ভুক্ত রুটসমূহ।
- **`provide` (`List<OmniBlocEntry>`, আবশ্যক):** গ্রুপের প্রথম কোনো রুটে ঢুকলেই Bloc তৈরি হয়; গ্রুপের এক রুট থেকে আরেক রুটে গেলে Bloc অক্ষুণ্ণ থাকে; গ্রুপের শেষ পেজ পপ হয়ে গেলে স্বয়ংক্রিয়ভাবে `close()` হয়।
- **`scopeKey` (`Object? Function(OmniRouteState state)?`):** যেমন `(s) => s.pathParameters['id']` — ধরুন ইউজার `/students/10` থেকে সোজা `/students/20`-এ গেল। যেহেতু `scopeKey` (`10` → `20`) বদলে গেছে, তাই আগের ছাত্রের Bloc বন্ধ হয়ে নতুন ছাত্রের Bloc তৈরি হবে!
- **`guards` (`List<OmniGuard> = const []`):** গ্রুপের সব রুটে প্রযোজ্য গার্ড।
- **`transition` (`OmniPageType?`):** গ্রুপের সব রুটের ডিফল্ট ট্রানজিশন।

---

## ৯. `OmniGuard` — লগইন, রোল ও রিডাইরেক্ট গার্ড

গার্ড দুভাবে লেখা যায়: `OmniGuard` ক্লাস এক্সটেন্ড করে, অথবা এক লাইনে `OmniGuard.fn(redirect, {refresh: ...})` দিয়ে।
- **`redirect(BuildContext context, OmniRouteState state)` (`FutureOr<String?>`):**
  - নেভিগেশনের আগে রান হয়। যে স্ট্রিং (যেমন `'/login?from=/settings'`) রিটার্ন করবেন, সেখানে রিডাইরেক্ট হবে; `null` দিলে ঢুকতে দেবে। গার্ডে সরাসরি নেটওয়ার্ক কল না করে `context.read<AuthBloc>().state` পড়া উচিত।
- **`refresh(BuildContext context)` (`Stream<Object?>? = null`):**
  - যে স্ট্রিম (যেমন `context.read<AuthBloc>().stream`) ইভেন্ট পাঠালে গার্ড স্বয়ংক্রিয়ভাবে রি-ইভালুয়েট হবে। সাবস্ক্রাইব ও ডিস্পোজ `OmniApp` নিজেই করে।

**ব্যবহার (ক্লাস ও ইনলাইন দুই রূপেই):**
```dart
// ১. ক্লাস দিয়ে:
class AuthGuard extends OmniGuard {
  const AuthGuard();

  @override
  Stream<Object?> refresh(BuildContext c) => c.read<AuthBloc>().stream;

  @override
  String? redirect(BuildContext c, OmniRouteState s) {
    final loggedIn = c.read<AuthBloc>().state.isLoggedIn;
    if (!loggedIn && s.matchedLocation != '/login') {
      return '/login?from=${Uri.encodeComponent(s.location)}';
    }
    if (loggedIn && s.matchedLocation == '/login') return '/dashboard';
    return null;
  }
}

// ২. ইনলাইন শর্টহ্যান্ড:
final onboardingGuard = OmniGuard.fn(
  (c, s) => c.read<AppPrefs>().done ? null : '/onboarding',
  refresh: (c) => c.read<AppPrefs>().changes,
);
```

---

## ১০. Screen ও Lifecycle — `OmniScreen`, `OmniStatelessWidget`, `OmniStatefulWidget`, `OmniState`, `OmniScreenHost`, `OmniLifecycle`

### `OmniScreen` প্রোপার্টি ও মেথড (Stateless/Stateful দুটোরই জন্য)
- **`routePath` (`String`, আবশ্যক):** স্ক্রিনের ক্যানোনিকাল পাথ (`'/students'`, `'/students/:id'`)।
- **`title` (`String`):** ডিফল্টভাবে `routePath` থেকে নাম বানায় (`'/students'` → `'Students'`)। ব্রাউজার ট্যাব ও টাস্ক-সুইচারে ব্যবহৃত হয়।
- **`provide` (`List<Provide> = const []`):** এই স্ক্রিনে ঢুকলেই তৈরি ও বের হলে `close()` হওয়া পেজ-স্কোপড Bloc তালিকা।
- **`debugName` (`String`):** ডিবাগ লগের জন্য রানটাইম ক্লাস নাম।
- **`metadata` (`OmniScreenMetadata`):** স্ক্রিনের `type`, `routePath`, `title` ও `debugName` সমৃদ্ধ ইমিউটেবল তথ্য।
- **`resolvePath({path, query})`:** স্ক্রিনের `routePath`-এ প্যারামিটার বসিয়ে সম্পূর্ণ URL স্ট্রিং রিটার্ন করে।
- **`go(context, ...)` / `push(context, ...)` / `open(context, ...)` / `replace(context, ...)`:** স্ক্রিন অবজেক্ট থেকেই সরাসরি নেভিগেশন।
- **`hosted({Key? key})`:** কোনো Stateful স্ক্রিনকে সরাসরি রুটের বাইরে (যেমন দুই প্যানেল লেআউট বা ডায়ালগে) দেখাতে `OmniScreenHost`-এ র‍্যাপ করে দেয়।

### `OmniState<T>` অতিরিক্ত সুবিধা
- **`onReady(BuildContext context)`:** প্রথম ফ্রেম আঁকা শেষ হওয়ার পর কেবল একবার চলে (ডায়ালগ খোলা বা প্রাথমিক অ্যানিমেশনের জন্য নিরাপদ)।
- **`onRouteChanged(OmniRouteState previous, OmniRouteState current)`:** পেজ আনমাউন্ট না হয়ে শুধু URL বা query বদলালে (যেমন `?tab=2`) ফায়ার হয়; অপ্রয়োজনীয় থিম বা MediaQuery পরিবর্তনে ফায়ার হয় না।
- **`safeSetState(fn)`:** `mounted` চেক করে তবেই `setState` চালায়।
- **`readBloc<B>()` ও `watchBloc<B>()`:** Bloc পড়া ও সাবস্ক্রাইব করা।
- **`routeState`, `maybeRouteState`, `params`, `maybeParams`, `routePath`, `screenTitle`, `metadata`:** `initState`-এও নিরাপদ অ্যাক্সেস।

### `OmniScreenHost(screen: ...)`
- **কীভাবে কাজ করে:** যখন `OmniStatefulWidget`-কে `OmniPage` দিয়ে না খুলে অন্য কোনো পেজের ভেতরে সাধারণ চাইল্ড উইজেট হিসেবে বসান, তখন তার `provide` Bloc তৈরি করার জন্য `OmniScreenHost(screen: MyScreen())` বা `const MyScreen().hosted()` ব্যবহার করতে হয় (Stateless স্ক্রিন নিজেই অটো-হোস্ট করে নেয়)।

### `OmniLifecycle` মিক্সিন (Stateless স্ক্রিন অথবা `OmniState`-এ মিক্স করুন)
বয়লারপ্লেট `WidgetsBindingObserver` ছাড়াই স্বয়ংক্রিয়ভাবে সিস্টেম ও স্ক্রিন ইভেন্ট হুক দেয়:
- **অ্যাপ লাইফসাইকেল:** `onAppLifecycleChanged(c, state)`, `onAppResumed(c)`, `onAppInactive(c)`, `onAppHidden(c)`, `onAppPaused(c)`, `onAppDetached(c)`
- **স্ক্রিন দৃশ্যমানতা (নতুন ও অত্যন্ত কাজের):**
  - `onScreenVisible(c)`: স্ক্রিনটি প্রথম দেখা গেলে, উপরের পেজ পপ হলে, অথবা এর ট্যাব পুনরায় সিলেক্ট হলে ফায়ার হয়।
  - `onScreenHidden(c)`: উপরে আরেকটি পেজ পুশ হলে, অন্য ট্যাবে গেলে, অথবা স্ক্রিন পপ হলে ফায়ার হয়। (সবশেষ চূড়ান্ত ডিস্পোজালে `context.read` না করে ফিল্ডে ডেটা রাখুন)।
- **সিস্টেম পরিবর্তন:** `onMemoryPressure(c)`, `onMetricsChanged(c)`, `onBrightnessChanged(c, brightness)`, `onLocalesChanged(c, locales)`, `onTextScaleChanged(c)`।

*(সতর্কতা: `OmniStatefulWidget`-এ `OmniLifecycle` না বসিয়ে সবসময় তার `OmniState`-এ মিক্স করবেন।)*

---

## ১১. Animation ও Swipe Back — `OmniPages`, `OmniTransition`, `OmniSwipeBack`, `OmniSwipeBackStyle`

### `OmniPages` রেডিমেড ট্রানজিশনসমূহ
- **`OmniPages.adaptive`**: ওয়েবে জিরো-ল্যাগ `none`, iOS/macOS-এ `cupertino`, বাকি প্ল্যাটফর্মে `material`।
- **`OmniPages.material`**: প্ল্যাটফর্মের স্ট্যান্ডার্ড Material পেজ ট্রানজিশন।
- **`OmniPages.cupertino`**: iOS স্টাইল ডান-বাম স্লাইড ও কিনারা-সোয়াইপ ব্যাক।
- **`OmniPages.none`**: শূন্য অ্যানিমেশন ফ্রেম — তাৎক্ষণিক পেজ পরিবর্তন।
- **`OmniPages.fade`**, **`OmniPages.slide`**, **`OmniPages.slideUp`**, **`OmniPages.scale`**, **`OmniPages.fadeScale`**, **`OmniPages.fadeSlide`**, **`OmniPages.swipeZoom`** (জুম-ইন + জুমিং সোয়াইপ ব্যাক)।

### `OmniPages.transition(kind, ...)` ও `OmniPages.custom(builder, ...)`
- **`kind` (`OmniTransition`):** `fade`, `slide`, `slideUp`, `scale`, `fadeScale`, `fadeSlide`।
- **`duration` (`Duration = 250ms`):** পেজ খোলার সময়কাল।
- **`reverseDuration` (`Duration = 200ms`):** পেজ বন্ধের সময়কাল।
- **`curve` (`Curve = Curves.easeOutCubic`):** অ্যানিমেশনের গতি-বক্র।
- **`builder` (`OmniTransitionBuilder`, কেবল `custom`-এ):** নিজস্ব ট্রানজিশন উইজেট তৈরির জন্য।
- **`opaque` (`bool = true`), `barrierColor` (`Color?`), `barrierDismissible` (`bool = false`), `fullscreenDialog` (`bool = false`)** (`custom`-এ): ট্রান্সপারেন্ট ওভারলে, ব্যাকগ্রাউন্ড ডিম বা মডাল ডায়ালগ আচরণের জন্য।
- **`swipeBack` (`OmniSwipeBack?`):** এই রুটের জন্য নির্দিষ্ট সোয়াইপ-ব্যাক স্টাইল।
- **`swipeBackStyle` (`OmniSwipeBackStyle?`):** এই রুটের জন্য সোয়াইপ টিউনিং।

### `OmniPages.dialog(...)` ও `OmniPages.bottomSheet(...)`
- **`OmniPages.dialog({barrierColor = Colors.black54, barrierDismissible = true})`:** স্ক্রিনটিকে স্ট্যান্ডার্ড `DialogRoute`-এ দেখায়।
- **`OmniPages.bottomSheet({showDragHandle, isScrollControlled = false})`:** স্ক্রিনটিকে `ModalBottomSheetRoute`-এ দেখায়; `isScrollControlled: true` দিলে লম্বা ফর্ম বা পুরো-উচ্চতার শিটও সুন্দরভাবে ফিট হয়।

### `OmniSwipeBack` মোডসমূহ (`none`, `slide`, `zoom`, `zoomCenter`, `zoomToEdge`, `zoomFollow`, `zoomCard`, `zoomParallax`, `zoomTilt`)
- **`none`**: কোনো সোয়াইপ জেসচার নেই।
- **`slide`**: iOS-এর মতো পেজ ১:১ আঙুলের সাথে সরে এবং নিচের পেজ -৩০% প্যারালাক্স থেকে ভেসে আসে।
- **`zoom` / `zoomCard` / `zoomParallax`**: পেজ ছোট হয়ে গোল কর্নার পায় (সর্বোচ্চ ব্যাসার্ধ `maxRadius`), `zoomCard`-এ নিচের পেজ ধীরে ধীরে আলোকিত হয় (`dimBelow`), `zoomParallax`-এ নিচের পেজটিও ০.৯৪ → ১.০ বড় হয়।
- **`zoomCenter` / `zoomToEdge` / `zoomFollow` / `zoomTilt`**: মাঝখানে জুম হয়ে হারানো, প্রান্তের দিকে ছিটকে যাওয়া, আঙুল অনুসরণ করা বা ৩ডি দরজার মতো হেলে পড়া (`maxTilt`)।

### `OmniSwipeBackStyle` প্রতিটি প্যারামিটার
- **`minScale` (`double?`)**: পুরোপুরি টানলে পেজ কত ছোট হবে (`0 < minScale <= 1`, নাল রাখলে মোডের ডিফল্ট)।
- **`maxRadius` (`double?`)**: সোয়াইপের সময় চার কোনা সর্বোচ্চ কত পিক্সেল গোল হবে।
- **`slideFactor` (`double?`)**: আঙুলের দূরত্বের কত শতাংশ পেজ সরবে (`0.45` = ৪৫%)।
- **`fadeStart` (`double?`)**: প্রগ্রেস কত পার হওয়ার পর ফেইড-আউট শুরু হবে (`0 <= fadeStart < 1`)।
- **`maxTilt` (`double = 0.25`)**: `zoomTilt` মোডে ৩ডি ঘূর্ণনের সর্বোচ্চ রেডিয়ান কোণ (ছোট রাখলে টেক্সট উল্টে যায় না)।
- **`shadow` (`bool?`)**: সরতে থাকা পেজের কিনারায় ছায়া দেখাবে কি না।
- **`dimBelow` (`bool?`)**: নিচের পেজ হালকা অন্ধকার থেকে ক্রমে আলোকিত হবে কি না।
- **`backgroundColor` (`Color?`)**: জুম-প্যারালাক্সে নিচের পেজের পেছনের ব্যাকগ্রাউন্ড রঙ (নাল হলে `scaffoldBackgroundColor`)।
- **`edgeWidth` (`double = 28`)**: স্ক্রিনের ধার থেকে কত পিক্সেল চওড়া এলাকা থেকে সোয়াইপ ধরা শুরু হবে।
- **`edges` (`Set<OmniSwipeEdge> = {left, right}`)**: কেবল বাম, ডান নাকি দুই ধার থেকেই সোয়াইপ শুরু করা যাবে।
- **`closeThreshold` (`double = 0.5`)**: স্ক্রিনের কত অংশ টেনে ছেড়ে দিলে পেজ পপ হয়ে বন্ধ হবে (`0.5` = ৫০%)।
- **`flickVelocity` (`double = 1.0`)**: ধীরভাবে টানলেও যদি এর চেয়ে দ্রুত ফ্লিক (screen-width/sec) করা হয়, পেজ বন্ধ হয়ে যাবে।
- **`settleCurve` (`Curve = Curves.easeOutBack`)**: ছেড়ে দিলে বাতিল হয়ে আগের অবস্থানে ফেরার বাউন্স কার্ভ।
- **`closeCurve` (`Curve = Curves.easeOutCubic`)**: বন্ধ হওয়ার কার্ভ।
- **`settleDuration` (`Duration = 300ms`)**: জায়গামতো স্থির হতে সর্বোচ্চ সময়।

*(রেডিমেড প্রিসেট: `const OmniSwipeBackStyle.subtle(...)` এবং `const OmniSwipeBackStyle.dramatic(...)`।)*

---

## ১২. Debugging, Terminal Color Log ও In-App Inspector

টার্মিনাল লগিং এবং অ্যাপের ভেতরে Talker-স্টাইল ইন্সপেক্টর ব্যবহারের প্রতিটি প্যারামিটার নিচে দেওয়া হলো (সম্পূর্ণ `omni_network` HTTP/Auth/WS/AI প্যারামিটার গাইড পড়ুন [omni_network বাংলা গাইডে](../packages/omni_network/doc/guide.bn.md))।

### `LogOptions` (`packages/omni_network`) প্যারামিটারসমূহ

| প্যারামিটার | ধরন ও ডিফল্ট | কীভাবে কাজ করে ও কী কাজে লাগে |
|---|---|---|
| `summary` | `bool = false` | `true` দিলে স্ট্যাটাস ব্যাজ (`🟢 ✔ 200 OK · SUCCESS`), গতি (`⚡ FAST`), সোর্স (`NETWORK`/`CACHE`) ও JSON কাঠামোর সারসংক্ষেপ লাইন যোগ করে। |
| `separate` | `bool = false` | `true` দিলে Request (`📡 http-request`), Response Header ও JSON Body আলাদা আলাদা কালার-কোডেড বক্সে ছাপে এবং JSON-এর প্রতি লাইনে অতিরিক্ত ইমোজি দেয় না। |
| `colors` | `bool? = null` | `null` মানে অটো-ডিটেকশন: Android লগ, macOS/Linux ডেস্কটপ, Chrome DevTools ও কালার TTY-তে ANSI রঙ চালু থাকে; iOS-এ `os_log` `ESC`-কে `\^[` করে ফেলায় ডিফল্ট প্লেইন থাকে (`true`/`false` দিয়ে জোর করে চালু/বন্ধ করা যায়)। |
| `headers` | `bool = false` | `true` করলে সেন্সিটিভ হেডার (`***` করে) রিকোয়েস্ট ও রেসপন্স হেডার প্রিন্ট করে। |
| `requestBody` | `bool = true` | রিকোয়েস্ট পে-লোড JSON সুন্দর করে (গোপন কী `***` রেখে) প্রিন্ট করে কি না। |
| `responseBody` | `bool = true` | রেসপন্স বডি সিনট্যাক্স-কালারড JSON আকারে প্রিন্ট করে কি না। |
| `maxLines` | `int? = null` | `null` থাকলে পুরো ৫০০–১০০০+ লাইনের বডিও প্রিন্ট হয়। সংখ্যা দিলে সেই সীমার পর `… N more lines` লিখে কাটে। |
| `width` | `int = 60` | টার্মিনাল বক্সের ফ্রেম লাইনের প্রস্থ। |
| `maxLineLength` | `int = 160` | এর চেয়ে লম্বা লাইন `↪` চিহ্ন দিয়ে পরের লাইনে মুড়ে দেয়, যাতে লম্বা ডেটাও না কাটে। |

**আলাদা কালার্ড লগের ব্যবহার ও ম্যাচিং রঙ:**
- **Request (`📡 http-request`)**: ম্যাজেন্টা ফ্রেম (`38;5;171`)
- **Success (`2xx`)**: সবুজ ফ্রেম (`38;5;40`) + সিনট্যাক্স-কালারড JSON (`key` সায়ান, `string` হলুদ, `number` বেগুনি, `bool/null` গোলাপি)
- **Redirect (`3xx`)**: নীল ফ্রেম (`38;5;39`)
- **Warning (`4xx`)**: কমলা ফ্রেম ও `⚠️ http-warning` (`38;5;214`)
- **Error (`5xx` / অফলাইন)**: লাল ফ্রেম (`38;5;196`) + লাল ব্যাকগ্রাউন্ডে সাদা বোল্ড ব্যানার (`⛔ http-error`)

```dart
final inspector = OmniInspector();

final api = OmniNetwork(
  baseUrl: 'https://jsonplaceholder.typicode.com',
  enableLogging: true,
  logOptions: const LogOptions(
    summary: true,
    separate: true,
    headers: false,
    maxLineLength: 160,
  ),
  logSink: MultiLogSink([
    PrettyLogSink(options: const LogOptions(summary: true, separate: true)),
    inspector.sink('api'),
  ]),
);

// রানটাইমে যেকোনো মুহূর্তে পরিবর্তন:
api.enableLogging = true;
api.logResponse = true; // false করলে শুধু বডি প্রিন্ট বন্ধ
api.logColors = null;   // true / false / null
```

### `OmniInspector` ও `OmniInspectorLauncher` (`omni_network_flutter`)

- **`OmniInspector({bool? enabled, int maxEntries = 300, LogSink? forwardTo})`:**
  - `enabled`: নাল রাখলে কেবল Debug/Profile-এ চালু, Release বিল্ডে অটো-বন্ধ।
  - `maxEntries`: সর্বোচ্চ কতগুলো HTTP এন্ট্রি রাখবে (টাইমলাইনে তার দ্বিগুণ কার্ড সংরক্ষণ করে)।
  - `forwardTo`: অতিরিক্ত কোনো `LogSink`-এ ফরওয়ার্ড করতে।
- **হেল্পার মেথডসমূহ:**
  - `inspector.sink('api')`: নির্দিষ্ট ট্যাগসহ `OmniNetwork(logSink:)`-এ ব্যবহার।
  - `inspector.attachClient(api, includeAi: true)`: ওয়েবসকেট ও AI কল অটো-রেকর্ড করে; ফেরা কলব্যাক দিয়ে ডিস্পোজে ডিটাচ করা যায়।
  - `inspector.logRoute(title, {subtitle, duration})` ও `inspector.logBloc(tag, title, {kind, subtitle})`: Talker-স্টাইল টাইমলাইনে রুট ও ব্লক কার্ড পাঠানো।
  - `inspector.toHarJson()` ও `inspector.toMarkdownReport()`: রিড্যাক্টেড HAR 1.2 JSON বা Markdown বাগ রিপোর্ট এক্সপোর্ট।
- **`OmniInspectorLauncher(inspector:, child:, alignment: Alignment.bottomRight, initialTab: InspectorTab.http)`:**
  - `initialTab`: সরাসরি Talker-স্টাইল কার্ড ও ১-ক্লিক কপি ট্যাবে খুলতে `InspectorTab.logs` দিন (অথবা `http`, `ws`, `ai`)। প্রতি কার্ডেই এক ট্যাপে JSON কপি, আর ভেতরের ভিউতে **`Copy Full Response`**, **`Copy Full Log`**, **`Copy as cURL`**, **`Copy HAR`** এবং টুলবারে **`Copy all logs`** বাটন রয়েছে।
