# প্রস্তাব: Omni Theming ও OmniApp রিডিজাইন

> অবস্থা: **বাস্তবায়িত (0.5)**, এই পরিবর্তনগুলো বাদে —
> A6 (reduce motion) আগে থেকেই ছিল; B7 (color field deprecate) ও C2 (OmniApp
> parameter গ্রুপ) সিদ্ধান্ত না পাওয়ায় করা হয়নি; wallpaper color করা হয়নি।
> A3-এ idle task-এর বদলে frame-প্রতি একটা কাজ (post-frame queue) ব্যবহার করা হয়েছে।
> অতিরিক্ত যোগ হয়েছে: লেখার আকার ব্যবস্থা (`OmniTextSize`)।

## সারসংক্ষেপ

তিনটা লক্ষ্য:

1. **ল্যাগ বা ঝলক একদম না থাকা** — অ্যাপ খোলার সময়, থিম বদলানোর সময়, আর উইন্ডোর সাইজ বদলানোর সময়।
2. **কম কোডে বেশি কাজ** — একটা seed color থেকে পুরো থিম, runtime-এ নতুন থিম, JSON থেকে থিম, আলাদা অংশে আলাদা থিম।
3. **OmniApp-এর একটাই ভিত্তি** — এখন `OmniApp` আর `OmniResponsiveApp` একই কাজ দুই জায়গায় আলাদা করে করে; একটায় ঠিক করলে অন্যটায় ভুল থেকে যায়।

নতুন কোনো dependency যোগ হবে না।

---

## ১. যা মেপে পাওয়া গেছে (এখনকার অবস্থা)

| বিষয় | এখন | সমস্যা |
|---|---|---|
| অ্যাপ খোলা (saved dark theme) | প্রথম frame default (light) থিমে আঁকা হয়, তারপর dark-এ বদলায় | **প্রতিবার অ্যাপ খুললে সাদা ঝলক** দেখা যায়। ভাষার ক্ষেত্রেও একই |
| `resolveColors()` | প্রতি rebuild-এ নতুন করে হিসাব, cache নেই | debug-এ ০.৪–১.৩ ms প্রতিবার |
| থিম বদলানো | light **আর** dark দুটো `ThemeData` একসাথে তৈরি হয় | একটা লাগলেও দুটোর খরচ (প্রতিটা ~১.১–১.৪ ms debug) ঠিক যে frame-এ ব্যবহারকারী ট্যাপ করেছে সেই frame-এ |
| breakpoint পার হওয়া (desktop/web-এ উইন্ডো resize) | পুরো theme cache মুছে যায় | resize করার সময় হঠাৎ ঝাঁকুনি (jank) |
| নতুন থিম প্রথমবার বেছে নেওয়া | আগে থেকে তৈরি করা থাকে না | প্রথম switch-টাই সবচেয়ে ধীর |
| "Reduce motion" (accessibility) | থিম transition এটা মানে না | যাদের animation বন্ধ রাখা দরকার তাদেরও circular reveal দেখায় |
| `OmniApp` বনাম `OmniResponsiveApp` | ~১৫০ লাইন একই composition দুই জায়গায় | আচরণ আলাদা হয়ে যেতে পারে |
| `OmniApp.material` | ~৭০টা parameter এক লাইনে | কোনটা কোন কাজের, খুঁজে পাওয়া কঠিন |
| `OmniTheme` | ~৭৫টা আলাদা color field (`cardColor`, `darkCardColor`, …) **এবং** `light`/`dark` palette — একই কাজের দুই উপায় | শেখা ও maintain করা কঠিন |

(সময়গুলো debug build-এর; release-এ ৩–৫ গুণ দ্রুত, কিন্তু ১৬ ms-এর frame-এ এগুলো জমে jank তৈরি করে।)

ভালো যা আছে, যা বদলাবে না: theme transition animation painter-এ চলে, প্রতি frame-এ widget tree rebuild করে না — এটা সঠিক ডিজাইন।

---

## ২. ধাপ A — পারফরম্যান্স (API বদলাবে না, ব্যবহারকারীর কোড বদলাতে হবে না)

**A1. অ্যাপ খোলার সময় ঝলক বন্ধ।**
প্রথম frame আঁকার আগে saved থিম/ভাষা পড়া হবে। `OmniApp` নিজে থেকেই প্রথম frame সর্বোচ্চ ~১০০ ms পর্যন্ত আটকে রাখবে (`deferFirstFrame`), এর মধ্যে prefs না এলে default দিয়েই চালু হবে — অ্যাপ কখনো আটকে থাকবে না।
ঐচ্ছিকভাবে আরও দ্রুত:
```dart
void main() async {
  await OmniApp.preload();   // prefs আগেই পড়ে রাখে; না দিলেও কাজ করবে
  runApp(OmniApp.material(...));
}
```

**A2. Colors cache।** `(theme, brightness)` অনুযায়ী `OmniColors` একবারই হিসাব হবে।

**A3. শুধু যেটা দেখা যাচ্ছে সেটা আগে।** এখন যে brightness দেখানো হচ্ছে সেটার `ThemeData` সাথে সাথে; অন্যটা (system dark/light বদলের জন্য) idle সময়ে তৈরি হবে — ট্যাপের frame-এ দ্বিগুণ খরচ থাকবে না।

**A4. Breakpoint-ভিত্তিক cache।** প্রতিটা device tier-এর জন্য আলাদা cache (সর্বোচ্চ ৪টা), তাই resize-এ আগে তৈরি করা থিম আবার কাজে লাগবে।

**A5. Precache।** অ্যাপ idle থাকলে picker-এ থাকা থিমগুলো আগেই তৈরি করে রাখবে; চাইলে নিজেও:
```dart
context.themeController.precache(['ocean', 'emerald']);
```

**A6. Reduce motion মানা।** OS-এ animation বন্ধ থাকলে (`MediaQuery.disableAnimations`) থিম সাথে সাথে বদলাবে।

**A7. Regression টেস্ট।** থিম বদলালে কতবার rebuild হয় আর resolve কত সময় নেয় — এর সীমা টেস্টে বাঁধা থাকবে, যাতে ভবিষ্যতে কেউ ধীর করে ফেললে CI ধরে ফেলে।

---

## ৩. ধাপ B — Theming আরও শক্তিশালী (নতুন ফিচার, পুরোনো কোড চলবে)

**B1. এক লাইনে থিম, পছন্দমতো palette ধরন।**
```dart
OmniTheme.fromSeed(
  const Color(0xFF0EA5E9),
  id: 'brand',
  variant: OmniPaletteVariant.vibrant, // tonalSpot, fidelity, vibrant, expressive, monochrome…
)
```
(Flutter-এর নিজস্ব `DynamicSchemeVariant` ব্যবহার করে — কোনো package লাগবে না।)

**B2. High contrast নিজে থেকে।** OS-এ high contrast চালু থাকলে প্রতিটা থিমের high-contrast সংস্করণ স্বয়ংক্রিয়ভাবে তৈরি হয়ে `MaterialApp.highContrastTheme`-এ যাবে।

**B3. Runtime-এ নতুন থিম (user নিজে রং বেছে থিম বানাবে) — সেভসহ।**
```dart
context.themeController.addTheme(OmniTheme.fromSeed(pickedColor, id: 'my-theme'));
context.setTheme('my-theme');      // অ্যাপ বন্ধ করে খুললেও থাকবে
```

**B4. JSON থেকে / JSON-এ থিম** — server থেকে brand theme বা A/B test:
```dart
final theme = OmniTheme.fromJson(await api.get('/theme'));
final json = theme.toJson();
```

**B5. অ্যাপের একটা অংশে আলাদা থিম।**
```dart
OmniThemeOverride(
  theme: OmniTheme.emerald,      // শুধু এই card / section / preview-তে
  child: PremiumSection(),
)
```
এটাও cache ব্যবহার করবে, তাই list-এর ভেতরে থাকলেও ধীর হবে না।

**B6. Contrast সতর্কতা (শুধু debug)।** custom রঙে লেখা আর background-এর contrast WCAG AA (৪.৫:১)-এর নিচে হলে console-এ সতর্কবার্তা — release-এ কোনো খরচ নেই।

**B7. Color API এক রকম করা।** `light: OmniColorPalette(...)` / `dark: ...` হবে প্রধান উপায়। পুরোনো আলাদা field (`cardColor`, `darkCardColor`, …) এখনই মুছবে না — `@Deprecated` করে রাখা হবে, পুরোনো কোড চলবে, migration guide-এ নতুন লেখার নিয়ম থাকবে। *(সিদ্ধান্ত লাগবে — নিচে প্রশ্ন ১)*

---

## ৪. ধাপ C — OmniApp আরও শক্তিশালী

**C1. এক ভিত্তি।** `OmniApp` ভেতরে `OmniResponsiveApp` ব্যবহার করবে। ~১৫০ লাইন duplicate কোড মুছে যাবে, আর responsive/theme/system UI/localization-এর আচরণ দুই জায়গায় হুবহু এক থাকবে।

**C2. Parameter গুছানো।** ৭০টা parameter বিষয় অনুযায়ী ভাগ:
```dart
OmniApp.material(
  routes: [...],
  ui: OmniUi(                      // থিম, system bar, text scale, orientation
    themes: OmniTheme.presets,
    statusBar: ..., screenMode: ...,
  ),
  navigation: OmniNavigation(      // swipe back, predictive back, escape, double-back-exit
    swipeBack: true,
  ),
  startup: OmniStartup(            // onInit, splash, timeout, error
    onInit: (c) async => ...,
    splash: const OmniSplash(...),
  ),
)
```
পুরোনো flat parameter-গুলো 0.5-এ কাজ করবে (`@Deprecated`), পরের major version-এ সরানো হবে। *(সিদ্ধান্ত লাগবে — প্রশ্ন ২)*

**C3. Startup আরও দ্রুত।** splash/`onInit` চলার সময়েই প্রথম থিম তৈরি হয়ে থাকবে, তাই প্রথম স্ক্রিন আসার frame হালকা থাকবে।

**C4. `OmniApp.cupertino` সমান সুবিধা।** material-এ যা আছে (থিম transition, high contrast, override) cupertino-তেও কাজ করবে — টেস্টসহ যাচাই।

**C5. নিরাপদ fallback।** কোনো custom থিম বা `customizer` exception দিলে অ্যাপ crash না করে আগের থিমে থাকবে, debug-এ কারণ দেখাবে।

---

## ৫. যা করা হবে না (ইচ্ছাকৃত)

- **Wallpaper থেকে রং (Android 12+ Material You)** — এর জন্য native plugin লাগে, যা app size বাড়ায়। দরকার হলে পরে আলাদা ঐচ্ছিক package (`omni_dynamic_color`) হিসেবে। *(প্রশ্ন ৩)*
- নতুন কোনো third-party dependency নয়।
- পুরোনো API এক ধাক্কায় মুছে ফেলা নয় — সব পরিবর্তন deprecation-সহ।

---

## ৬. যাচাই কীভাবে হবে

- প্রতিটা ধাপের জন্য widget test (leak tracker চালু): saved dark theme-এ **প্রথম frame-ই dark**, resize-এ cache hit, precache-এর পর switch-এ resolve শূন্য, reduce motion-এ animation নেই, override subtree, JSON round-trip, high contrast।
- Rebuild-count ও সময়ের সীমা টেস্ট (A7)।
- Release build: Android, iOS, web (JS + Wasm), macOS।
- সব package-এর পুরো test suite, `flutter analyze`, format check।
- README, `doc/theming.bn.md`, `doc/migration.md`, CHANGELOG হালনাগাদ।

## ৭. ক্রম

| ধাপ | কী | Breaking? |
|---|---|---|
| A | পারফরম্যান্স ও startup ঝলক | না |
| B | নতুন theming ফিচার | না (B7-এ শুধু deprecation) |
| C | OmniApp এক ভিত্তি + parameter গুছানো | না (C2-এ শুধু deprecation) |

ধাপ A সবচেয়ে বেশি দরকারি — ব্যবহারকারী সরাসরি পার্থক্য দেখবে।

---

## ৮. আপনার সিদ্ধান্ত দরকার

1. **B7** — আলাদা color field-গুলো (`cardColor`, `darkCardColor`, …) deprecate করে `light`/`dark` palette-কে একমাত্র উপায় বানাবো? (পুরোনো কোড চলতেই থাকবে, শুধু সতর্কবার্তা দেখাবে)
2. **C2** — `OmniApp`-এর parameter-গুলো `ui:` / `navigation:` / `startup:` গ্রুপে ভাগ করবো? নাকি flat-ই রাখবো?
3. **Wallpaper color** — এখন বাদ, নাকি আলাদা ঐচ্ছিক package হিসেবে এখনই?
4. তিনটা ধাপই করবো, নাকি শুধু কিছু (যেমন আগে শুধু A)?
