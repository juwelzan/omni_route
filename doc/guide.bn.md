# OmniRoute — সহজ ও পূর্ণাঙ্গ বাংলা গাইড

এই গাইডটি এমনভাবে সাজানো হয়েছে যেন শুরুতেই বুঝতে পারেন **কখন কোন জিনিসটি ব্যবহার করবেন**, তারপর ধাপে ধাপে **প্রতিটি ক্লাস ও প্রতিটি প্যারামিটারের আসল কাজ, ভেতরের আচরণ ও কোড উদাহরণ** সহজে দেখে নিতে পারেন।

> - **থিমিং মোড গাইড (`OmniTheme` — Dark/Light, TextField, Button ও Custom Setup):** [doc/theming.bn.md](theming.bn.md)
> - ইংরেজি টেকনিক্যাল ডকুমেন্ট: [architecture.md](architecture.md) · [web.md](web.md) · [platforms.md](platforms.md) · [migration.md](migration.md)
> - API কল, WebSocket ও AI-এর আলাদা বাংলা গাইড: [omni_network বাংলা গাইড](../packages/omni_network/doc/guide.bn.md)
> - প্রজেক্ট ওভারভিউ: [মূল README](../README.md)

---

## সূচিপত্র

1. [কোন কাজে কোনটা ব্যবহার করবেন — এক নজরে](#১-কোন-কাজে-কোনটা-ব্যবহার-করবেন--এক-নজরে)
2. [শুরু করার ধাপ (ইনস্টলেশন ও প্রথম অ্যাপ)](#২-শুরু-করার-ধাপ-ইনস্টলেশন-ও-প্রথম-অ্যাপ)
3. [Screen তৈরি — OmniStatelessWidget, OmniStatefulWidget ও OmniState](#৩-screen-তৈরি--omnistatelesswidget-omnistatefulwidget-ও-omnistate)
4. [রুট ও পেজ সাজানো — OmniPage (প্রতিটি প্যারামিটারসহ)](#৪-রুট-ও-পেজ-সাজানো--omnipage-প্রতিটি-প্যারামিটারসহ)
5. [এক পেজ থেকে অন্য পেজে যাওয়া — Navigation ও Back নিয়ন্ত্রণ](#৫-এক-পেজ-থেকে-অন্য-পেজে-যাওয়া--navigation-ও-back-নিয়ন্ত্রণ)
6. [URL থেকে ID ও তথ্য পড়া — OmniParams ও OmniRouteState](#৬-url-থেকে-id-ও-তথ্য-পড়া--omniparams-ও-omniroutestate)
7. [OmniApp — অ্যাপের সব প্যারামিটার ও প্রতিটির ব্যবহার](#৭-omniapp--অ্যাপের-সব-প্যারামিটার-ও-প্রতিটির-ব্যবহার)
   - [৭.ক. সহজ এন্ট্রি-ফ্লো কনফিগ: OmniConfig (Splash, Onboarding, Auth ও Public রুট)](#ক-সহজ-এন্ট্রি-ফ্লো-কনফিগ-omniconfig-splash-onboarding-auth-ও-public-রুট)
   - [৭.১ রুট, সার্ভিস, গার্ড ও বেসিক সেটআপ](#৭১-রুট-সার্ভিস-গার্ড-ও-বেসিক-সেটআপ)
   - [৭.২ স্টার্টআপ স্প্ল্যাশ, অনবোর্ডিং, অথ/পাবলিক কনফিগ ও এনালিটিক্স](#৭২-স্টার্টআপ-স্প্ল্যাশ-অনবোর্ডিং-অথপাবলিক-কনফিগ-ও-এনালিটিক্স)
   - [৭.৩ মোবাইল, ডেস্কটপ ও ওয়েব নিয়ন্ত্রণ](#৭৩-মোবাইল-ডেস্কটপ-ও-ওয়েব-নিয়ন্ত্রণ)
   - [৭.৪ OmniApp.material ও OmniApp.cupertino-এর অতিরিক্ত প্যারামিটার](#৭৪-omniappmaterial-ও-omniappcupertino-এর-অতিরিক্ত-প্যারামিটার)
8. [ডেটা ও Bloc ব্যবস্থাপনা — OmniRepo, OmniBloc, Provide ও OmniRouteGroup](#৮-ডেটা-ও-bloc-ব্যবস্থাপনা--omnirepo-omnibloc-provide-ও-omniroutegroup)
9. [ট্যাব ও শেয়ার্ড লেআউট — OmniShell ও OmniStatefulShell](#৯-ট্যাব-ও-শেয়ার্ড-লেআউট--omnishell-ও-omnistatefulshell)
10. [লগইন ও অনুমতি গার্ড — OmniGuard](#১০-লগইন-ও-অনুমতি-গার্ড--omniguard)
11. [অ্যাপ ও স্ক্রিনের লাইফসাইকেল — OmniLifecycle ও OmniScreenHost](#১১-অ্যাপ-ও-স্ক্রিনের-লাইফসাইকেল--omnilifecycle-ও-omniscreenhost)
12. [পেজ অ্যানিমেশন ও সোয়াইপ ব্যাক — OmniPages ও OmniSwipeBackStyle](#১২-পেজ-অ্যানিমেশন-ও-সোয়াইপ-ব্যাক--omnipages-ও-omniswipebackstyle)
13. [টার্মিনাল কালার লগ ও ইন-অ্যাপ ইন্সপেক্টর — LogOptions ও OmniInspector](#১৩-টার্মিনাল-কালার-লগ-ও-ইন-অ্যাপ-ইন্সপেক্টর--logoptions-ও-omniinspector)
14. [জিরো-ল্যাগ Responsive Handling — OmniResponsiveConfig ও অ্যাডাপ্টিভ শেল/মোডাল](#১৪-জিরো-ল্যাগ-responsive-handling--omniresponsiveconfig-ও-অ্যাডাপ্টিভ-শেলমোডাল)

---

## ১. কোন কাজে কোনটা ব্যবহার করবেন — এক নজরে

কোড লেখার আগে শুধু নিচের টেবিলটা দেখে নিন—কোন সমস্যার জন্য `omni_route`-এর কোন অংশটি বানানো হয়েছে:

| আপনি কী করতে চান? | কোনটি ব্যবহার করবেন? | সহজ কথায় কেন ব্যবহার করবেন? |
|---|---|---|
| পুরো অ্যাপ চালু করতে | `OmniApp.material(...)` / `.cupertino(...)` / `OmniApp(...)` | রাউটার, Bloc, গার্ড, থিম, স্প্ল্যাশ ও এরর সব একসাথে সেটআপ করে দেয়। |
| স্ক্রিন ক্লাস বানাতে | `OmniStatelessWidget` বা `OmniStatefulWidget` + `OmniState` | স্ক্রিনের নিজের `routePath`, অটো-Bloc ও রেডি লাইফসাইকেল হুক পাওয়া যায়। |
| URL-এর সাথে পেজ যুক্ত করতে | `OmniPage` বা `OmniPage.screen(...)` | `/students/:id` পাথের সাথে স্ক্রিন, অ্যানিমেশন ও গার্ড বেঁধে দেয়। |
| অন্য পেজে যেতে (নরমাল) | `context.push(...)` / `pushTo<S>()` | আগের পেজের উপর নতুন পেজ খোলে — চাইলে Back করে ফেরা যায়। |
| আগের পেজ মুছে নতুন পেজে যেতে | `context.replace(...)` / `replaceTo<S>()` | যেমন **Login → Home**: আগের পেজ মুছে যায়, Mobile বা Web Back করা যায় না। |
| পুরো স্ট্যাক পাল্টে নতুন জায়গায় যেতে | `context.go(...)` / `to<S>()` | যেমন সাইড মেনু বা হোমে যাওয়া (`replaceHistory: true` দিলে Web Back-ও বন্ধ হয়)। |
| ডুপ্লিকেট ছাড়া পেজ খুলতে | `context.open(...)` / `openTo<S>()` | পেজটি আগেই স্ট্যাকে থাকলে নতুন করে না খুলে সেখানেই ফিরে যায়। |
| URL থেকে ID বা Query নিতে | `OmniParams` (`p.pathInt('id')`, `p.query('tab')`) | স্ট্রিং থেকে নিরাপদে `int`, `double`, `bool` বা `enum` পড়ে। |
| API / সার্ভিস পুরো অ্যাপে দিতে | `OmniRepo` | `OmniNetwork` বা ডাটাবেস সবার জন্য তৈরি করে এবং অ্যাপ বন্ধে ক্লিয়ার করে। |
| State / Bloc কোথায় দেবেন? | `OmniBloc(..., global: true)` / `Provide` / `OmniRouteGroup` | গ্লোবাল, এক পেজের জন্য, নাকি ২-৩টি পেজ জুড়ে থাকবে—তা ঠিক করে দেয়। |
| নিচে Bottom Nav Bar / ট্যাব বানাতে | `OmniStatefulShell` + `OmniBranch` | প্রতি ট্যাবের নিজস্ব স্ক্রল ও নেভিগেশন আলাদাভাবে বাঁচিয়ে রাখে। |
| ট্যাব ছাড়া কমন ফ্রেম (Drawer/AppBar) | `OmniShell` | সব পেজের চারপাশে একই লেআউট রাখে। |
| লগইন ছাড়া ভেতরে ঢোকা আটকাতে | `OmniGuard` | পেজ খোলার আগেই চেক করে `/login` বা অন্য রুটে পাঠিয়ে দেয়। |
| অ্যাপ ব্যাকগ্রাউন্ড/সামনে এলে জানতে | `OmniLifecycle` | `onScreenVisible`, `onAppPaused` ইত্যাদি হুক বিনা ঝামেলায় দেয়। |
| রঙিন টার্মিনাল লগ ও UI-তে লগ দেখতে | `LogOptions(separate: true)` + `OmniInspectorLauncher` | Request/Response আলাদা কালার বক্সে দেখায় ও ১ ক্লিকে JSON কপি করায়। |

---

## ২. শুরু করার ধাপ (ইনস্টলেশন ও প্রথম অ্যাপ)

### ধাপ ১: শুধু একটি প্লাগিন যোগ করুন (`pubspec.yaml`)

`omni_route` যোগ করলে Routing, Bloc/Cubit (`flutter_bloc`), Onboarding + Local DB, নেটিভ `OmniNative` আর পুরো `omni_responsive` (responsive layout, theme, field, system UI, localization) সাথে আসে — আলাদা করে `flutter_bloc`, `omni_responsive` বা `shared_preferences` লিখতে হয় না। Networking (`omni_network`) আর `flutter_secure_storage` **আসে না**; দরকার হলে আলাদা যোগ করুন (README §১ ও §২১ দেখুন):

```yaml
dependencies:
  omni_route:
    git:
      url: https://github.com/juwelzan/omni_route.git
      ref: v0.5.0
```
> তারপর `import 'package:omni_route/omni_route.dart';` লিখলেই Routing, Bloc/Cubit, Onboarding + Local DB, Responsive/Theme ও নেটিভ `OmniNative` পাওয়া যাবে। টেস্টের helper: `package:omni_route/testing.dart`। API call-এর জন্য `omni_network` যোগ করে `package:omni_network/omni_network.dart`।

### ধাপ ২: একটি ছোট পূর্ণাঙ্গ অ্যাপ (`main.dart`)

নিচের কোডেই দেখুন—কীভাবে `main()`-এ ওয়েব URL পরিষ্কার করা হলো, দুটি স্ক্রিন বানানো হলো এবং `OmniApp.material` দিয়ে রান করা হলো:

```dart
import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  OmniRoute.usePathUrls(); // ওয়েবে '#' ছাড়া /home, /users/5 দেখাবে (মোবাইলে ক্ষতি নেই)
  runApp(const MyApp());
}

class HomeScreen extends OmniStatelessWidget {
  const HomeScreen({super.key});
  @override
  String get routePath => '/';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('হোম')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.push('/students/42?tab=marks'),
        child: const Text('ছাত্র #42 দেখুন'),
      ),
    ),
  );
}

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key, required this.id, this.tab});
  final int id;
  final String? tab;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('ছাত্র #$id')),
    body: Center(child: Text('ট্যাব: ${tab ?? "default"}')),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => OmniApp.material(
    title: 'আমার অ্যাপ',
    routes: [
      OmniPage.screen(const HomeScreen()),
      OmniPage('/students/:id', (p) => StudentScreen(
        id: p.pathInt('id'),
        tab: p.query('tab'),
      )),
    ],
  );
}
```

---

## ৩. Screen তৈরি — `OmniStatelessWidget`, `OmniStatefulWidget` ও `OmniState`

আপনি চাইলে ফ্লাটারের সাধারণ `StatelessWidget`/`StatefulWidget`-ও ব্যবহার করতে পারেন; তবে `OmniStatelessWidget` বা `OmniStatefulWidget` ব্যবহার করলে বাড়তি ৪টি সুবিধা পান:
1. স্ক্রিনের URL (`routePath`) ক্লাসের ভেতরেই থাকে।
2. পেজে ঢুকলে নিজস্ব Bloc অটো-তৈরি এবং বের হলে অটো-বন্ধ হয় (`provide`)।
3. `OmniScreen.hosted()` দিয়ে রুটের বাইরেও সহজে বসানো যায়।
4. `OmniState`-এ `onReady`, `onRouteChanged`, `readBloc`, `watchBloc`, `safeSetState` রেডি থাকে।

### ক. `OmniScreen`-এর প্রতিটি প্রোপার্টি ও শর্টকাট (দুটো স্ক্রিনেই পাওয়া যায়)

- **`routePath` (`String`, আবশ্যক):**
  - **কী কাজে লাগে:** এই স্ক্রিনের স্থায়ী URL ঠিকানা বলে দিতে (যেমন `'/login'`, `'/students/:id'`)।
  - **ভেতরে কীভাবে কাজ করে:** `OmniPage.screen(const MyScreen())` লিখলে এখান থেকেই পাথ নেয়, ফলে বারবার একই পাথ লিখতে হয় না। এছাড়া লগ ও `OmniRoute.to<MyScreen>()` এই পাথ ব্যবহার করে।
  - **উদাহরণ (স্ক্রিনের ভেতর পাথ ও নাম ঘোষণা করা হচ্ছে):**
    ```dart
    class ProfileScreen extends OmniStatelessWidget {
      const ProfileScreen({super.key});
      @override
      String get routePath => '/profile';
    ```

- **`title` (`String`, ঐচ্ছিক):**
  - **কী কাজে লাগে:** ওয়েবে ব্রাউজার ট্যাব এবং Android-এ Recent Apps কার্ডের নাম দেখাতে।
  - **ভেতরে কীভাবে কাজ করে:** না লিখলে `routePath` থেকে নিজেই নাম বানায় (যেমন `'/user-profile'` → `'User Profile'`)।
  - **উদাহরণ (বাংলায় কাস্টম ট্যাব টাইটেল সেট করা হচ্ছে):**
    ```dart
      @override
      String get title => 'আমার প্রোফাইল';
    ```

- **`provide` (`List<Provide>`, ঐচ্ছিক):**
  - **কী কাজে লাগে:** শুধু এই স্ক্রিনটি যতক্ষণ খোলা থাকবে, ততক্ষণ একটি Bloc/Cubit চালু রাখতে।
  - **ভেতরে কীভাবে কাজ করে:** স্ক্রিনে ঢোকার সময় `BlocProvider` তৈরি হয়, আর স্ক্রিন বন্ধ হলে নিজেই `bloc.close()` হয়ে মেমোরি খালি করে।
  - **উদাহরণ (পেজের ভেতর ঢোকার সাথে সাথে `ProfileBloc` তৈরি করা হচ্ছে):**
    ```dart
      @override
      List<Provide> get provide => [
        Provide.bloc((_) => ProfileBloc()..load()),
      ];
    ```

- **`metadata` (`OmniScreenMetadata`) ও `debugName` (`String`):**
  - **কী কাজে লাগে:** ডিবাগিং বা এনালিটিক্সের সময় স্ক্রিনের ক্লাস নাম, `routePath` ও `title` পড়তে।

- **স্ক্রিন থেকে সরাসরি নেভিগেশন (`resolvePath`, `go`, `push`, `open`, `replace` ও `hosted`):**
  - **কী কাজে লাগে:** হাতে স্ট্রিং না লিখে সরাসরি স্ক্রিন অবজেক্ট থেকে অন্য পেজে যেতে বা রুটের বাইরে উইজেট হিসেবে দেখাতে।
  - **উদাহরণ (স্ক্রিন অবজেক্ট থেকেই `/students/10?tab=fees`-এ যাওয়া ও রুটের বাইরে `.hosted()` করা):**
    ```dart
    // অন্য স্ক্রিনে push করা
    const StudentDetailScreen().push(context, path: {'id': 10}, query: {'tab': 'fees'});

    // আরেকটি পেজের ভেতর ড্যাশবোর্ডের অংশ হিসেবে এম্বেড করা (তার নিজস্ব Bloc-সহ)
    const MiniStatsCard().hosted();
    ```

### খ. `OmniState<T>` (কেবল `OmniStatefulWidget`-এর State-এ পাওয়া যায়)

| ফিচার | কী কাজে লাগে ও কীভাবে কাজ করে | ব্যবহার উদাহরণ |
|---|---|---|
| `onReady(context)` | স্ক্রিনের প্রথম ফ্রেম আঁকা শেষ হওয়ার পর **একবার** চলে। শুরুতে ডায়ালগ বা অ্যানিমেশন চালানোর জন্য নিরাপদ। | `@override void onReady(context) => showWelcomeTip();` |
| `onRouteChanged(prev, cur)` | পেজ নতুন করে না তৈরি হয়ে শুধু URL/Query বদলালে (যেমন `?tab=1` → `?tab=2`) ফায়ার হয়। | `@override void onRouteChanged(old, next) => reloadTab();` |
| `safeSetState(() {...})` | Async API শেষে স্ক্রিন ততক্ষণে বন্ধ হয়ে গেলেও `mounted` চেক করে ক্র্যাশ এড়ায়। | `safeSetState(() => loading = false);` |
| `readBloc<B>()` / `watchBloc<B>()` | `context.read<B>()` ও `context.watch<B>()`-এর সংক্ষিপ্ত রূপ। | `final user = watchBloc<UserCubit>().state;` |
| `params` / `maybeParams` | বর্তমান রুটের ID বা Query পড়া (`initState`-এও ক্র্যাশ করে না)। | `final id = params.pathInt('id');` |
| `routeState` / `maybeRouteState` | পুরো `Uri`, `extra`, `metadata` ও রুট প্যারামিটার দেখা। | `final from = routeState.queryParameters['from'];` |
| `go`, `push`, `replace`, `open`, `to`, `pushTo`, `replaceTo`, `openTo`, `pop` | `context.` না লিখেই সরাসরি স্টেট থেকে নেভিগেশন। | `replaceTo<HomeScreen>();` |

---

## ৪. রুট ও পেজ সাজানো — `OmniPage` (প্রতিটি প্যারামিটারসহ)

`OmniApp`-এর `routes:` তালিকায় প্রতিটি স্ক্রিন বা URL বসাতে `OmniPage` ব্যবহার হয়। এর দুই রকম কনস্ট্রাক্টর আছে:
1. **`OmniPage(path, (p) => ...)`**: যখন URL থেকে ID বা Query পড়ে উইজেট বানাবেন (যেকোনো সাধারণ `Widget`-ও হতে পারে)।
2. **`OmniPage.screen(const MyScreen())`**: যখন স্ক্রিনটি `OmniScreen` হয় এবং তার নিজের `routePath` থেকেই অটো-সেট করতে চান।

### `OmniPage`-এর প্রতিটি প্যারামিটার:

#### ১. `path` (`String`)
- **কী কাজে লাগে:** এই পেজ কোন URL পাথে খুলবে তা নির্ধারণ করতে (`'/'`, `'/login'`, চাইল্ড হলে `':id'`, বা সব পাথ ধরতে `'*rest'`)।
- **উদাহরণ (মূল `/users`-এর ভেতর চাইল্ড `:id` রুট বানানো, যা মিলে `/users/:id` হবে):**
  ```dart
  OmniPage('/users', (_) => const UsersScreen(), routes: [
    OmniPage(':id', (p) => UserDetailScreen(id: p.pathInt('id'))),
  ])
  ```

#### ২. `screenBuilder` (`S Function(OmniParams p)`) বা `OmniPage.screen(S screen)`
- **কী কাজে লাগে:** ম্যাচ হওয়া URL-এর প্যারামিটার (`p`) দিয়ে স্ক্রিন তৈরি করতে। ভুল প্যারামিটার (যেমন সংখ্যার বদলে অক্ষর) হলে ক্র্যাশ না হয়ে `notFound` এরর পেজ দেখায়।
- **উদাহরণ (URL থেকে `id` এবং `tab` নিয়ে স্ক্রিন তৈরি):**
  ```dart
  OmniPage<OrderScreen>(
    '/orders/:id',
    (p) => OrderScreen(orderId: p.pathInt('id'), tab: p.query('tab')),
  )
  ```

#### ৩. `name` (`String? = null`)
- **কী কাজে লাগে:** রুটের একটা স্থায়ী ডাকনাম রাখতে, যেন পরে বড় URL বদলালেও নাম ধরে (`pushNamed('invoice')`) কল করা যায়।
- **উদাহরণ (রুটটির নাম `'invoice'` রাখা হলো):**
  ```dart
  OmniPage('/billing/orders/:id/invoice', (p) => const InvoiceScreen(), name: 'invoice')
  ```

#### ৪. `title` (`String? = null`)
- **কী কাজে লাগে:** সাধারণ `Widget` (যেখানে `OmniScreen.title` নেই) অথবা কোনো পেজের ব্রাউজার ট্যাব/টাস্ক-সুইচার শিরোনাম বদলাতে।
- **উদাহরণ (ট্যাবের নাম `'চেকআউট'` সেট করা হচ্ছে):**
  ```dart
  OmniPage('/checkout', (_) => const CheckoutView(), title: 'চেকআউট')
  ```

#### ৫. `transition` (`OmniPageType? = null`)
- **কী কাজে লাগে:** পুরো অ্যাপের ডিফল্ট অ্যানিমেশন থেকে বেরিয়ে শুধু এই পেজটিকে ভিন্নভাবে (যেমন ডায়ালগ, বটমশিট, বা নিচ থেকে স্লাইড) দেখাতে।
- **উদাহরণ (`/filters` পেজটি Bottom Sheet হিসেবে খুলবে):**
  ```dart
  OmniPage(
    '/filters',
    (_) => const FilterSheet(),
    transition: OmniPages.bottomSheet(showDragHandle: true, isScrollControlled: true),
  )
  ```

#### ৬. `guards` (`List<OmniGuard> = const []`)
- **কী কাজে লাগে:** কেবল এই নির্দিষ্ট রুটে (এবং এর চাইল্ড রুটগুলোতে) ঢোকার আগে বিশেষ শর্ত (যেমন অ্যাডমিন চেক) যাচাই করতে।
- **উদাহরণ (শুধু `/admin` রুটে এলে অ্যাডমিন গার্ড চেক হবে):**
  ```dart
  OmniPage('/admin', (_) => const AdminPanel(), guards: const [AdminGuard()])
  ```

#### ৭. `blocs` ও `provide` (`List<OmniBlocEntry> = const []`)
- **কী কাজে লাগে:** সাধারণ `Widget` বা `OmniScreen`-কে পেজ-স্কোপড Bloc দিতে (পেজে এলে তৈরি হবে, বের হলে অটো `close()` হবে)। দুটি প্যারামিটারই একসাথে মার্জ হয়ে কাজ করে।
- **উদাহরণ (সাধারণ `StatelessWidget` পেজের সাথে `CartBloc` জুড়ে দেওয়া):**
  ```dart
  OmniPage(
    '/cart',
    (_) => const CartPage(),
    blocs: [OmniBloc((c) => CartBloc(c.read<ApiClient>()))],
  )
  ```

#### ৮. `onExit` (`FutureOr<bool> Function(BuildContext context)? = null`)
- **কী কাজে লাগে:** ফর্মে না-সেভ করা তথ্য থাকলে Back বাটনে বের হওয়ার আগে ইউজারকে জিজ্ঞেস করতে। `true` দিলে বের হবে, `false` দিলে পেজে থেকে যাবে।
- **উদাহরণ (এডিট পেজ থেকে বের হওয়ার আগে কনফার্মেশন নেওয়া):**
  ```dart
  OmniPage(
    '/profile/edit',
    (_) => const EditProfilePage(),
    onExit: (ctx) => showUnsavedConfirmDialog(ctx),
  )
  ```

#### ৯. `routes` (`List<OmniRouteBase> = const []`)
- **কী কাজে লাগে:** প্যারেন্ট রুটের নিচে চাইল্ড রুট বসাতে। চাইল্ড রুটে গেলে প্যারেন্ট রুট নিচে থাকে, তাই Back করলে প্যারেন্টে ফেরা যায়।
- **উদাহরণ:** উপরে ১ নং উদাহরণে `routes` ব্যবহার দেখুন।

#### ১০. `metadata` (`Map<String, dynamic>? = null`)
- **কী কাজে লাগে:** রুটের সাথে অতিরিক্ত কোনো তথ্য (যেমন `{'role': 'editor', 'hideNav': true}`) যুক্ত রাখতে, যা পরে গার্ড বা এনালিটিক্সে পড়া যায়।
- **উদাহরণ (রোল মেটাডাটা যোগ করা হচ্ছে):**
  ```dart
  OmniPage('/reports', (_) => const ReportScreen(), metadata: const {'role': 'manager'})
  ```

#### ১১. `parentNavigatorKey` (`GlobalKey<NavigatorState>? = null`)
- **কী কাজে লাগে:** ট্যাবের ভেতর থেকে কোনো পেজ খুললেও সেটিকে ট্যাবের Bottom Nav Bar ঢেকে পুরো স্ক্রিনের উপরে দেখাতে।
- **উদাহরণ (রুট নেভিগেটরের উপরে ফুল-স্ক্রিন প্লেয়ার খোলা হচ্ছে):**
  ```dart
  OmniPage('/video', (_) => const VideoPlayer(), parentNavigatorKey: rootNavKey)
  ```

---

## ৫. এক পেজ থেকে অন্য পেজে যাওয়া — Navigation ও Back নিয়ন্ত্রণ

এটি সবথেকে গুরুত্বপূর্ণ অংশ। কাজের ধরন অনুযায়ী সঠিক মেথড বেছে নিন:

### ক. কোন মেথড কখন ব্যবহার করবেন? (`go` বনাম `push` বনাম `replace` বনাম `open`)

| আপনি কী চান? | কোন মেথড ডাকবেন? | মোবাইল Back কেমন কাজ করবে? | ওয়েব ব্রাউজার Back কেমন কাজ করবে? |
|---|---|---|---|
| **এক ধাপ সামনে যাওয়া** (ফিরতে পারবে) | `push('/details')` বা `pushTo<DetailScreen>()` | আগের পেজে ফিরে আসবে | আগের URL-এ ফিরে আসবে |
| **আগের স্ক্রিন চিরতরে বাদ দিয়ে যাওয়া** (যেমন **Login → Home**) | `replace('/home')` বা `replaceTo<HomeScreen>()` | **ফেরা যাবে না** (টপ পেজ পাল্টে গেছে) | **ফেরা যাবে না** (`replaceState` করে দেয়) |
| **পুরো স্ট্যাক পরিষ্কার করে যাওয়া** (যদি আরও ২-৩ পেজ নিচে থাকে) | `go('/home', replaceHistory: true)` অথবা `OmniRoute.neglect(() => ...)` | **ফেরা যাবে না** (সব পুরনো পেজ মুছে গেছে) | **ফেরা যাবে না** (`replaceState` করে দেয়) |
| **নরমাল ওয়েব পেজ সুইচ** (সাইড মেনু/ড্যাশবোর্ড লিংক) | `go('/students')` বা `to<StudentsScreen>()` | ফ্লাটার স্ট্যাক নতুন রুট থেকে শুরু হয় | ওয়েব ব্রাউজারের Back দিয়ে আগের পেজে ফেরা যায় |
| **একই পেজ বারবার স্ট্যাকে জমতে না দেওয়া** | `open('/settings')` বা `openTo<SettingsScreen>()` | আগেই খোলা থাকলে সেখানেই ফিরে যায়, ডুপ্লিকেট হয় না | অপ্রয়োজনীয় ডুপ্লিকেট হিস্ট্রি ছাড়া পরিচ্ছন্ন থাকে |
| **বন্ধ করে আগের পেজে ফেরা** | `pop([result])` / `maybePop([result])` | ১ ধাপ পেছনে যায় (রেজাল্ট ফেরত দিয়ে) | পপ করা পেজ হিস্ট্রি থেকে রিপ্লেস করে সরায় |
| **একাধিক পেজ একবারে বন্ধ করা** | `popUntil('/home')` বা `popToRoot()` | নির্দিষ্ট পেজ বা ট্যাবের শুরুতে ফিরে আসে | অপ্রয়োজনীয় পপ-করা URL হিস্ট্রিতে রেখে দেয় না |

> **বিশেষ টিপস — Login থেকে Home-এ যাওয়ার সেরা ৩ উপায় (যাতে Back না করা যায়):**
> 1. **গার্ড দিয়ে (`AuthGuard`):** লগইন শেষে শুধু `auth.logIn(); OmniRoute.refresh();` কল করুন — গার্ড নিজেই `/login` হিস্ট্রি রিপ্লেস করে `/dashboard`-এ পাঠাবে এবং পরে URL লিখে বা Back চেপেও `/login`-এ ঢোকা যাবে না।
> 2. **সরাসরি রিপ্লেস (`replace`):** `context.replace('/home');` বা `context.replaceTo<HomeScreen>();`
> 3. **গভীর স্ট্যাকসহ রিপ্লেস (`go`):** যদি `/welcome` → `/login` → `/otp` হয়ে আসেন, তবে শেষে `context.go('/home', replaceHistory: true);` কল করুন—সব পুরনো পেজ ও ওয়েব হিস্ট্রি একসাথে সরে যাবে।

### খ. নেভিগেশন মেথডের প্রতিটি প্যারামিটার

- **`location` / `routePath` / `name` (`String`)**: গন্তব্য পাথ (`'/students/5'`), প্যাটার্ন (`'/students/:id'`), বা রুটের `name` (`'invoice'`)।
- **`path` (`Map<String, Object?>`)**: URL-এর `:id`-এর মতো অংশে মান বসাতে (যেমন `path: {'id': 5}`)।
- **`query` (`Map<String, Object?>`)**: `?tab=info&sort=asc` ইত্যাদি যুক্ত করতে (`null` মান আপনা থেকেই বাদ যায়)।
- **`extra` (`Object?`)**: পুরো Dart অবজেক্ট (যেমন `User`) পাস করতে। *(নোট: ওয়েব রিফ্রেশে `extra` থাকে না, তাই গুরুত্বপূর্ণ ID সবসময় `path` বা `query`-তে দিন।)*
- **`maxDepth` (`int = 10`, কেবল `open` মেথডে)**: স্ট্যাকে কতগুলো পেজ জমলে নতুন `push` না করে `go` দিয়ে রিসেট করবে তা ঠিক করে।
- **`animated` (`bool = true`)**: `false` দিলে কোনো ট্রানজিশন ছাড়াই সাথে সাথে স্ক্রিন দেখাবে।
- **`transition` (`OmniPageType?`)**: শুধু এই একবারের যাওয়ার জন্য ভিন্ন অ্যানিমেশন (যেমন `OmniPages.slideUp`) ব্যবহার করবে।
- **`replaceHistory` (`bool = false`, কেবল `go`/`to`/`goNamed`/`goPath`-এ)**: `true` দিলে ওয়েবে নতুন Back এন্ট্রি যোগ না করে বর্তমান URL রিপ্লেস করবে।

**এক নজরে উদাহরণ:**
```dart
// ১. গ্লোবাল (BuildContext ছাড়াই Bloc বা সার্ভিস থেকে)
OmniRoute.to<DetailScreen>(path: {'id': 42}, query: {'tab': 'notes'});

// ২. পেজের ভেতর থেকে Login -> Home (কোনোভাবেই Back করা যাবে না)
context.replaceTo<HomeScreen>();
// অথবা: context.go('/home', replaceHistory: true);

// ৩. অ্যানিমেশন ছাড়া ও ডুপ্লিকেট ছাড়া ওপেন
await context.open('/notifications', animated: false, maxDepth: 5);

// ৪. রেজাল্টসহ ডায়ালগ থেকে ফেরা
final ok = await context.push<bool>('/confirm-logout');
```

### গ. বর্তমান রুট ও স্ট্যাক দেখার প্রোপার্টি

- **`OmniRoute.current`**: এখন স্ক্রিনের একদম উপরে যে পেজ আছে তার তথ্য (`location`, `routePath`, `name`, `screen`, `metadata`)।
- **`OmniRoute.currentListenable`**: রুট বদলালেই অটো-আপডেট হওয়া `ValueListenable` (UI-তে ব্রেডক্রাম্ব বা ব্যানার দেখাতে)।
- **`OmniRoute.stack`**: নিচ থেকে উপর পর্যন্ত অ্যাক্টিভ সব পেজের তালিকা।
- **`OmniRoute.paths`**: রেজিস্ট্রার হওয়া সব রুট পাথের তালিকা।
- **`OmniRoute.hasRoute('/users/5')`**: এই URL বৈধ রুট কি না (`true`/`false`) যাচাই করে।
- **`OmniRoute.locationFor` / `locationNamed` / `locationOf<S>`**: নেভিগেশন না করেই কেবল ফরম্যাট করা URL স্ট্রিং দেয়।

---

## ৬. URL থেকে ID ও তথ্য পড়া — `OmniParams` ও `OmniRouteState`

URL-এর `/users/7?age=25&rate=4.5&active=true&sort=newest&tag=a&tag=b` থেকে প্রতিটি অংশ টাইপ-সেফভাবে পড়তে `OmniParams` ব্যবহার হয়। কোনো মান ভুল ফরম্যাটে থাকলে অ্যাপ ক্র্যাশ না করে `notFound` এরর পেজ দেখায়।

| প্যারামিটার/মেথড | কী দেয় ও কী কাজে লাগে | উপরের URL-এ উদাহরণ |
|---|---|---|
| `OmniParams.of(context)` / `context.params` | বর্তমান পেজের `OmniParams` দেয় (`initState`-এও নিরাপদ)। | `final p = context.params;` |
| `p.path('id')` | `:id`-এর মান `String` হিসেবে দেয়। | `'7'` |
| `p.pathInt('id')` | `:id`-কে পূর্ণসংখ্যা `int` বানিয়ে দেয়। | `7` |
| `p.query('q')` | ঐচ্ছিক query `String?` দেয় (না থাকলে `null`)। | `null` |
| `p.queryInt('age')` | ঐচ্ছিক query `int?` দেয়। | `25` |
| `p.queryDouble('rate')` | ঐচ্ছিক দশমিক সংখ্যা `double?` দেয়। | `4.5` |
| `p.queryBool('active')` | `'true'`/`'1'`/`'false'`/`'0'` থেকে `bool?` দেয়। | `true` |
| `p.queryEnum('sort', Sort.values)` | সরাসরি Dart `enum` ভ্যালুতে রূপান্তর করে। | `Sort.newest` |
| `p.queryAll('tag')` | একই query কী একাধিকবার এলে পুরো তালিকা দেয়। | `['a', 'b']` |
| `p.extra<User>()` | `push(..., extra: user)` দিয়ে পাঠানো অবজেক্ট নেয়। | `User` অবজেক্ট |
| `p.uri` / `context.routeState` | সম্পূর্ণ `Uri`, `matchedLocation`, `metadata`, `pageKey`, `error` পড়া। | `routeState.metadata` |

---

## ৭. `OmniApp` — অ্যাপের সব প্যারামিটার ও প্রতিটির ব্যবহার

আপনি অ্যাপ বানাতে **`OmniApp.material(...)`** (Android/Web/Material ডিজাইন), **`OmniApp.cupertino(...)`** (iOS ডিজাইন), অথবা কাস্টম **`OmniApp(..., builder:)`** ব্যবহার করবেন — এবং প্রতিটির সাথেই সরাসরি **`config: OmniConfig(...)`** বসাতে পারবেন।

### ক. সহজ এন্ট্রি-ফ্লো কনফিগ: `OmniConfig` (Splash, Onboarding, Auth ও Public রুট)

**`OmniConfig`**-এর ভেতর সবকিছু ৪টি পরিষ্কার অংশে সাজানো, যাতে ডেভেলপার একদম নিজস্ব স্ক্রিন বসিয়ে পুরো এন্ট্রি-ফ্লো সহজে কন্ট্রোল করতে পারেন:

1. **`splash: OmniSplash(...)`** — সরাসরি `screen: const MySplash()` অথবা `builder: (ctx) => ...`, সাথে `onInit`, `minDuration`, `timeout`, `manualFinish` (`context.flow?.finishSplash()`), `onError`।
2. **`onboarding: OmniOnboarding(...)`** — যতগুলো খুশি নিজের তৈরি অনবোর্ডিং স্ক্রিন দিন:
   - **একাধিক স্ক্রিন উইজেট:** `screens: const [Step1(), Step2(), Step3()]` (নিজেই সোয়াইপ ও `nextOnboarding()` / `previousOnboarding()` / `goToOnboardingStep()` কাজ করবে — সাথে চাইলে সব স্ক্রিনের উপর শেয়ার্ড `overlayBuilder` দিন!)
   - **বিল্ডার তালিকা / একক বিল্ডার:** `screenBuilders: [...]` অথবা `builder: (ctx, flow) => ...`
   - **রুট তালিকা:** `route: '/onboarding'` বা `routes: ['/ob-1', '/ob-2']` (লগইন ছাড়াই স্বয়ংক্রিয়ভাবে চলবে)
   - **বিল্ট-ইন লোকাল ডাটাবেজ ও অটো-সেভ মোড (`OmniOnboardingMode`, কোনো ম্যানুয়াল কোড ছাড়াই):**
     - `mode: OmniOnboardingMode.onceUntilLoginScreen` *(ডিফল্ট)* — প্রথমবার ইনস্টল/ওপেন করলে অনবোর্ডিং দেখাবে; একবার **Login স্ক্রিনে ঢুকলেই** (বা অনবোর্ডিং শেষ/স্কিপ করলে) অটো লোকাল ডাটাবেজে সেভ হয়ে যাবে। এরপর অ্যাপ ব্যাকগ্রাউন্ড থেকে ক্লিয়ার করে আবার খুললেও আর অনবোর্ডিং দেখাবে না।
     - `mode: OmniOnboardingMode.untilLoggedIn` — ইউজার যতক্ষণ **সফলভাবে লগইন (`isAuthenticated == true`) না করছে** ততক্ষণ অ্যাপ ব্যাকগ্রাউন্ড থেকে ক্লিয়ার করে পুনরায় খুললেও অনবোর্ডিং দেখাবে; একবার লগইন সম্পন্ন হয়ে গেলেই লোকাল ডাটাবেজে সেভ হবে, পরে আর দেখাবে না।
     - `mode: OmniOnboardingMode.onceAfterComplete` — শুধু অনবোর্ডিং সম্পন্ন/স্কিপ করলেই সেভ হয়।
     - `mode: OmniOnboardingMode.always` — প্রতিবার অ্যাপ খুললেই দেখাবে।
     - `enabled: false` (বা `mode: OmniOnboardingMode.disabled`) — পুরো অনবোর্ডিং বন্ধ রাখতে। আর `persist: false` দিলে লোকাল ডাটাবেজে সেভ বন্ধ থাকবে।
     - `storageKey` / `storage` — চাইলে ভার্সন (`'v2'`) বদলাতে বা কাস্টম লোকাল স্টোর (`OmniLocalStore`) দিতে পারবেন।
   - **কন্ট্রোল ও কলব্যাক:** `shouldShow`, `alwaysShow`, `swipeable`, `onStepChanged`, `onDone`, `onSkip`, `afterDone`।
3. **`auth: OmniAuthConfig(...)`** — সরাসরি `loginScreen: const LoginScreen()` (বা `loginBuilder`), `signupScreen: const SignupScreen()` (বা `signupBuilder`), `homeRoute`, `isAuthenticated`, `refreshStream` / `refreshListenable`, `afterLogin`, `afterLogout`, `onUnauthenticated`, `blockAuthWhenLoggedIn` (লগইনের পর Web Back/URL দিয়ে Login/Signup-এ ফেরা আটকায়), `preserveRedirectQuery` (`?from=`)।
4. **লগইন ছাড়া ভিজিটযোগ্য পাবলিক স্ক্রিন:**
   - **`publicScreens: {'/about': const AboutScreen(), '/terms': const TermsScreen()}`** — একদম সরাসরি রুট ও স্ক্রিন ম্যাপে দিয়ে দিন (আলাদা `routes:`-এ লেখা বা গার্ড কনফিগ করার দরকার নেই)।
   - **`publicPages`** — প্যারামিটারসহ (`/article/:id`) বা `provide:` যুক্ত পাবলিক `OmniPage`।
   - **`publicRoutes`** — মূল `routes:`-এ থাকা পাবলিক প্যাটার্ন (`'/docs/*'`).
5. **যেকোনো স্ক্রিন থেকে রানটাইম কন্ট্রোল (`context.flow`):** `finishSplash()`, `nextOnboarding({redirectTo})`, `previousOnboarding()`, `goToOnboardingStep(i)`, `completeOnboarding({redirectTo})`, `skipOnboarding({redirectTo})`, `replayOnboarding()`, `resetOnboarding({replay})`, `restartStartup()`, `goToLogin()`, `goToSignup()`, `goToHome()`, `goToPublic('/about')`, `pushPublic('/terms')`, `logout(...)`, `refresh()`।

**উদাহরণ (নিজস্ব Splash, ৩টি Onboarding স্ক্রিন, অটো লোকাল DB, Login/Signup ও Public ভিজিট স্ক্রিন একসাথে):**
```dart
OmniApp.material(
  title: 'আমার অ্যাপ',
  config: OmniConfig(
    // ১. কাস্টম Splash
    splash: OmniSplash(
      screen: const MySplashScreen(),
      minDuration: const Duration(milliseconds: 600),
      onInit: (c) => c.read<SessionRepo>().restore(),
    ),

    // ২. যতগুলো খুশি নিজের তৈরি Onboarding স্ক্রিন (অটো লোকাল ডাটাবেজসহ)
    onboarding: OmniOnboarding(
      // onceUntilLoginScreen (ডিফল্ট): Login স্ক্রিনে ঢুকলেই অটো সেভ (আর দেখাবে না)
      // untilLoggedIn: সফল লগইন না করা পর্যন্ত প্রতিটি লঞ্চে দেখাবে
      // enabled: false দিলে পুরোপুরি বন্ধ থাকবে
      mode: OmniOnboardingMode.onceUntilLoginScreen,
      screens: const [
        WelcomeStepScreen(),
        FeatureStepScreen(),
        ReadyStepScreen(),
      ],
      // ঐচ্ছিক শেয়ার্ড ডট/স্কিপ বার:
      overlayBuilder: (context, flow, child) => Scaffold(
        body: Column(
          children: [
            Expanded(child: child),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: flow.skipOnboarding, child: const Text('Skip')),
                Text('${flow.onboardingStep + 1} / ${flow.onboardingCount}'),
                ElevatedButton(
                  onPressed: flow.nextOnboarding, // শেষ স্ক্রিনে অটো complete!
                  child: Text(flow.isLastOnboardingStep ? 'Start' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),

    // ৩. Login, Signup ও Home কন্ট্রোল
    auth: OmniAuthConfig(
      isAuthenticated: (c) => c.read<AuthBloc>().state.isLoggedIn,
      refreshStream: (c) => c.read<AuthBloc>().stream,
      homeRoute: '/home',
      loginScreen: const MyLoginScreen(),
      signupScreen: const MySignupScreen(),
      afterLogout: (_) => '/login',
    ),

    // ৪. লগইন ছাড়াই ভিজিট করা যাবে এমন পাবলিক স্ক্রিন
    publicScreens: const {
      '/about': AboutScreen(),
      '/terms': TermsScreen(),
      '/privacy': PrivacyScreen(),
    },
    publicPages: [
      OmniPage('/article/:id', (p) => ArticleScreen(id: p.path('id'))),
    ],
  ),
  routes: [
    OmniPage('/home', (_) => const HomeScreen()),
  ],
)
```
> Cupertino (`OmniApp.cupertino`) বা কাস্টম `OmniApp(..., builder:)`-এও একইভাবে সরাসরি `config: OmniConfig(...)` বসানো যায়।

---

### ৭.১ রুট, সার্ভিস, গার্ড ও বেসিক সেটআপ

#### ১. `routes` (`List<OmniRouteBase>`, আবশ্যক)
- **কী কাজে লাগে:** অ্যাপের সব পেজ, ট্যাব এবং শেল যুক্ত করতে।
- **ভেতরে কীভাবে কাজ করে:** অ্যাপ চালুর সাথে সাথে সব পাথ যাচাই করে একটা দ্রুত Segment Trie বানায় (ভুল বা ডুপ্লিকেট পাথ থাকলে আগেই ধরে ফেলে)।
- **ব্যবহার (সব পেজ এক তালিকায় দেওয়া হচ্ছে):**
  ```dart
  OmniApp.material(
    routes: [
      OmniPage('/', (_) => const HomeScreen()),
      OmniPage('/details', (_) => const DetailScreen()),
    ],
  )
  ```

#### ২. `builder` (`Widget Function(BuildContext, OmniRouter)`, কেবল মূল `OmniApp`-এ আবশ্যক)
- **কী কাজে লাগে:** যখন নিজে হাতে `MaterialApp.router`, `CupertinoApp.router` বা তৃতীয় কোনো রুট উইজেট তৈরি করবেন।
- **ব্যবহার (`OmniApp`-এ নিজস্ব `MaterialApp.router` বসানো):**
  ```dart
  OmniApp(
    routes: routes,
    builder: (context, router) => MaterialApp.router(routerConfig: router),
  )
  ```

#### ৩. `repositories` (`List<OmniRepoEntry> = const []`)
- **কী কাজে লাগে:** API ক্লায়েন্ট (`OmniNetwork`), ডাটাবেস বা Auth সার্ভিস পুরো অ্যাপে শেয়ার করতে।
- **ভেতরে কীভাবে কাজ করে:** গ্লোবাল Bloc-গুলোরও **উপরে** মাউন্ট হয়, যাতে যেকোনো Bloc তৈরিতেই `context.read<MyRepo>()` পাওয়া যায়।
- **ব্যবহার (`AuthRepo` বানিয়ে অ্যাপ বন্ধে অটো `dispose` করা হচ্ছে):**
  ```dart
  OmniApp.material(
    repositories: [OmniRepo((_) => AuthRepo(), dispose: (r) => r.close())],
    routes: routes,
  )
  ```

#### ৪. `blocs` (`List<OmniBlocEntry> = const []`)
- **কী কাজে লাগে:** পুরো অ্যাপ-জুড়ে চলা গ্লোবাল Bloc (`global: true`), অথবা পেজের জন্য শেয়ার্ড Bloc ফ্যাক্টরি রাখতে।
- **ভেতরে কীভাবে কাজ করে:** `global: true` দিলে অ্যাপের শুরুতে তৈরি হয়ে আজীবন চলে; `global: false` দিলে শুধু ফ্যাক্টরি হিসেবে থাকে।
- **ব্যবহার (পুরো অ্যাপের জন্য একটি গ্লোবাল `AuthBloc` রাখা হচ্ছে):**
  ```dart
  OmniApp.material(
    blocs: [OmniBloc((c) => AuthBloc(c.read<AuthRepo>()), global: true)],
    routes: routes,
  )
  ```

#### ৫. `initialRoute` (`String = '/'`)
- **কী কাজে লাগে:** অ্যাপ প্রথম খুললে কোন পেজ দেখাবে তা ঠিক করতে (যদি বাইরে থেকে কোনো ডিপ লিংক বা URL না আসে)।
- **ব্যবহার (`/`-এর বদলে সরাসরি `/dashboard` দিয়ে অ্যাপ শুরু):**
  ```dart
  OmniApp.material(initialRoute: '/dashboard', routes: routes)
  ```

#### ৬. `resolveInitialRoute` (`FutureOr<String?> Function(BuildContext)? = null`)
- **কী কাজে লাগে:** `onInit`-এ ডেটা লোড হওয়ার পর সিদ্ধান্ত নিতে যে অ্যাপ প্রথমে `/onboarding`, `/login` নাকি `/dashboard`-এ খুলবে।
- **ভেতরে কীভাবে কাজ করে:** প্রথম স্ক্রিন আঁকার আগেই `splash` চলাকালীন রান হয় এবং ওয়েবে আগের এন্ট্রি রিপ্লেস করে।
- **ব্যবহার (অনবোর্ডিং শেষ হয়েছে কি না দেখে প্রথম রুট ঠিক করা হচ্ছে):**
  ```dart
  OmniApp.material(
    splash: (_) => const SplashView(),
    resolveInitialRoute: (ctx) async =>
        await ctx.read<AuthRepo>().isFirstRun ? '/onboarding' : '/dashboard',
    routes: routes,
  )
  ```

#### ৭. `transition` (`OmniPageType`)
- **কী কাজে লাগে:** পুরো অ্যাপের সব পেজের ডিফল্ট ওপেনিং-ক্লোজিং অ্যানিমেশন ঠিক করতে (ডিফল্ট `OmniPages.material` / `.cupertino`)।
- **ব্যবহার (প্ল্যাটফর্ম অনুযায়ী `adaptive` অ্যানিমেশন ব্যবহার):**
  ```dart
  OmniApp.material(transition: OmniPages.adaptive, routes: routes)
  ```

#### ৮. `guards` (`List<OmniGuard> = const []`)
- **কী কাজে লাগে:** সব রুটে ঢোকার আগে লগইন, মেইনটেন্যান্স বা অনুমতি যাচাই করতে।
- **ব্যবহার (পুরো অ্যাপে `AuthGuard` যুক্ত করা):**
  ```dart
  OmniApp.material(guards: const [AuthGuard()], routes: routes)
  ```

#### ৯. `refreshListenable` (`Listenable? = null`)
- **কী কাজে লাগে:** Bloc ছাড়া কোনো `ChangeNotifier`/`ValueNotifier` বদলালে গার্ডগুলো আবার চালিয়ে অটো-রিডাইরেক্ট করতে।
- **ব্যবহার (`authNotifier` বদলালেই গার্ড চেক হবে):**
  ```dart
  OmniApp.material(
    refreshListenable: authNotifier,
    guards: [OmniGuard.fn((_, __) => authNotifier.value ? null : '/login')],
    routes: routes,
  )
  ```

#### ১০. `notFound` (`Widget Function(BuildContext, OmniRouteState, Object?)? = null`)
- **কী কাজে লাগে:** ভুল URL, ভুল প্যারামিটার বা গার্ড লুপে পড়লে নিজস্ব সুন্দর 404 এরর পেজ দেখাতে।
- **ব্যবহার (ভুল পাথ এলে হোমে ফেরার বাটনসহ কাস্টম 404 স্ক্রিন):**
  ```dart
  OmniApp.material(
    notFound: (ctx, st, err) => Scaffold(
      body: Center(child: Text('${st.uri} পাওয়া যায়নি')),
    ),
    routes: routes,
  )
  ```

#### ১১. `navigatorKey` (`GlobalKey<NavigatorState>? = null`) ও ১২. `observers` (`List<NavigatorObserver>? = null`)
- **কী কাজে লাগে:** `navigatorKey` লাগে রুট নেভিগেটরে ডায়ালগ বা ফুল-স্ক্রিন খুলতে (`parentNavigatorKey`); আর `observers` লাগে Firebase Analytics বা `RouteObserver` বসাতে।
- **ব্যবহার:**
  ```dart
  final rootKey = GlobalKey<NavigatorState>();
  OmniApp.material(
    navigatorKey: rootKey,
    observers: [RouteObserver<ModalRoute<void>>()],
    routes: routes,
  )
  ```

#### স্ট্যাটিক ভ্যালিডেশন: `OmniApp.validateRoutes(routes, {rootNavigatorKey})`
- **কী কাজে লাগে:** অ্যাপ চালানোর আগেই (বা টেস্টে) ডুপ্লিকেট/ভুল রুট পাথ ধরে ফেলতে এবং সব রুটের তালিকা পেতে।
- **ব্যবহার:** `final allPaths = OmniApp.validateRoutes(appRoutes);`

---

### ৭.২ স্টার্টআপ স্প্ল্যাশ, অনবোর্ডিং, অথ/পাবলিক কনফিগ ও এনালিটিক্স

| প্যারামিটার | কী কাজে লাগে ও কীভাবে কাজ করে | ব্যবহার উদাহরণ |
|---|---|---|
| `config` (`OmniConfig?`) | `OmniApp`, `OmniApp.material` ও `OmniApp.cupertino`-এ সরাসরি `OmniSplash`, `OmniOnboarding` (`screens:`, অটো লোকাল DB ও `OmniOnboardingMode`), `OmniAuthConfig` এবং `publicScreens`/`publicPages`/`publicRoutes` সেটআপ করে। | `config: OmniConfig(...)` |
| `context.flow` (`OmniFlowController?`) | যেকোনো স্ক্রিন থেকে `finishSplash()`, `nextOnboarding()`, `previousOnboarding()`, `goToOnboardingStep()`, `completeOnboarding()`, `skipOnboarding()`, `replayOnboarding()`, `resetOnboarding()`, `goToLogin()`, `goToSignup()`, `goToHome()`, `goToPublic()`, `pushPublic()`, `logout()`, `refresh()` চালায়। | `onPressed: () => context.flow?.logout()` |
| `OmniNative` | নেটিভ প্লাগিন হেল্পার: `getPlatformVersion()`, `getDeviceInfo()`, `hideKeyboard()`, `keepScreenOn(true)`, `clearNativeCache()` (Android/iOS/macOS/Linux/Windows/Web)। | `final info = await OmniNative.getDeviceInfo();` |
| `onInit` (`Future<void> Function(BuildContext)?`) | রুট দেখানোর আগে একবার async কাজ (যেমন সেভ করা টোকেন/কনফিগ পড়া) চালায় (`OmniSplash(onInit:)` বা সরাসরি `OmniApp`)। | `onInit: (c) => c.read<AppInit>().load()` |
| `initTimeout` (`Duration?`) | `onInit` অতিরিক্ত দেরি করলে নির্দিষ্ট সময় পর টাইমআউট এরর দেয়, স্প্ল্যাশ আটকে থাকে না। | `initTimeout: const Duration(seconds: 8)` |
| `splash` (`WidgetBuilder?`) | সম্পূর্ণ নিজের ডিজাইন করা কাস্টম স্প্ল্যাশ উইজেট দিতে। | `splash: (_) => const MySplashScreen()` |
| `onInitError` (`Widget Function(ctx, err, stack, retry)?`) | `onInit` বা অনবোর্ডিং ব্যর্থ/টাইমআউট হলে এরর UI ও `retry()` বাটন দেখায়। | `onInitError: (c, e, s, retry) => RetryPage(retry)` |
| `lifecycle` (`OmniLifecycle?`) | পুরো অ্যাপ ব্যাকগ্রাউন্ডে যাওয়া বা ফোরগ্রাউন্ডে ফেরার ইভেন্ট শোনে। | `lifecycle: AppLifecycleHandler()` |
| `onNavigate` (`void Function(OmniNavigation)?`) | প্রতিটি রুট পরিবর্তনে এনালিটিক্স বা ইনস্পেক্টর লগে ইভেন্ট পাঠায় (`kind`, `from`, `to`, `uri`, `timestamp`)। | `onNavigate: (n) => analytics.track(n.to.location)` |
| `logNavigation` (`bool = false`) | ডিবাগে কনসোলে সুন্দর বক্স আকারে `from → to` লগ ছাপে (রিলিজে বন্ধ)। | `logNavigation: true` |
| `blocObserver` (`BlocObserver?`) | সব Bloc-এর `onCreate`, `onChange`, `onError` এক জায়গায় ধরতে (অ্যাপ বন্ধে আগের অবজার্ভার ফিরে আসে)। | `blocObserver: MyBlocObserver()` |
| `onError` (`void Function(Object, StackTrace)?`) | ফ্লাটার বা ডার্টের আনকট ক্র্যাশ Crashlytics/Sentry-তে পাঠাতে। | `onError: (e, s) => crashlytics.record(e, s)` |
| `overlayBuilder` (`TransitionBuilder?`) | পুরো অ্যাপের উপরে ফ্লোটিং ইনস্পেক্টর বাটন বা গ্লোবাল ব্যানার বসাতে। | `overlayBuilder: (_, c) => OmniInspectorLauncher(...)` |

---

### ৭.৩ মোবাইল, ডেস্কটপ ও ওয়েব নিয়ন্ত্রণ

| প্যারামিটার (ডিফল্ট) | কী কাজে লাগে ও কীভাবে কাজ করে | ব্যবহার উদাহরণ |
|---|---|---|
| `setTitles` (`true`) | ব্রাউজার ট্যাব ও Recent Apps-এ বর্তমান পেজের `title` দেখায়। | `setTitles: true` |
| `titleColor` (`Color?`) | Android টাস্ক-সুইচারের হেডার বারের রঙ ঠিক করে। | `titleColor: Colors.indigo` |
| `swipeBack` (`OmniSwipeBack.none`) | কাস্টম ট্রানজিশন পেজেও আঙুল দিয়ে কিনারা টেনে পেজ বন্ধের জেসচার দেয়। | `swipeBack: OmniSwipeBack.zoomCard` |
| `swipeBackStyle` (`OmniSwipeBackStyle()`) | সোয়াইপের জুম, কর্নার রেডিয়াস, শ্যাডো ও দূরত্ব সূক্ষ্মভাবে নিয়ন্ত্রণ করে। | `swipeBackStyle: const OmniSwipeBackStyle.subtle()` |
| `predictiveBack` (`false`) | Android-এ সিস্টেম ব্যাক জেসচারের সাথে জুম প্রগ্রেস সিঙ্ক করে। | `predictiveBack: true` |
| `desktopBack` (`true`) | macOS/Windows/Linux-এ `Alt+Left`, `Cmd+[` ও মাউস ব্যাক বাটন সচল করে। | `desktopBack: true` |
| `escapeGoesBack` (`false`) | ডেস্কটপে `Esc` কী চাপলে ডায়ালগ না থাকলে আগের পেজে ফেরা। | `escapeGoesBack: true` |
| `restorationScopeId` (`String?`) | OS মেমোরি বাঁচাতে অ্যাপ কিল করলে ফিরে এসে আগের রুট ও ট্যাব রিস্টোর করা। | `restorationScopeId: 'app_nav'` |
| `dismissKeyboardOnTap` (`false`) | টেক্সট ফিল্ডের বাইরে ট্যাপ করলেই কিবোর্ড অটো নামিয়ে দেওয়া। | `dismissKeyboardOnTap: true` |
| `doubleBackToExit` (`Duration?`) | Android রুট পেজে নির্দিষ্ট সময়ের মধ্যে ২ বার ব্যাক চাপলে তবেই বের হওয়া। | `doubleBackToExit: const Duration(seconds: 2)` |
| `onExitWarning` (`void Function(BuildContext)?`) | প্রথমবার ব্যাক চাপলে "আবার চাপুন" স্ন্যাকবার দেখাতে। | `onExitWarning: (c) => showToast(c)` |
| `orientations` (`List<DeviceOrientation>?`) | পুরো অ্যাপ শুধু পোর্ট্রেট বা ল্যান্ডস্কেপে সীমিত রাখা। | `orientations: const [DeviceOrientation.portraitUp]` |
| `minTextScale` / `maxTextScale` (`double?`) | সিস্টেম ফন্ট অনেক বড়/ছোট হলেও ডিজাইন ভেঙে যাওয়া ঠেকানো। | `minTextScale: 0.85, maxTextScale: 1.3` |

---

### ৭.৪ `OmniApp.material` ও `OmniApp.cupertino`-এর অতিরিক্ত প্যারামিটার

- **`title`, `theme`, `darkTheme`, `highContrastTheme`, `highContrastDarkTheme`, `themeMode`, `color`**: ফ্লাটারের সাধারণ `MaterialApp`/`CupertinoApp`-এর মতোই কাজ করে।
- **`themeModeBuilder` (`ThemeMode? Function(BuildContext)?`)**: `ThemeCubit` থেকে সরাসরি `ThemeMode` বদলাতে (`themeModeBuilder: (c) => c.watch<ThemeCubit>().state`)।
- **`locale`, `localizationsDelegates`, `supportedLocales`**: বহুভাষী (`bn`, `en`) অ্যাপ বানাতে।
- **`debugShowCheckedModeBanner` (`true`)**: উপরের কোনায় DEBUG ফিতা লুকাতে `false` দিন।
- **`scaffoldMessengerKey`, `shortcuts`, `actions`, `scrollBehavior`**: গ্লোবাল `SnackBar`, কিবোর্ড শর্টকাট ও স্ক্রল ফিজিক্সের জন্য।
- **`appBuilder` (`TransitionBuilder?`)**: `MaterialApp.router(builder: ...)`-এর জায়গায় ইনস্পেক্টর লঞ্চার বা ওভারলে বসাতে।

---

## ৮. ডেটা ও Bloc ব্যবস্থাপনা — `OmniRepo`, `OmniBloc`, `Provide` ও `OmniRouteGroup`

সঠিক জায়গায় সঠিক ডেটা না রাখলে মেমোরি লিক হয় অথবা অপ্রয়োজনে স্টেট হারিয়ে যায়। সহজ নিয়ম হলো:

1. **সার্ভিস / API ক্লায়েন্ট (`OmniRepo`):** `OmniApp(repositories:)`-এ দিন।
   - `OmniRepo((c) => UserRepo(c.read<OmniNetwork>()), lazy: true, dispose: (r) => r.close())`
   - `OmniRepo.value(existingApi)` — আগে তৈরি করা অবজেক্ট ইনজেক্ট করতে (`OmniRoute` এটিকে `close`/`dispose` করে না)।
2. **গ্লোবাল Bloc (`OmniBloc(..., global: true)`):** `OmniApp(blocs:)`-এ দিন (যেমন `AuthBloc`, `ThemeBloc`) — অ্যাপ চলা পর্যন্ত থাকবে।
3. **শুধু এক পেজের Bloc (`Provide` বা `OmniPage(blocs:)`):**
   - `Provide.bloc((_) => DetailBloc())` — পেজে ঢুকলে তৈরি হবে, পপ করলে `close()` হবে (`lazy: true` ডিফল্ট, সাথে সাথেই চাইলে `Provide.blocEager(...)`)।
   - `Provide<SharedFactoryBloc>()` — `OmniApp(blocs:)`-এ রেজিস্টার্ড ফ্যাক্টরি থেকে পেজে নতুন ইনস্ট্যান্স তৈরি করে।
   - `Provide.value(existingBloc)` — বাইরের ব্লক দেয়, পেজ পপ হলে বন্ধ করে **না**।
4. **একাধিক পেজে শেয়ার্ড Bloc (`OmniRouteGroup`):**
   - ধরুন `/students/:id` (বিস্তারিত) এবং `/students/:id/edit` (এডিট) — দুটো পেজই এক `StudentDetailBloc` শেয়ার করবে।
   - **`routes`**: কোন কোন রুট এই গ্রুপের ভেতর থাকবে।
   - **`provide`**: কোন Bloc-গুলো এরা ভাগ করে নেবে।
   - **`scopeKey` (`(s) => s.pathParameters['id']`)**: ID `10` থেকে `20`-এ গেলে পুরনো `10`-এর Bloc অটো-বন্ধ হয়ে `20`-এর নতুন Bloc তৈরি হবে!
   - **`guards`** ও **`transition`**: পুরো গ্রুপের সব পেজে প্রযোজ্য গার্ড ও অ্যানিমেশন।

```dart
OmniPage('/students', (_) => const StudentListScreen(), routes: [
  OmniRouteGroup(
    scopeKey: (s) => s.pathParameters['id'],
    provide: [
      Provide.bloc((c) => StudentDetailBloc(OmniParams.of(c).pathInt('id'))),
    ],
    routes: [
      OmniPage(':id', (p) => StudentDetailScreen(id: p.pathInt('id'))),
      OmniPage(':id/edit', (p) => StudentEditScreen(id: p.pathInt('id'))),
    ],
  ),
])
```

---

## ৯. ট্যাব ও শেয়ার্ড লেআউট — `OmniShell` ও `OmniStatefulShell`

### কখন কোনটা?
- **`OmniShell` (একটাই স্ট্যাক):** যখন সব চাইল্ড পেজের চারপাশে একই `Drawer`, `NavigationRail` বা `AppBar` রাখবেন, কিন্তু আলাদা আলাদা ট্যাব স্ট্যাক বাঁচানোর দরকার নেই।
  - প্যারামিটার: `builder(ctx, state, child)`, `routes`, `provide` (শেলের নিজস্ব Bloc), `navigatorKey`, `parentNavigatorKey`, `observers`, `guards`।
- **`OmniStatefulShell` + `OmniBranch` + `OmniNavigationShell` (পৃথক ট্যাব স্ট্যাক):** যখন নিচের Bottom Navigation Bar-এর প্রতিটি ট্যাবে আলাদা নেভিগেশন হিস্ট্রি, স্ক্রল পজিশন ও ট্যাব-লেভেল Bloc অটুট রাখতে চান।
  - **`OmniStatefulShell`**: `builder(ctx, state, shell)`, `branches`, `provide`, `parentNavigatorKey`, `restorationScopeId`, `guards`।
  - **`OmniBranch`**: `routes`, `initialLocation` (ট্যাবে প্রথম ঢুকলে কোন রুট খুলবে), `provide`, `navigatorKey`, `observers`, `restorationScopeId`।
  - **`shell.goBranch(index, initialLocation: ...)`**: `index` নং ট্যাবে যায়; `initialLocation: true` দিলে ট্যাবটি তার শুরুর পেজে রিসেট হয়।

---

## ১০. লগইন ও অনুমতি গার্ড — `OmniGuard`

গার্ড দুভাবে লেখা যায়: ক্লাস তৈরি করে (`class AuthGuard extends OmniGuard`) অথবা এক লাইনে `OmniGuard.fn(redirect, refresh: ...)` দিয়ে:
- **`redirect(BuildContext context, OmniRouteState state)`**: গন্তব্যে ঢোকার আগেই চলে। অন্য পাথ স্ট্রিং (যেমন `'/login?from=/dashboard'`) দিলে সেখানে পাঠিয়ে দেয়; `null` দিলে ঢুকতে দেয়। *(এখানে নেটওয়ার্ক কল না করে Bloc বা স্টেট পড়বেন।)*
- **`refresh(BuildContext context)`**: যে স্ট্রিম (`context.read<AuthBloc>().stream`) বদলালেই গার্ড স্বয়ংক্রিয়ভাবে রি-চেক হবে ও প্রয়োজনে রিডাইরেক্ট করবে (এবং ওয়েব হিস্ট্রি পরিচ্ছন্নভাবে রিপ্লেস করবে)।

```dart
class AuthGuard extends OmniGuard {
  const AuthGuard();

  @override
  Stream<Object?> refresh(BuildContext c) => c.read<AuthBloc>().stream;

  @override
  String? redirect(BuildContext c, OmniRouteState s) {
    final loggedIn = c.read<AuthBloc>().state;
    final atLogin = s.matchedLocation == '/login';
    if (!loggedIn && !atLogin) return '/login?from=${Uri.encodeComponent(s.location)}';
    if (loggedIn && atLogin) return s.params.query('from') ?? '/dashboard';
    return null;
  }
}
```

---

## ১১. অ্যাপ ও স্ক্রিনের লাইফসাইকেল — `OmniLifecycle` ও `OmniScreenHost`

- **`OmniLifecycle`**: আপনার `OmniStatelessWidget` অথবা `OmniStatefulWidget`-এর `OmniState`-এ `with OmniLifecycle` যোগ করলেই কোনো `WidgetsBindingObserver` কোড না লিখেই নিচের হুকগুলো পাবেন:
  - **স্ক্রিন দেখা বা আড়াল হওয়া:** `onScreenVisible(ctx)` (স্ক্রিনে এলে বা উপরের পেজ/ট্যাব থেকে ফিরলে), `onScreenHidden(ctx)` (উপরে পেজ খুললে বা অন্য ট্যাবে গেলে)।
  - **অ্যাপ স্টেট:** `onAppResumed(ctx)`, `onAppPaused(ctx)`, `onAppInactive(ctx)`, `onAppHidden(ctx)`, `onAppDetached(ctx)`, `onAppLifecycleChanged(ctx, state)`।
  - **সিস্টেম পরিবর্তন:** `onMemoryPressure(ctx)`, `onMetricsChanged(ctx)`, `onBrightnessChanged(ctx, b)`, `onLocalesChanged(ctx, l)`, `onTextScaleChanged(ctx)`।
- **`OmniScreenHost(screen: ...)` বা `.hosted()`**: কোনো Stateful স্ক্রিনকে `OmniPage` দিয়ে না খুলে অন্য পেজের ভেতর চাইল্ড উইজেট হিসেবে দেখালে তার `provide` Bloc চালু রাখতে `const MyCard().hosted()` ব্যবহার করুন।

---

## ১২. পেজ অ্যানিমেশন ও সোয়াইপ ব্যাক — `OmniPages` ও `OmniSwipeBackStyle`

- **রেডিমেড ট্রানজিশন (`OmniPages`):** `adaptive`, `material`, `cupertino`, `none`, `fade`, `slide`, `slideUp`, `scale`, `fadeScale`, `fadeSlide`, `swipeZoom`, `dialog({barrierColor, barrierDismissible})`, `bottomSheet({showDragHandle, isScrollControlled})`।
- **নিজের মতো কাস্টমাইজ (`OmniPages.transition` / `OmniPages.custom`):** `duration`, `reverseDuration`, `curve`, `opaque`, `barrierColor`, `barrierDismissible`, `fullscreenDialog`, `swipeBack`, `swipeBackStyle`।
- **`OmniSwipeBack` মোডসমূহ:** `none`, `slide` (iOS স্টাইল), `zoom`, `zoomCenter`, `zoomToEdge`, `zoomFollow`, `zoomCard`, `zoomParallax`, `zoomTilt`।
- **`OmniSwipeBackStyle` প্যারামিটারসমূহ (অথবা প্রিসেট `.subtle()` / `.dramatic()`):**
  - `minScale`, `maxRadius`, `slideFactor`, `fadeStart`, `maxTilt` (৩ডি হেলানো), `shadow`, `dimBelow`, `backgroundColor`।
  - জেসচার নিয়ন্ত্রণ: `edgeWidth` (২৮ পিক্সেল), `edges` (`{OmniSwipeEdge.left, OmniSwipeEdge.right}`), `closeThreshold` (`0.5`), `flickVelocity` (`1.0`), `settleCurve`, `closeCurve`, `settleDuration`।

---

## ১৩. টার্মিনাল কালার লগ ও ইন-অ্যাপ ইন্সপেক্টর — `LogOptions` ও `OmniInspector`

### `LogOptions` (`omni_network` প্যাকেজ থেকে)
- **`summary` (`bool = false`)**: `🟢 ✔ 200 OK · SUCCESS`, `⚡ FAST` ও JSON আকৃতির সারসংক্ষেপ যোগ করে।
- **`separate` (`bool = false`)**: Request (`📡 http-request`), Header ও JSON Body আলাদা আলাদা রঙিন বক্সে প্রিন্ট করে (ম্যাজেন্টা Request, সবুজ 2xx, নীল 3xx, কমলা `⚠️ http-warning` 4xx, লাল ব্যানারে `⛔ http-error` 5xx)।
- **`colors` (`bool? = null`)**: Android, macOS/Linux ডেস্কটপ, Chrome DevTools ও কালার টার্মিনালে অটো-চালু; iOS-এ প্লেইন থাকে (`true`/`false` দিয়ে ফোর্স করা যায়)।
- **`headers` (`false`), `requestBody` (`true`), `responseBody` (`true`), `maxLines` (`null` = সব লাইন), `width` (`60`), `maxLineLength` (`160` অক্ষরের পর `↪` দিয়ে মোড়া)**।

### `OmniInspector` ও `OmniInspectorLauncher` (`omni_network_flutter` প্যাকেজ থেকে)
- `OmniInspector({enabled, maxEntries: 300, forwardTo})` → ইন-অ্যাপ Talker-স্টাইল টাইমলাইন সংগ্রহ করে (রিলিজ বিল্ডে অটো-বন্ধ)।
- `inspector.attachClient(api, includeAi: true)` → HTTP, WebSocket ও AI কল অটো যুক্ত করে।
- `inspector.logRoute(...)` ও `inspector.logBloc(...)` → নেভিগেশন ও ব্লক কার্ডও একই টাইমলাইনে দেখায়।
- `OmniInspectorLauncher(inspector:, initialTab: InspectorTab.logs, alignment:, child:)` → অ্যাপের কোনায় ফ্লোটিং বাটন বসিয়ে **`All Logs`** কার্ড, ট্যাগ ফিল্টার, সার্চ ও প্রতিটি কার্ডে **১-ক্লিক JSON কপি** (`Copy Full Response`, `Copy Full Log`, `Copy as cURL`, `Copy HAR`, `Copy all logs`) সুবিধা দেয়।

---

## ১৪. জিরো-ল্যাগ Responsive Handling — `OmniResponsiveConfig` ও অ্যাডাপ্টিভ শেল/মোডাল

`omni_route` কোনো বাড়তি প্যাকেজ ছাড়াই নেটিভ Android (`dp` / `WindowSizeClass`) ও iOS (`pt` / `TraitCollection`)-এর মতো **জিরো-ওভারহেড রেসপন্সিভ ইঞ্জিন** সরাসরি `OmniApp`-এর সাথে চালু রাখে:

- **কোনো পিক্সেল জ্যাঙ্ক নেই:** প্রতিটি উইজেটে `.w`/`.h`/`.sp` ক্যালকুলেশন করে `const` ভাঙার বদলে `InheritedModel` ভিত্তিক ৫টি আলাদা অ্যাস্পেক্ট (`device`, `windowSize`, `orientation`, `tokens`, `metrics`) ও আগে থেকেই তৈরি **`const OmniResponsiveTokens`** ব্যবহার করে।
- **ইন্ট্রা-টিয়ার রি-বিল্ড শূন্য (`0`):** একই ব্রেকপয়েন্টের মধ্যে উইন্ডো রিসাইজ (`380px → 580px`) বা কিবোর্ড খোলা/বন্ধ হলে (`viewInsets`) `context.isMobile`, `context.tokens`, `context.responsiveValue(...)` বা `OmniResponsiveLayout` **একবারও রি-বিল্ড হয় না**।
- **`const Text` স্বয়ংক্রিয়ভাবে স্কেল হয়:** `OmniResponsiveConfig(adaptTextScaling: true)` প্রতিটি টিয়ারে (`smallPhone: 0.94`, `mobile: 1.0`, `tablet: 1.0`, `desktop: 1.05`, `largeDesktop: 1.08`) সুষম `TextScaler` বসায় এবং আপনার `minTextScale`/`maxTextScale` ও OS Accessibility মেনে চলে।
- **ডিফল্ট ব্রেকপয়েন্ট:** `mobile < 600` (`smallPhone < 360`), `tablet 600..1023`, `desktop 1024..1439`, `largeDesktop >= 1440` (চাইলে `useShortestSide: true` দিয়ে ফোনের ল্যান্ডস্কেপকে মোবাইল টিয়ারে স্থির রাখা যায়, অথবা `OmniResponsiveConfig.disabled()` দিয়ে বন্ধ করা যায়)।

### ক. `BuildContext` ও উইজেট হেল্পারসমূহ

| API / উইজেট | কাজ | রি-বিল্ড আচরণ |
|---|---|---|
| `context.isMobile` / `isTablet` / `isDesktop` / `isLargeDesktop` / `isCompactHeight` | ডিভাইস টিয়ার ও ছোট উচ্চতা চেক | কেবল ব্রেকপয়েন্ট সীমা পার হলেই রি-বিল্ড |
| `context.responsiveRead` | `onPressed` / কলব্যাকে নিরাপদ নন-লিসেনিং পড়া | **০ রি-বিল্ড** (`depend` করে না) |
| `OmniResponsiveScope.constrained(child:)` | স্প্লিট-প্যান বা সাইডবারের নিজের প্রস্থ অনুযায়ী রেসপন্সিভ | কেবল কন্টেইনার সাইজ বদলালে |
| `context.tokens` | `pagePadding`, `cardPadding`, `gapMd`, `cardBorderRadius`, `gridColumns`, `iconSize`, `maxContentWidth` | কেবল টিয়ার বদলালেই রি-বিল্ড (`const` অবজেক্ট) |
| `context.responsiveValue(mobile:, tablet:, desktop:)` | টিয়ার অনুযায়ী মান নেওয়া (নিচের টিয়ারে অটো ফলব্যাক) | কেবল টিয়ার বদলালেই রি-বিল্ড |
| `OmniResponsiveLayout(mobile:, tablet:, desktop:)` | স্ক্রিন ভেদে আলাদা লেআউট | কেবল টিয়ার বদলালেই রি-বিল্ড |
| `OmniResponsiveContainer(maxWidth:, child:)` | ওয়েব/ডেস্কটপে কনটেন্ট মাঝখানে ও নির্দিষ্ট প্রস্থে রাখা | এক পাসে নেটিভ `ConstrainedBox` লেআউট |
| `OmniResponsiveGrid` / `.builder` | `mobileColumns`/`desktopColumns` অথবা `maxItemWidth` দিলে C++ RenderObject-এ **120fps রিফ্লো** | `maxItemWidth` দিলে **০ Dart রি-বিল্ড** |
| `OmniResponsiveRowColumn` | মোবাইলে `Column`, ট্যাবলেট/ডেস্কটপে `Row` | কেবল টিয়ার বদলালেই রি-বিল্ড |
| `OmniResponsiveVisibility` | ডিভাইস অনুযায়ী উইজেট দেখানো/লুকানো | কেবল টিয়ার বদলালেই রি-বিল্ড |

### খ. অ্যাডাপ্টিভ ট্যাব নেভিগেশন ও মোডাল পেজ

```dart
OmniApp.material(
  routes: [
    // ১. মোবাইলে Bottom NavigationBar, ট্যাবলেটে Rail, ডেস্কটপে Extended Rail (ট্যাব স্টেট অক্ষুণ্ণ!)
    OmniStatefulShell.adaptive(
      destinations: const [
        OmniAdaptiveDestination(icon: Icon(Icons.home), label: 'Home'),
        OmniAdaptiveDestination(icon: Icon(Icons.person), label: 'Profile'),
      ],
      branches: [
        OmniBranch(routes: [OmniPage('/home', (_) => const HomePage())]),
        OmniBranch(routes: [OmniPage('/profile', (_) => const ProfilePage())]),
      ],
    ),
    // ২. মোবাইলে BottomSheet, ট্যাবলেট/ডেস্কটপে Dialog!
    OmniPage(
      '/filter',
      (_) => const FilterContent(),
      transition: OmniPages.adaptiveModal(),
    ),
  ],
)
```

### গ. এন্টারপ্রাইজ ও সিনিয়র-গ্রেড ফিচারসমূহ (Zero-Overhead Modular APIs)

1. **`OmniMasterDetail<T>` ও `OmniMasterDetailController<T>`:** মোবাইলে শুধু লিস্ট দেখিয়ে ক্লিকে পুশ (`onOpenMobile`) আর ট্যাবলেট/ডেস্কটপে দুই-প্যান স্প্লিট — আইটেম সিলেক্ট করলে **শুধু ডিটেইল প্যান** আপডেট হয়, মূল লিস্ট মোটেও রি-বিল্ড হয় না!
2. **`OmniFoldableSplit`:** `DisplayFeature` হিঞ্জ ডিটেক্ট করে ফোল্ডেবল ফোনে ভাঁজের দুই পাশে প্যান পরিচ্ছন্নভাবে আলাদা করে।
3. **`OmniTheme` — ১ লাইনে ডার্ক/লাইট/সিস্টেম থিমিং মোড ও অটো-সেভ (`SharedPreferences`):** *(সম্পূর্ণ গাইড: [doc/theming.bn.md](theming.bn.md))*
   - `OmniApp.material(omniTheme: const OmniTheme(seedColor: Colors.indigo, mode: ThemeMode.system, persistMode: true))` ব্যবহার করলে আর আলাদা কোনো থিম Bloc/প্যাকেজ লিখতে হয় না (এমনকি `Splash` ও `Onboarding`-ও থিম পায়!)।
   - **`OmniThemeModeButton()`** (`AppBar`-এর জন্য ১-ট্যাপ বাটন), **`OmniThemeModeSwitch()`** (`System / Light / Dark` সেগমেন্টেড সুইচ), এবং ১-লাইনে `context.toggleTheme()`, `context.setThemeMode(...)`, `context.isDarkMode`, `context.themeMode`।
   - প্রিসেটসমূহ: `OmniTheme(...)`, `OmniTheme.compact(...)` (`8dp`), `OmniTheme.pill(...)` (`20dp`) — সাথে মেমোইজড `ThemeData` ক্যাশ (`0` এক্সট্রা রি-বিল্ড)।
4. **`OmniResponsiveSliverGrid`:** `CustomScrollView`-এর ভেতর `O(visible)` মেমরিতে হাজার হাজার আইটেম ১২০fps-এ ভার্চুয়ালাইজ করে।
5. **`OmniBreadcrumbBar`:** ট্যাবলেট/ডেস্কটপে ইন্টারেক্টিভ পাথ ব্রেডক্রাম্ব (`Home > Shop > Electronics`) দেখায় ও মোবাইলে স্বয়ংক্রিয়ভাবে লুকায়।
6. **`OmniPrefetch` ও `OmniPage(onPrefetch:)`:** ডেস্কটপে হোভার বা মোবাইলে টাচ-ডাউনের সাথে সাথে `OmniRoute.prefetch(...)` চালিয়ে ব্যাকগ্রাউন্ডে ডেটা আনে (বাউন্ডেড ৬৪-এন্ট্রি `ttl` ডিডুপ্লিকেশনসহ)।
7. **`OmniPage(validateParams:)` ও `OmniParams` স্ট্রিক্ট ভ্যালিডেশন:** `pathPositiveInt`, `pathEnum`, `queryRequired`, `queryDateTime`, `queryOneOf` দিয়ে **পেইজ বা Bloc তৈরি হওয়ার আগেই** ভুল ডিপ-লিংক নিরাপদে এরর পেজে ফেরত পাঠায়।
8. **`OmniAppGate` (`OmniConfig(gate:)`):** স্টার্টআপে **Maintenance মোড** (`OmniGateStatus.maintenance`) ও **Force Update / Dismissible Update** (`OmniGateStatus.updateRequired`) নিয়ন্ত্রণ করে (`gate == null` হলে কোনো ওভারহেড নেই)।
9. **বাউন্ডেড ক্র্যাশ ব্রেডক্রাম্ব (`maxBreadcrumbs = 25`):** `OmniRoute.breadcrumbs`, `OmniRoute.recordBreadcrumb(...)` এবং `OmniRoute.exportDiagnostics()` দিয়ে Crashlytics/Sentry-এর জন্য তাৎক্ষণিক ডায়াগনস্টিক রিপোর্ট পাওয়া যায়।
