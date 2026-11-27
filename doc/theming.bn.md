# OmniTheme — পূর্ণাঙ্গ বাংলা থিমিং গাইড (Dark/Light, TextField, Button ও Custom Setup)

> আলাদা `ThemeBloc`, `ChangeNotifier` বা `SharedPreferences` বয়লারপ্লেট ছাড়াই কীভাবে `OmniRoute`-এ পুরো অ্যাপের **রঙ, ডার্ক/লাইট/সিস্টেম মোড, অটো-সেভ, `TextField`, `Button`, `Card` ও যেকোনো কাস্টম উইজেট** আগে থেকেই সেটআপ ও ব্যবহার করবেন — এই ডকে ধাপে ধাপে উদাহরণসহ দেখানো হয়েছে।

> মূল গাইড: [doc/guide.bn.md](guide.bn.md) · প্রজেক্ট ওভারভিউ: [README.md](../README.md)

---

## সূচিপত্র

1. [১ মিনিটে শুরু — সবচেয়ে সহজ সেটআপ](#১-১-মিনিটে-শুরু--সবচেয়ে-সহজ-সেটআপ)
2. [আগে থেকেই থিম সেটআপ করা (`OmniTheme` সব প্যারামিটার ও প্রিসেট)](#২-আগে-থেকেই-থিম-সেটআপ-করা-omnitheme-সব-প্যারামিটার-ও-প্রিসেট)
3. [Dark / Light / System মোড ও Settings ১-ক্লিক কালার প্যালেট নিয়ন্ত্রণ](#৩-dark--light--system-মোড-ও-settings-১-ক্লিক-কালার-প্যালেট-নিয়ন্ত্রণ)
4. [আগে থেকেই কোন কোন উইজেট থিমড থাকে (`TextField`, `Button`, `Card`, `NavigationBar`)](#৪-আগে-থেকেই-কোন-কোন-উইজেট-থিমড-থাকে-textfield-button-card-navigationbar)
5. [যেকোনো বাকি উপাদান আগে থেকেই গ্লোবালি থিম করা (`customizer`)](#৫-যেকোনো-বাকি-উপাদান-আগে-থেকেই-গ্লোবালি-থিম-করা-customizer)
6. [সহজ কালার, টেক্সট স্টাইল ও স্টাইল সিস্টেম (`context.ui`, `context.colors`, `context.textStyles`, `context.styles`)](#৬-সহজ-কালার-টেক্সট-স্টাইল-ও-স্টাইল-সিস্টেম-contextui-contextcolors-contexttextstyles-contextstyles)
7. [কাস্টম `OmniThemeController` (অ্যাপের বাইরে বা Bloc থেকে কন্ট্রোল)](#৭-কাস্টম-omnithemecontroller-অ্যাপের-বাইরে-বা-bloc-থেকে-কন্ট্রোল)
8. [পারফরম্যান্স ও মেমরি নীতি (`0` এক্সট্রা রি-বিল্ড)](#৮-পারফরম্যান্স-ও-মেমরি-নীতি-0-এক্সট্রা-রি-বিল্ড)
9. [পূর্ণাঙ্গ ব্যবহারিক উদাহরণ (Login + Settings + Palette Sheet + Form)](#৯-পূর্ণাঙ্গ-ব্যবহারিক-উদাহরণ-login--settings--palette-sheet--form)

---

## ১. ১ মিনিটে শুরু — সবচেয়ে সহজ সেটআপ

### ক. শুধু একটি থিম + Dark/Light/System মোড:
```dart
OmniApp.material(
  title: 'My App',
  omniTheme: const OmniTheme(
    seedColor: Colors.indigo,
    mode: ThemeMode.system, // .system / .light / .dark
    persistMode: true,      // ইউজার বদলালে অটো-সেভ থাকবে
    surfaceColor: Color(0xFFF8FAFC), // Scaffold/পেজ ব্যাকগ্রাউন্ড
    buttonColor: Colors.indigo,      // প্রাইমারি বাটন কালার
    borderColor: Color(0xFFCBD5E1),  // কার্ড ও ইনপুট বর্ডার
    errorColor: Color(0xFFDC2626),   // এরর কালার
    warningColor: Color(0xFFD97706), // ওয়ার্নিং কালার
    successColor: Color(0xFF059669), // সাকসেস কালার
  ),
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
  ],
)
```

### খ. একাধিক কালার প্যালেট (`themes:`) দিয়ে সেটিংস থেকে ১-ক্লিকে পুরো অ্যাপ পরিবর্তন:
```dart
OmniApp.material(
  title: 'Multi-Theme App',
  omniTheme: const OmniTheme(
    seedColor: Colors.indigo,
    style: OmniThemeStyle.outlined, // অথবা .modern / .soft / .elevated / .minimal / .compact
  ),
  // রেডিমেড ৮টি প্যালেট (`Ocean`, `Emerald`, `Violet`, `Sunset`, `Rose`, `Teal`, `Amber`, `Slate`)
  themes: OmniTheme.presets,
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
  ],
)
```

সেটিংস বা যেকোনো স্ক্রিনে ১ ক্লিকে কালার প্যালেট ও মোড (`Dark / Light / System`) পাল্টে দিন:
- `Settings` কার্ডে: **`const OmniThemePanel(showStylePicker: true)`** (মোড সুইচ + কালার প্যালেট কার্ড + স্টাইল পিকার!)
- `Settings` `ListView`-তে: **`const OmniThemeSettingsTile()`** (ট্যাপ করলেই বটমশিট/ডায়ালগ খুলে দেয়!)
- `AppBar` বাটনে: **`const OmniThemeButton()`** (১ ক্লিকে কালার প্যালেট পাল্টায়) ও **`const OmniThemeModeButton(allowSystemMode: true)`** (`System <-> Light <-> Dark`!)
- কোড থেকে: **`context.nextTheme()`**, **`context.setTheme('emerald')`**, **`context.setThemeMode(ThemeMode.dark)`**, **`context.setThemeStyle(OmniThemeStyle.elevated)`**, **`context.openThemeSettings()`**

---

## ২. আগে থেকেই থিম সেটআপ করা (`OmniTheme` সব প্যারামিটার ও প্রিসেট)

### ক. ৩টি রেডিমেড কনস্ট্রাক্টর (Preset)

| কনস্ট্রাক্টর | কখন ব্যবহার করবেন? | কর্নার ও ইনপুট স্টাইল |
|---|---|---|
| `OmniTheme(seedColor: ...)` | ডিফল্ট আধুনিক Material 3 স্টাইল | ডিভাইস টিয়ার অনুযায়ী অটো (`10`–`24dp`), `inputVariant: .filled` |
| `OmniTheme.compact(seedColor: ...)` | ড্যাশবোর্ড, অ্যাডমিন বা প্রোডাক্টিভিটি অ্যাপ | সবসময় তীক্ষ্ণ `8dp`, `inputVariant: .outlined` |
| `OmniTheme.pill(seedColor: ...)` | সোশ্যাল, কনজিউমার বা ফ্রেন্ডলি মোবাইল অ্যাপ | সবসময় গোল `20dp`, `inputVariant: .filled` |

### খ. `OmniTheme`-এর মূল প্যারামিটার ও স্টাইল কন্ট্রোল

| প্যারামিটার | ধরন ও ডিফল্ট | কাজ |
|---|---|---|
| `seedColor` | `Color` *(আবশ্যক)* | লাইট ও ডার্ক মূল ব্র্যান্ড প্যালেট তৈরি করে |
| `style` | `OmniThemeStyle = .modern` | ১-লাইনের ডিজাইন প্রিসেট (`.modern`, `.outlined`, `.soft`, `.elevated`, `.minimal`, `.compact`) |
| `mode` | `ThemeMode = ThemeMode.system` | প্রথমবার অ্যাপ চালু হলে কোন মোড দেখাবে |
| `persistMode` | `bool = true` | `SharedPreferences`-এ ইউজারের পছন্দের প্যালেট, মোড ও স্টাইল সেভ রাখবে কি না |
| `storageKey` | `String = 'default'` | সেভ করার চাবি (একাধিক অ্যাপ বা প্রোফাইল আলাদা রাখতে) |
| `controller` | `OmniThemeController? = null` | বাইরে থেকে মোড/প্যালেট/স্টাইল পাল্টাতে চাইলে নিজের কন্ট্রোলার দিন |
| `fontFamily` | `String? = null` | পুরো অ্যাপের ডিফল্ট ফন্ট (যেমন `'HindSiliguri'`) |
| `headingWeight` | `FontWeight = FontWeight.w700` | `display`, `heading`, `title` ও হেডিংগুলোর ডিফল্ট ফন্ট ওয়েট |
| `borderRadius` | `double? = null` | কার্ড, বাটন ও ইনপুটের কর্নার রেডিয়াস (`null` হলে [style] বা টিয়ার অনুযায়ী অটো) |
| `inputVariant` | `OmniInputVariant? = null` | সব `TextField`-এর ধরন (`.filled`, `.outlined`, `.underlined`; না দিলে [style] অনুযায়ী) |
| `borderWidth` | `double? = null` | সাধারণ অবস্থায় ইনপুট, চিপ ও আউটলাইন বাটনের বর্ডার পুরুত্ব |
| `focusedBorderWidth` | `double? = null` | ইনপুট ফোকাস বা এরর অবস্থায় বর্ডার পুরুত্ব |
| `cardBorderWidth` | `double? = null` | কার্ডের বর্ডার পুরুত্ব (`0` দিলে বর্ডার ছাড়া ফ্ল্যাট কার্ড হয়) |
| `cardElevation` | `double? = null` | `Card`-এর শ্যাডো উচ্চতা |
| `appBarCenterTitle` | `bool? = null` | `true`/`false` করলে সব পেজের `AppBar` টাইটেল সেন্টার বা বামে থাকে |
| `useMaterial3` | `bool = true` | Material 3 ডিজাইন সিস্টেম চালু রাখে |
| `customizer` | `OmniThemeCustomizer?` | বিশেষ কোনো অতিরিক্ত উইজেট কাস্টম করার হুক |

### গ. সহজ কালার ওভাররাইড (ঐচ্ছিক — না দিলে `seedColor` থেকেই অটো তৈরি হয়)

- **সারফেস ও কার্ড:** `surfaceColor`, `darkSurfaceColor`, `secondaryBackgroundColor`, `darkSecondaryBackgroundColor`, `cardColor`, `darkCardColor`, `dividerColor` *(পুরোনো `scaffoldBackgroundColor` ও সমর্থিত)*
- **অ্যাপবার ও নেভিগেশন:** `appBarColor`, `appBarTextColor`, `navBarColor`, `navSelectedColor`, `navUnselectedColor`
- **বাটন ও লিংক:** `buttonColor`, `buttonTextColor`, `secondaryButtonColor`, `secondaryButtonTextColor`, `dangerButtonColor`, `dangerButtonTextColor`, `linkColor`
- **ইনপুট, বর্ডার ও টেক্সট:** `inputFillColor`, `borderColor`, `focusedBorderColor`, `textColor`, `secondaryTextColor`, `hintTextColor`, `iconColor`
- **চিপ, ব্যাজ ও ডিজেবল/ইন্টার‍্যাকশন:** `chipColor`, `chipTextColor`, `badgeColor`, `badgeTextColor`, `selectedItemColor`, `hoverColor`, `rippleColor`, `disabledColor`, `disabledTextColor`, `disabledBorderColor`
- **কন্ট্রোল, টোস্ট ও টুলটিপ:** `switchActiveColor`, `switchInactiveColor`, `snackbarColor`, `snackbarTextColor`, `tooltipColor`, `tooltipTextColor`
- **স্ট্যাটাস, শিমার ও শ্যাডো:** `errorColor`, `warningColor`, `successColor`, `infoColor`, `shimmerBaseColor`, `shimmerHighlightColor`, `overlayColor`, `shadowColor`
- **সম্পূর্ণ কাস্টম প্যালেট:** চাইলে `lightColors:` এবং `darkColors:`-এ সরাসরি `OmniColors(...)` দিতে পারেন।

### ঘ. একটি পূর্ণ-কনফিগার করা উদাহরণ

```dart
const appTheme = OmniTheme(
  id: 'clinic_teal',
  name: 'Clinic Teal',
  seedColor: Color(0xFF0F766E),
  secondaryColor: Color(0xFFF59E0B),
  secondaryButtonColor: Color(0xFFE2E8F0),
  dangerButtonColor: Color(0xFFDC2626),
  disabledColor: Color(0xFFF1F5F9),
  style: OmniThemeStyle.outlined,
  mode: ThemeMode.system,
  persistMode: true,
  fontFamily: 'HindSiliguri',
  headingWeight: FontWeight.w800,
  surfaceColor: Color(0xFFF8FAFC),
  darkSurfaceColor: Color(0xFF0B1120),
  appBarCenterTitle: false,
);
```

---

## ৩. Dark / Light / System মোড ও Settings ১-ক্লিক কালার প্যালেট নিয়ন্ত্রণ

### ক. Settings পেজ ও `AppBar`-এর রেডিমেড উইজেট

1. **`AppBar`-এ ১-ট্যাপ বাটন (`OmniThemeModeButton` ও `OmniThemeButton`):**

```dart
AppBar(
  title: const Text('Dashboard'),
  actions: const [
    OmniThemeButton(),                          // ১ ক্লিকে পরের কালার প্যালেটে যায়
    OmniThemeModeButton(allowSystemMode: true), // System <-> Light <-> Dark!
  ],
)
```

2. **`Settings` পেজে সম্পূর্ণ প্যানেল (`OmniThemePanel`) বা রো টাইল (`OmniThemeSettingsTile`):**

```dart
// বিকল্প ১: Settings পেজে সরাসরি সম্পূর্ণ কার্ড:
const OmniThemePanel(
  modeTitle: 'থিম মোড',
  themeTitle: 'কালার প্যালেট',
  styleTitle: 'থিম স্টাইল',
  systemLabel: 'সিস্টেম',
  lightLabel: 'লাইট',
  darkLabel: 'ডার্ক',
  showStylePicker: true,
)

// বিকল্প ২: Settings ListView-তে ১টি ক্লিকেবল রো (ট্যাপে মডাল শিট খোলে):
const OmniThemeSettingsTile(
  title: 'থিম ও কালার প্যালেট',
  sheetTitle: 'অ্যাপিয়ারেন্স সেটিংস',
  systemLabel: 'সিস্টেম',
  lightLabel: 'লাইট',
  darkLabel: 'ডার্ক',
)
```

### খ. কোড থেকে যেকোনো বাটন/ইভেন্টে মোড, প্যালেট ও স্টাইল পরিবর্তন

```dart
// ডার্ক <-> লাইট পাল্টান:
ElevatedButton(
  onPressed: () => context.toggleTheme(),
  child: Text(context.isDarkMode ? 'লাইট মোড দিন' : 'ডার্ক মোড দিন'),
)

// নির্দিষ্ট মোড সেট করুন (System / Light / Dark):
context.setThemeMode(ThemeMode.dark);
context.setThemeMode(ThemeMode.light);
context.setThemeMode(ThemeMode.system);

// ১ ক্লিকে কালার প্যালেট ও স্টাইল বদলান:
context.setTheme('violet');
context.setThemeStyle(OmniThemeStyle.elevated);
context.openThemeSettings();

// system -> light -> dark -> system ঘোরান:
context.cycleThemeMode();

// বর্তমান মোড পড়ুন:
final mode = context.themeMode;
```

> **নোট:** `persistMode: true` থাকলে মোড, কালার প্যালেট ও স্টাইল পরিবর্তন করামাত্রই ব্যাকগ্রাউন্ডে `SharedPreferences`-এ (`mode`, `themeId`, `style`) সেভ হয়ে যায়।

---

## ৪. আগে থেকেই কোন কোন উইজেট থিমড থাকে (`TextField`, `Button`, `Card`, `NavigationBar`)

`OmniTheme` প্রতি ডিভাইস টিয়ার অনুযায়ী (`mobile`, `tablet`, `desktop`, `largeDesktop`) আগে থেকেই নিচের উপাদানগুলো সাজিয়ে দেয় — তাই স্ক্রিনের ভেতর প্রতিবার আলাদা স্টাইল লেখার দরকার পড়ে না:

### ক. `TextField`, `TextFormField` ও ৩টি `OmniInputVariant`

`OmniTheme(inputVariant: ...)` বা `style:` দিয়ে এক লাইনে পুরো অ্যাপের সব টেক্সট ফিল্ডের স্টাইল ঠিক করতে পারবেন:

| ভ্যারিয়েন্ট (`OmniInputVariant`) | দেখতে কেমন | কখন ভালো মানায়? |
|---|---|---|
| `OmniInputVariant.filled` *(ডিফল্ট)* | নরম ব্যাকগ্রাউন্ড (`inputFillColor`) + সূক্ষ্ম বর্ডার | সাধারণ মোবাইল ও কনজিউমার অ্যাপ |
| `OmniInputVariant.outlined` | ট্রান্সপারেন্ট ফিল + চারদিকে পরিষ্কার বর্ডার | ফর্ম-প্রধান, ড্যাশবোর্ড ও SaaS অ্যাপ |
| `OmniInputVariant.underlined` | ফিল ছাড়া শুধু নিচে লাইন বর্ডার | মিনিমাল/রিডার-ফোকাসড প্রোফাইল ফর্ম |

**স্ক্রিনে যেভাবে লিখবেন (একদম কম কোডে):**

```dart
final ui = context.ui;

// ১. সাধারণ স্ট্যান্ডার্ড TextField (Theme-এর inputVariant অটো নেয়):
TextField(
  decoration: ui.styles.inputDecoration(
    label: 'ইমেইল',
    hint: 'you@example.com',
    prefixIcon: const Icon(Icons.email_outlined),
  ),
)

// ২. রেডি পিল-আকৃতির সার্চ বার:
TextField(
  decoration: ui.styles.searchDecoration(
    hint: 'পণ্য খুঁজুন...',
    onClear: () {},
  ),
)
```

### খ. বাটন (`FilledButton`, `ElevatedButton`, `OutlinedButton`, `TextButton` + `Secondary` / `Danger`)

**আগে থেকে কী সেট থাকে:**
- `minimumSize`: `Size(0, tokens.minTapTarget)` — মোবাইলে `48dp`, ট্যাবলেটে `44dp`, ডেস্কটপে `40dp`।
- `shape`: `RoundedRectangleBorder` (`borderRadius` অথবা `tokens.buttonBorderRadius`) এবং টেক্সট স্টাইল `textStyles.button`।
- পাশাপাশি `secondaryButtonColor`, `dangerButtonColor`, এবং `disabledColor` / `disabledTextColor` **স্বয়ংক্রিয়ভাবে** সক্রিয় ও নিষ্ক্রিয় দুই অবস্থায়ই সেট থাকে!

```dart
final s = context.styles;

// ১. প্রাথমিক অ্যাকশন (Primary)
FilledButton(onPressed: () {}, child: const Text('লগইন করুন'))

// ২. সেকেন্ডারি অ্যাকশন (Cancel / Skip / Filter)
FilledButton(
  style: s.secondaryButton,
  onPressed: () {},
  child: const Text('পরে দেখব'),
)

// ৩. ডেঞ্জার অ্যাকশন (Delete / Remove / Logout)
FilledButton(
  style: s.dangerButton,
  onPressed: () {},
  child: const Text('অ্যাকাউন্ট মুছুন'),
)

// ৪. আউটলাইন ও লিংক বাটন (ডিজেবল অবস্থায় disabledBorderColor পায়)
OutlinedButton(onPressed: null, child: const Text('নিষ্ক্রিয় বাটন'))
TextButton(onPressed: () {}, child: const Text('পাসওয়ার্ড ভুলে গেছেন?'))
```

### গ. কার্ড, ডায়ালগ, বটমশিট, স্ন্যাকবার, সুইচ ও নেভিগেশন

- **`Card`**: `color: cardColor`, `shadowColor`, `elevation`, বর্ডার (`cardBorderWidth`), কর্নার `tokens.cardBorderRadius`।
- **`Dialog` ও `BottomSheet`**: থিম অনুযায়ী `cardColor`, ব্যাকড্রপ স্ক্রিন ডার্কেন (`overlayColor`), গোল কর্নার।
- **`Switch`, `Checkbox` ও `Radio`**: `switchActiveColor`, `switchInactiveColor`, `disabledColor` অনুযায়ী অটো থিমড।
- **`NavigationBar` ও `NavigationRail`**: `navBarColor`, `navSelectedColor`, `navUnselectedColor` ও `selectedItemColor`।
- **`Chip`, `Tooltip` ও `SnackBar`**: `chipColor`, `tooltipColor`/`tooltipTextColor` এবং `snackbarColor`/`snackbarTextColor` অটো থিমড।

---

## ৫. যেকোনো বাকি উপাদান আগে থেকেই গ্লোবালি থিম করা (`customizer`)

`TextField`, `TextButton`, `Chip`, `Switch`, `Checkbox`, `Radio`, `Tooltip`, `BottomSheet`, `NavigationBar` এবং `SnackBar` এখন **আগে থেকেই অটো-থিমড**! তবু বিশেষ কোনো উইজেট (যেমন `FloatingActionButton` বা কাস্টম `BottomSheet.showDragHandle`) গ্লোবালি বদলাতে চাইলে `customizer` ব্যবহার করুন:

```dart
OmniApp.material(
  omniTheme: OmniTheme(
    seedColor: Colors.indigo,
    style: OmniThemeStyle.outlined,
    customizer: (base, device, tokens) {
      return base.copyWith(
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: tokens.cardBorderRadius),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          showDragHandle: true,
        ),
        navigationBarTheme: base.navigationBarTheme.copyWith(
          height: device == OmniDeviceType.mobile ? 68 : 72,
        ),
      );
    },
  ),
  routes: [...],
)
```

> **লক্ষ্য করুন:** `customizer` প্রতিবার `build`-এ চলে না — এটি কেবল **ডিভাইস টিয়ার (`mobile`/`tablet`/`desktop`) বদলালে একবারই** চলে এবং ফল মেমোইজড থাকে।

---

## ৬. সহজ কালার, টেক্সট স্টাইল ও স্টাইল সিস্টেম (`context.ui`, `context.colors`, `context.textStyles`, `context.styles`)

### ৬.১. ৫৩টি পিওর কালার (`context.colors` — `OmniColors`)

Material-এর `onSurfaceVariant` বা `surfaceContainerHigh` মনে রাখার কোনো দরকার নেই! যেকোনো উইজেটে **`context.colors`** বা **`context.ui.colors`** লিখলেই সব স্পষ্ট নাম পাবেন — আর IDE-তে **যেকোনো নামের ওপর মাউস হোভার করলেই** জানতে পারবেন সেটি ঠিক কোথায় ও কেন ব্যবহার হয়:

| ক্যাটাগরি | কালার নাম (`context.colors.*`) | কী কাজে ও কোথায় ব্যবহার হয় |
|---|---|---|
| **ব্র্যান্ড** | `primaryColor` / `secondaryColor` | মূল ব্র্যান্ড হাইলাইট ও দ্বিতীয় অ্যাকসেন্ট কালার |
| **সারফেস** | `surfaceColor` / `secondaryBackgroundColor` / `cardColor` | `Scaffold` মূল ব্যাকগ্রাউন্ড, সেকশন/কোড ব্যাকগ্রাউন্ড এবং কার্ড/ডায়ালগ |
| **অ্যাপবার ও ন্যাভ** | `appBarColor` / `appBarTextColor` | উপরের `AppBar` ব্যাকগ্রাউন্ড এবং শিরোনাম/আইকন রঙ |
| **নেভিগেশন** | `navBarColor` / `navSelectedColor` / `navUnselectedColor` | নিচের `NavigationBar`/রেল ব্যাকগ্রাউন্ড, সিলেক্টেড ও আন-সিলেক্টেড ট্যাব |
| **বাটন** | `buttonColor` / `buttonTextColor` | প্রাইমারি বাটন (`FilledButton`, `ElevatedButton`) ও তার লেখা |
| **সেকেন্ডারি বাটন** | `secondaryButtonColor` / `secondaryButtonTextColor` | "Cancel", "Skip", "Back" বাটনের ব্যাকগ্রাউন্ড ও লেখা |
| **ডেঞ্জার বাটন** | `dangerButtonColor` / `dangerButtonTextColor` | "Delete", "Remove", "Logout" বাটনের লাল ব্যাকগ্রাউন্ড ও লেখা |
| **লিংক ও ইনপুট** | `linkColor` / `inputFillColor` | ক্লিকেবল লিংক টেক্সট এবং `TextField`-এর ভেতরের ফিল রঙ |
| **বর্ডার ও লাইন** | `borderColor` / `focusedBorderColor` / `dividerColor` | সাধারণ বর্ডার, ফোকাসড বর্ডার এবং সেকশন ডিভাইডার লাইন |
| **টেক্সট ও আইকন** | `textColor` / `secondaryTextColor` / `hintTextColor` / `iconColor` | মূল লেখা, সাবটাইটেল, হিন্ট টেক্সট এবং সাধারণ আইকন |
| **চিপ ও ব্যাজ** | `chipColor` / `chipTextColor` / `badgeColor` / `badgeTextColor` | ফিল্টার চিপ/ট্যাগ এবং নোটিফিকেশন কাউন্টার ব্যাজের রঙ |
| **স্টেট ও হোভার** | `selectedItemColor` / `hoverColor` / `rippleColor` | সিলেক্টেড রো হাইলাইট, ডেস্কটপ হোভার ও ট্যাপ রিপল ফিডব্যাক |
| **ডিজেবল ও কন্ট্রোল** | `disabledColor` / `disabledTextColor` / `disabledBorderColor` / `switchActiveColor` / `switchInactiveColor` | নিষ্ক্রিয় ফিল্ড/বাটন ও সুইচ/চেকবক্সের অন/অফ রঙ |
| **টোস্ট ও টুলটিপ** | `snackbarColor` / `snackbarTextColor` / `tooltipColor` / `tooltipTextColor` | নিচের `SnackBar`/টোস্ট এবং হোভার `Tooltip` পপআপ রঙ |
| **স্ট্যাটাস অ্যালার্ট** | `errorColor` / `errorBackgroundColor` / `warningColor` / `warningBackgroundColor` / `successColor` / `successBackgroundColor` / `infoColor` / `infoBackgroundColor` | এরর, সতর্কতা, সফল ও তথ্য ব্যানারের বর্ডার/আইকন ও হালকা ব্যাকগ্রাউন্ড |
| **শিমার ও ওভারলে** | `shimmerBaseColor` / `shimmerHighlightColor` / `overlayColor` / `shadowColor` | লোডিং স্কেলেটন শিমার, ডায়ালগ ব্যাকড্রপ ও কার্ড শ্যাডো |

---

### ৬.২. ১৫টি রেসপন্সিভ টেক্সট স্টাইল (`context.textStyles` — `OmniTextStyles`)

প্রতিবার `TextStyle(...)` লেখার বদলে **`final t = context.textStyles;`** বা **`context.ui.text`** লিখুন — প্রতিটি স্টাইল ডিভাইস টিয়ার অনুযায়ী অটো স্কেলড এবং লাইট/ডার্ক মোডে সঠিক কন্ট্রাস্ট পায়:

| নাম (`t.*`) | ব্যবহার ক্ষেত্র | ডিফল্ট বৈশিষ্ট্য |
|---|---|---|
| `t.display` | হিরো ব্যানার / অনবোর্ডিং বড় শিরোনাম | `tokens.displaySize`, `headingWeight` |
| `t.heading` | পেজ হেডার (`H1` / বড় সেকশন) | `tokens.headlineSize`, `headingWeight` |
| `t.title` | কার্ড, লিস্ট বা ডায়ালগের শিরোনাম | `tokens.titleSize`, `FontWeight.w600` |
| `t.subtitle` | শিরোনামের নিচের সাবটাইটেল | `tokens.bodySize + 1`, `FontWeight.w600` |
| `t.body` | স্বাভাবিক অনুচ্ছেদ ও মূল লেখা | `tokens.bodySize`, `textColor` |
| `t.bodyMuted` | হালকা বিবরণ ও সেকেন্ডারি প্যারাগ্রাফ | `tokens.bodySize`, `secondaryTextColor` |
| `t.label` | ফর্ম ফিল্ড লেবেল, ট্যাগ ও ব্যাজ | `tokens.labelSize + 1`, `FontWeight.w500` |
| `t.caption` | সময়, ফুটার, হেল্পার নোট | `tokens.labelSize`, `secondaryTextColor` |
| `t.hint` | খালি অবস্থার প্লেসহোল্ডার/হিন্ট টেক্সট | `tokens.bodySize`, `hintTextColor` |
| `t.button` | বাটনের ভেতরের লেখা | `tokens.bodySize + 0.5`, `FontWeight.w600` |
| `t.link` | ক্লিকেবল টেক্সট লিংক | `linkColor`, `FontWeight.w500` |
| `t.error` | ফর্ম ভ্যালিডেশন ও এরর মেসেজ | `labelSize`, `errorColor` |
| `t.warning` | সতর্কবার্তা টেক্সট | `labelSize`, `warningColor` |
| `t.success` | সফল/ভেরিফাইড মেসেজ টেক্সট | `labelSize`, `successColor` |
| `t.code` | OTP, ট্রানজ্যাকশন/অর্ডার কোড বা টোকেন | `monospace` |

---

### ৬.৩. `context.ui` এবং প্রি-ক্যাশড UI ডেকোরেশন ও বাটন স্টাইল (`context.styles`)

স্ক্রলিং লিস্ট বা প্রতি `build()`-এ নতুন `BoxDecoration(...)` বা `ButtonStyle(...)` অ্যালোকেট না করে **`final ui = context.ui;`** লিখলে এক জায়গাতেই সব পাবেন (`ui.colors`, `ui.text`, `ui.styles`, `ui.tokens`, `ui.isDark`, `ui.isMobile`):

- **প্রি-ক্যাশড বক্স ও কার্ড ডেকোরেশন:**
  - `cardDecoration`, `elevatedCardDecoration`, `selectedCardDecoration`
  - `subtleBoxDecoration` (`secondaryBackgroundColor`), `disabledBoxDecoration` (`disabledColor` + `disabledBorderColor`)
  - `errorBoxDecoration`, `warningBoxDecoration`, `successBoxDecoration`, `infoBoxDecoration`
  - `chipDecoration`, `badgeDecoration`
- **রেডি বাটন স্টাইল (`ButtonStyle`):**
  - `primaryButton`, `secondaryButton`, `dangerButton`, `outlineButton`, `linkButton`
- **টেক্সট ফিল্ড হেল্পার:**
  - `inputDecoration(label:, hint:, helper:, error:, prefixIcon:, suffixIcon:, enabled:)`
  - `searchDecoration(hint:, onClear:, prefixIcon:)`

```dart
final ui = context.ui; // মাত্র ১ লাইনেই সম্পূর্ণ থিম অ্যাক্সেস!

Container(
  padding: ui.tokens.cardPadding,
  decoration: ui.styles.warningBoxDecoration,
  child: Row(
    children: [
      Icon(Icons.warning_amber_rounded, color: ui.colors.warningColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'আপনার সাবস্ক্রিপশন ৩ দিনের মধ্যে শেষ হবে',
          style: ui.text.warning,
        ),
      ),
    ],
  ),
)
```

---

## ৭. কাস্টম `OmniThemeController` (অ্যাপের বাইরে বা Bloc থেকে কন্ট্রোল)

যদি Bloc, Repository বা `OmniConfig.splash.onInit`-এর ভেতর থেকে থিম মোড, কালার প্যালেট বা স্টাইল নিয়ন্ত্রণ করতে চান:

```dart
final themeController = OmniThemeController(
  initialMode: ThemeMode.system,
  initialThemeId: 'ocean',
  initialStyle: OmniThemeStyle.modern,
  persist: true,
);

// অ্যাপ শুরুতে:
OmniApp.material(
  omniTheme: OmniTheme(
    seedColor: Colors.teal,
    controller: themeController,
  ),
  themes: OmniTheme.presets,
  routes: [...],
)

// বাইরে বা ইভেন্ট থেকে:
themeController.setTheme('emerald');
themeController.setStyle(OmniThemeStyle.outlined);
themeController.useDark();
themeController.useLight();
themeController.useSystem();
themeController.toggle();
await themeController.resetSavedMode(); // সেভ করা পছন্দ মুছে ডিফল্টে ফেরা
```

*(নোট: নিজে কন্ট্রোলার তৈরি করলে প্রয়োজন শেষে সেটি `dispose()` করবেন; আর না দিলে `OmniApp` নিজেই তৈরি ও ডিসপোজ করে — মেমরি লিক হওয়ার কোনো সুযোগ নেই।)*

---

## ৮. পারফরম্যান্স ও মেমরি নীতি (`0` এক্সট্রা রি-বিল্ড)

1. **Memoized `ThemeData`, `OmniTextStyles` ও `OmniStyles`:** `OmniResponsiveThemeHost` শুধু ব্রেকপয়েন্ট টিয়ার (`mobile` ↔ `tablet` ↔ `desktop`) বা থিম/স্টাইল বদলালেই একবারে সব কালার, টেক্সট স্টাইল, বক্স ডেকোরেশন ও বাটন স্টাইল ক্যাশ করে রাখে। একবার ভিজিট করা প্যালেট বা উইন্ডো রিসাইজে একই ইনস্ট্যান্স রিটার্ন হয়।
2. **মোড টগলে ন্যূনতম কাজ:** `Dark ↔ Light ↔ System` টগল করলে নতুন `ThemeData` রিকম্পিউট হয় না; শুধু `MaterialApp`-এর `themeMode` বদলায় এবং `const` চাইল্ড উইজেটগুলো রি-বিল্ড হয় না।
3. **কোনো কিবোর্ড জ্যাঙ্ক নেই:** কীবোর্ড উঠা-নামায় (`viewInsets`) `OmniTheme` বা `OmniResponsiveScope` কেউই ট্রিগার হয় না।

---

## ৯. পূর্ণাঙ্গ ব্যবহারিক উদাহরণ (Login + Settings + Palette Sheet + Form)

```dart
import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OmniApp.material(
      title: 'OmniTheme Demo',
      omniTheme: const OmniTheme(
        id: 'ocean',
        name: 'Ocean',
        seedColor: Color(0xFF2563EB),
        style: OmniThemeStyle.outlined,
        mode: ThemeMode.system,
        persistMode: true,
      ),
      themes: OmniTheme.presets, // ৮টি রেডি কালার প্যালেট!
      routes: [
        OmniPage('/', (_) => const DemoFormPage()),
      ],
    );
  }
}

class DemoFormPage extends StatelessWidget {
  const DemoFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui; // colors, text, styles, tokens সব এক জায়গায়!

    return Scaffold(
      appBar: AppBar(
        title: const Text('থিমিং ডেমো'),
        actions: const [
          OmniThemeButton(),                          // ১ ক্লিকে কালার প্যালেট বদলান!
          OmniThemeModeButton(allowSystemMode: true), // ১ ক্লিকে System/Light/Dark!
        ],
      ),
      body: SingleChildScrollView(
        child: OmniResponsiveContainer(
          maxWidth: 560,
          child: Padding(
            padding: ui.tokens.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: ui.styles.searchDecoration(hint: 'ফিচার খুঁজুন...'),
                ),
                ui.tokens.gapMd,
                Container(
                  padding: ui.tokens.cardPadding,
                  decoration: ui.styles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('অ্যাকাউন্টে প্রবেশ করুন', style: ui.text.heading),
                      ui.tokens.gapXs,
                      Text(
                        'আপনার নিবন্ধিত ইমেইল ও পাসওয়ার্ড দিন',
                        style: ui.text.bodyMuted,
                      ),
                      ui.tokens.gapMd,
                      Container(
                        padding: ui.tokens.cardPadding,
                        decoration: ui.styles.warningBoxDecoration,
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, color: ui.colors.warningColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'নিরাপত্তার জন্য শক্তিশালী পাসওয়ার্ড দিন',
                                style: ui.text.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ui.tokens.gapMd,
                      TextField(
                        decoration: ui.styles.inputDecoration(
                          label: 'ইমেইল',
                          hint: 'you@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      ui.tokens.gapSm,
                      TextField(
                        obscureText: true,
                        decoration: ui.styles.inputDecoration(
                          label: 'পাসওয়ার্ড',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      ui.tokens.gapMd,
                      FilledButton(
                        onPressed: () {},
                        child: const Text('লগইন'),
                      ),
                      ui.tokens.gapSm,
                      FilledButton(
                        style: ui.styles.secondaryButton,
                        onPressed: () {},
                        child: const Text('পরে প্রবেশ করুন'),
                      ),
                      ui.tokens.gapSm,
                      FilledButton(
                        style: ui.styles.dangerButton,
                        onPressed: () {},
                        child: const Text('অ্যাকাউন্ট মুছুন'),
                      ),
                    ],
                  ),
                ),
                ui.tokens.gapLg,
                const OmniThemeSettingsTile(
                  title: 'থিম ও কালার প্যালেট',
                  sheetTitle: 'অ্যাপিয়ারেন্স সেটিংস',
                  systemLabel: 'সিস্টেম',
                  lightLabel: 'লাইট',
                  darkLabel: 'ডার্ক',
                ),
                ui.tokens.gapSm,
                const OmniThemePanel(
                  modeTitle: 'থিম মোড',
                  themeTitle: '১ ক্লিকে কালার প্যালেট পাল্টান',
                  styleTitle: 'ডিজাইন স্টাইল',
                  systemLabel: 'সিস্টেম',
                  lightLabel: 'লাইট',
                  darkLabel: 'ডার্ক',
                  showStylePicker: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```
