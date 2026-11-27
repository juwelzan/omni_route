# OmniTheme — পূর্ণাঙ্গ বাংলা থিমিং গাইড (Dark/Light, TextField, Button ও Custom Setup)

> আলাদা `ThemeBloc`, `ChangeNotifier` বা `SharedPreferences` বয়লারপ্লেট ছাড়াই কীভাবে `OmniRoute`-এ পুরো অ্যাপের **রঙ, ডার্ক/লাইট/সিস্টেম মোড, অটো-সেভ, `TextField`, `Button`, `Card` ও যেকোনো কাস্টম উইজেট** আগে থেকেই সেটআপ ও ব্যবহার করবেন — এই ডকে ধাপে ধাপে উদাহরণসহ দেখানো হয়েছে।

> মূল গাইড: [doc/guide.bn.md](guide.bn.md) · প্রজেক্ট ওভারভিউ: [README.md](../README.md)

---

## সূচিপত্র

1. [১ মিনিটে শুরু — সবচেয়ে সহজ সেটআপ](#১-১-মিনিটে-শুরু--সবচেয়ে-সহজ-সেটআপ)
2. [আগে থেকেই থিম সেটআপ করা (`OmniTheme` সব প্যারামিটার ও প্রিসেট)](#২-আগে-থেকেই-থিম-সেটআপ-করা-omnitheme-সব-প্যারামিটার-ও-প্রিসেট)
3. [Dark / Light / System মোড নিয়ন্ত্রণ ও অটো-সেভ](#৩-dark--light--system-মোড-নিয়ন্ত্রণ-ও-অটো-সেভ)
4. [আগে থেকেই কোন কোন উইজেট থিমড থাকে (`TextField`, `Button`, `Card`, `NavigationBar`)](#৪-আগে-থেকেই-কোন-কোন-উইজেট-থিমড-থাকে-textfield-button-card-navigationbar)
5. [যেকোনো বাকি উপাদান আগে থেকেই গ্লোবালি থিম করা (`customizer`)](#৫-যেকোনো-বাকি-উপাদান-আগে-থেকেই-গ্লোবালি-থিম-করা-customizer)
6. [সহজ কালার, টেক্সট স্টাইল ও স্টাইল সিস্টেম (`context.colors`, `context.textStyles`, `context.styles`)](#৬-সহজ-কালার-টেক্সট-স্টাইল-ও-স্টাইল-সিস্টেম-contextcolors-contexttextstyles-contextstyles)
7. [কাস্টম `OmniThemeController` (অ্যাপের বাইরে বা Bloc থেকে কন্ট্রোল)](#৭-কাস্টম-omnithemecontroller-অ্যাপের-বাইরে-বা-bloc-থেকে-কন্ট্রোল)
8. [পারফরম্যান্স ও মেমরি নীতি (`0` এক্সট্রা রি-বিল্ড)](#৮-পারফরম্যান্স-ও-মেমরি-নীতি-0-এক্সট্রা-রি-বিল্ড)
9. [পূর্ণাঙ্গ ব্যবহারিক উদাহরণ (Login + Settings + Form)](#৯-পূর্ণাঙ্গ-ব্যবহারিক-উদাহরণ-login--settings--form)

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

### খ. একাধিক থিম (`themes:`) দিয়ে ১-ক্লিকে পুরো অ্যাপের থিম পরিবর্তন:
```dart
OmniApp.material(
  title: 'Multi-Theme App',
  // রেডিমেড ৫টি থিম (`Ocean`, `Emerald`, `Sunset`, `Rose`, `Slate`),
  // অথবা নিজের তৈরি লিস্ট [OmniTheme(id: 'my_blue', name: 'নীল', ...), ...] দিন!
  themes: OmniTheme.presets,
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
  ],
)
```

একটি বাটন থেকেই ১ ক্লিকে থিম বা মোড পাল্টে দিন:
- `AppBar` বাটনে: **`const OmniThemeButton()`** (১ ক্লিকে থিম পাল্টায়) ও **`const OmniThemeModeButton()`** (১ ক্লিকে লাইট/ডার্ক পাল্টায়)
- Settings পেজে: **`const OmniThemePanel()`** (একসাথে Dark/Light সুইচ + কালার থিম চিপ পিকার)
- কোড থেকে: **`context.nextTheme()`**, **`context.setTheme('emerald')`**, **`context.toggleTheme()`**

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
| `mode` | `ThemeMode = ThemeMode.system` | প্রথমবার অ্যাপ চালু হলে কোন মোড দেখাবে |
| `persistMode` | `bool = true` | `SharedPreferences`-এ ইউজারের পছন্দের থিম ও মোড সেভ রাখবে কি না |
| `storageKey` | `String = 'default'` | সেভ করার চাবি (একাধিক অ্যাপ বা প্রোফাইল আলাদা রাখতে) |
| `controller` | `OmniThemeController? = null` | বাইরে থেকে মোড/থিম পাল্টাতে চাইলে নিজের কন্ট্রোলার দিন |
| `fontFamily` | `String? = null` | পুরো অ্যাপের ডিফল্ট ফন্ট (যেমন `'HindSiliguri'`) |
| `headingWeight` | `FontWeight = FontWeight.w700` | `display`, `heading`, `title` ও হেডিংগুলোর ডিফল্ট ফন্ট ওয়েট |
| `borderRadius` | `double? = null` | কার্ড, বাটন ও ইনপুটের কর্নার রেডিয়াস একসাথে ঠিক করতে (`dialog` পায় `+2`) |
| `inputVariant` | `OmniInputVariant = .filled` | সব `TextField`-এর ডিফল্ট ধরন (`.filled`, `.outlined`, `.underlined`) |
| `borderWidth` | `double = 1.0` | সাধারণ অবস্থায় ইনপুট, চিপ ও আউটলাইন বাটনের বর্ডার পুরুত্ব |
| `focusedBorderWidth` | `double = 1.8` | ইনপুট ফোকাস বা এরর অবস্থায় বর্ডার পুরুত্ব |
| `cardBorderWidth` | `double = 1.0` | কার্ডের বর্ডার পুরুত্ব (`0` দিলে বর্ডার ছাড়া ফ্ল্যাট কার্ড হয়) |
| `cardElevation` | `double = 0` | `Card`-এর শ্যাডো উচ্চতা (`0` = ফ্ল্যাট মডার্ন) |
| `appBarCenterTitle` | `bool? = null` | `true`/`false` করলে সব পেজের `AppBar` টাইটেল সেন্টার বা বামে থাকে |
| `useMaterial3` | `bool = true` | Material 3 ডিজাইন সিস্টেম চালু রাখে |
| `customizer` | `OmniThemeCustomizer?` | বিশেষ কোনো অতিরিক্ত উইজেট কাস্টম করার হুক |

### গ. সহজ কালার ওভাররাইড (ঐচ্ছিক — না দিলে `seedColor` থেকেই অটো তৈরি হয়)

- **সারফেস ও কার্ড:** `surfaceColor`, `darkSurfaceColor`, `cardColor`, `darkCardColor`, `dividerColor` *(পুরোনো `scaffoldBackgroundColor` ও সমর্থিত)*
- **অ্যাপবার ও নেভিগেশন:** `appBarColor`, `appBarTextColor`, `navBarColor`, `navSelectedColor`, `navUnselectedColor`
- **বাটন ও লিংক:** `buttonColor`, `buttonTextColor`, `secondaryButtonColor`, `secondaryButtonTextColor`, `dangerButtonColor`, `dangerButtonTextColor`, `linkColor`
- **ইনপুট, বর্ডার ও টেক্সট:** `inputFillColor`, `borderColor`, `focusedBorderColor`, `textColor`, `secondaryTextColor`, `hintTextColor`, `iconColor`
- **চিপ, ব্যাজ ও স্টেট:** `chipColor`, `chipTextColor`, `badgeColor`, `badgeTextColor`, `selectedItemColor`, `hoverColor`, `disabledColor`, `disabledTextColor`
- **স্ট্যাটাস, শিমার ও শ্যাডো:** `errorColor`, `warningColor`, `successColor`, `infoColor`, `shimmerBaseColor`, `shimmerHighlightColor`, `overlayColor`, `shadowColor`
- **সম্পূর্ণ কাস্টম প্যালেট:** চাইলে `lightColors:` এবং `darkColors:`-এ সরাসরি `OmniColors(...)` দিতে পারেন।

### ঘ. একটি পূর্ণ-কনফিগার করা উদাহরণ

```dart
const appTheme = OmniTheme(
  id: 'clinic_teal',
  name: 'Clinic Teal',
  seedColor: Color(0xFF0F766E),
  secondaryColor: Color(0xFFF59E0B),
  dangerButtonColor: Color(0xFFDC2626),
  mode: ThemeMode.system,
  persistMode: true,
  fontFamily: 'HindSiliguri',
  headingWeight: FontWeight.w800,
  borderRadius: 12,
  inputVariant: OmniInputVariant.outlined,
  borderWidth: 1.0,
  focusedBorderWidth: 1.8,
  cardBorderWidth: 1.0,
  surfaceColor: Color(0xFFF8FAFC),
  darkSurfaceColor: Color(0xFF0B1120),
  cardElevation: 0,
  appBarCenterTitle: false,
);
```

---

## ৩. Dark / Light / System মোড নিয়ন্ত্রণ ও অটো-সেভ

### ক. ১-লাইনের রেডিমেড উইজেট

1. **`AppBar`-এ ১-ট্যাপ বাটন (`OmniThemeModeButton`):**

```dart
AppBar(
  title: const Text('Dashboard'),
  actions: const [
    OmniThemeModeButton(), // লাইট <-> ডার্ক টগল করে (শুধু নিজেকেই রি-বিল্ড করে)
    // ৩-স্টেট চাইলে: OmniThemeModeButton(allowSystemMode: true),
  ],
)
```

- ঐচ্ছিক প্যারামিটার: `allowSystemMode: false`, `lightIcon`, `darkIcon`, `systemIcon`, `tooltip`।

2. **`Settings` পেজে ৩-অপশন সুইচ (`OmniThemeModeSwitch`):**

```dart
const OmniThemeModeSwitch(
  systemLabel: 'অটো',
  lightLabel: 'লাইট',
  darkLabel: 'ডার্ক',
  showIcons: true,
)
```

### খ. কোড থেকে যেকোনো বাটন/ইভেন্টে মোড পরিবর্তন

```dart
// ডার্ক <-> লাইট পাল্টান (onPressed / কলব্যাকে নিরাপদ):
ElevatedButton(
  onPressed: () => context.toggleTheme(),
  child: Text(context.isDarkMode ? 'লাইট মোড দিন' : 'ডার্ক মোড দিন'),
)

// নির্দিষ্ট মোড সেট করুন:
context.setThemeMode(ThemeMode.dark);
context.setThemeMode(ThemeMode.light);
context.setThemeMode(ThemeMode.system);

// system -> light -> dark -> system ঘোরান:
context.cycleThemeMode();

// বর্তমান মোড পড়ুন (শুধু মোড বদলালেই এই উইজেট রি-বিল্ড হবে):
final mode = context.themeMode;
```

> **নোট:** `persistMode: true` থাকলে মোড পরিবর্তন করামাত্রই ব্যাকগ্রাউন্ডে `SharedPreferences`-এ (`omni_route.theme.<storageKey>.mode`) সেভ হয়ে যায়। অ্যাপ ব্যাকগ্রাউন্ড থেকে ক্লিয়ার করে আবার খুললেও সেই মোডেই অ্যাপ চালু হবে।

---

## ৪. আগে থেকেই কোন কোন উইজেট থিমড থাকে (`TextField`, `Button`, `Card`, `NavigationBar`)

`OmniTheme` প্রতি ডিভাইস টিয়ার অনুযায়ী (`smallPhone`, `mobile`, `tablet`, `desktop`, `largeDesktop`) আগে থেকেই নিচের উপাদানগুলো সাজিয়ে দেয় — তাই স্ক্রিনের ভেতর প্রতিবার আলাদা স্টাইল লেখার দরকার পড়ে না:

### ক. `TextField`, `TextFormField` ও ৩টি `OmniInputVariant`

`OmniTheme(inputVariant: ...)` দিয়ে এক লাইনে পুরো অ্যাপের সব টেক্সট ফিল্ডের স্টাইল ঠিক করতে পারবেন:

| ভ্যারিয়েন্ট (`OmniInputVariant`) | দেখতে কেমন | কখন ভালো মানায়? |
|---|---|---|
| `OmniInputVariant.filled` *(ডিফল্ট)* | নরম ব্যাকগ্রাউন্ড (`inputFillColor`) + সূক্ষ্ম বর্ডার | সাধারণ মোবাইল ও কনজিউমার অ্যাপ |
| `OmniInputVariant.outlined` | ট্রান্সপারেন্ট ফিল + চারদিকে পরিষ্কার বর্ডার | ফর্ম-প্রধান, ড্যাশবোর্ড ও SaaS অ্যাপ |
| `OmniInputVariant.underlined` | ফিল ছাড়া শুধু নিচে লাইন বর্ডার | মিনিমাল/রিডার-ফোকাসড প্রোফাইল ফর্ম |

**স্ক্রিনে যেভাবে লিখবেন (একদম কম কোডে):**

```dart
final s = context.styles;

// ১. সাধারণ স্ট্যান্ডার্ড TextField (Theme-এর inputVariant অটো নেয়):
TextField(
  decoration: s.inputDecoration(
    label: 'ইমেইল',
    hint: 'you@example.com',
    prefixIcon: const Icon(Icons.email_outlined),
  ),
)

// ২. রেডি পিল-আকৃতির সার্চ বার:
TextField(
  decoration: s.searchDecoration(
    hint: 'পণ্য খুঁজুন...',
    onClear: () {},
  ),
)
```

### খ. বাটন (`FilledButton`, `ElevatedButton`, `OutlinedButton`, `TextButton` + `Secondary` / `Danger`)

**আগে থেকে কী সেট থাকে:**
- `minimumSize`: `Size(0, tokens.minTapTarget)` — মোবাইলে `48dp`, ট্যাবলেটে `44dp`, ডেস্কটপে `40dp`।
- `shape`: `RoundedRectangleBorder` (`borderRadius` অথবা `tokens.buttonBorderRadius`) এবং টেক্সট স্টাইল `textStyles.button`।
- পাশাপাশি **`context.styles`**-এ `secondaryButton` ("Cancel"/"Later") ও `dangerButton` ("Delete"/"Logout") রেডি অবস্থায় থাকে!

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

// ৪. আউটলাইন ও লিংক বাটন
OutlinedButton(onPressed: () {}, child: const Text('বাতিল'))
TextButton(onPressed: () {}, child: const Text('পাসওয়ার্ড ভুলে গেছেন?'))
```

### গ. কার্ড, ডায়ালগ, বটমশিট, স্ন্যাকবার ও নেভিগেশন

- **`Card`**: `color: cardColor`, `shadowColor`, `elevation: cardElevation`, বর্ডার (`cardBorderWidth`), কর্নার `tokens.cardBorderRadius`।
- **`Dialog` ও `BottomSheet`**: থিম অনুযায়ী `cardColor`, ব্যাকড্রপ স্ক্রিন ডার্কেন (`overlayColor`), গোল কর্নার।
- **`NavigationBar` ও `NavigationRail`**: `navBarColor`, `navSelectedColor`, `navUnselectedColor`, এবং হাইলাইট পিল `selectedItemColor` অটো সেট থাকে।
- **`Chip` ও `SnackBar`**: `chipColor`, `chipTextColor` এবং ফ্লোটিং স্ন্যাকবার স্টাইল অটো থিমড।

---

## ৫. যেকোনো বাকি উপাদান আগে থেকেই গ্লোবালি থিম করা (`customizer`)

`TextField`, `TextButton`, `Chip`, `BottomSheet`, `NavigationBar` এবং `SnackBar` এখন **আগে থেকেই অটো-থিমড**! তবু বিশেষ কোনো উইজেট (যেমন `FloatingActionButton`, `Switch`, `BottomSheet.showDragHandle`, বা কাস্টম `NavigationBar.height`) গ্লোবালি বদলাতে চাইলে `customizer` ব্যবহার করুন:

```dart
OmniApp.material(
  omniTheme: OmniTheme(
    seedColor: Colors.indigo,
    inputVariant: OmniInputVariant.outlined,
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

## ৬. সহজ কালার, টেক্সট স্টাইল ও স্টাইল সিস্টেম (`context.colors`, `context.textStyles`, `context.styles`)

### ৬.১. ৪৪টি পিওর কালার (`context.colors` — `OmniColors`)

Material-এর `onSurfaceVariant` বা `surfaceContainerHigh` মনে রাখার কোনো দরকার নেই! যেকোনো উইজেটে **`context.colors`** লিখলেই সব স্পষ্ট নাম পাবেন — আর IDE-তে **যেকোনো নামের ওপর মাউস হোভার করলেই** জানতে পারবেন সেটি ঠিক কোথায় ও কেন ব্যবহার হয়:

| ক্যাটাগরি | কালার নাম (`context.colors.*`) | কী কাজে ও কোথায় ব্যবহার হয় |
|---|---|---|
| **ব্র্যান্ড** | `primaryColor` / `secondaryColor` | মূল ব্র্যান্ড হাইলাইট ও দ্বিতীয় অ্যাকসেন্ট কালার |
| **সারফেস** | `surfaceColor` / `cardColor` | পেজের মূল ব্যাকগ্রাউন্ড (`Scaffold`) ও কার্ড/ডায়ালগ/বক্স |
| **অ্যাপবার ও ন্যাভ** | `appBarColor` / `appBarTextColor` | উপরের `AppBar` ব্যাকগ্রাউন্ড এবং টাইটেল/আইকন রঙ |
| **নেভিগেশন** | `navBarColor` / `navSelectedColor` / `navUnselectedColor` | নিচের `NavigationBar`/রেল ব্যাকগ্রাউন্ড, সিলেক্টেড ও আন-সিলেক্টেড ট্যাব |
| **বাটন** | `buttonColor` / `buttonTextColor` | প্রাইমারি বাটন (`FilledButton`, `ElevatedButton`) ও তার লেখা |
| **সেকেন্ডারি বাটন** | `secondaryButtonColor` / `secondaryButtonTextColor` | "Cancel", "Skip", "Back" বাটনের ব্যাকগ্রাউন্ড ও লেখা |
| **ডেঞ্জার বাটন** | `dangerButtonColor` / `dangerButtonTextColor` | "Delete", "Remove", "Logout" বাটনের লাল ব্যাকগ্রাউন্ড ও লেখা |
| **লিংক ও ইনপুট** | `linkColor` / `inputFillColor` | ক্লিকেবল লিংক টেক্সট এবং `TextField`-এর ভেতরের ফিল রঙ |
| **বর্ডার ও লাইন** | `borderColor` / `focusedBorderColor` / `dividerColor` | সাধারণ বর্ডার, ফোকাসড বর্ডার এবং সেকশন ডিভাইডার লাইন |
| **টেক্সট ও আইকন** | `textColor` / `secondaryTextColor` / `hintTextColor` / `iconColor` | মূল লেখা, সাবটাইটেল, হিন্ট টেক্সট এবং সাধারণ আইকন |
| **চিপ ও ব্যাজ** | `chipColor` / `chipTextColor` / `badgeColor` / `badgeTextColor` | ফিল্টার চিপ/ট্যাগ এবং নোটিফিকেশন কাউন্টার ব্যাজের রঙ |
| **স্টেট ও হোভার** | `selectedItemColor` / `hoverColor` / `disabledColor` / `disabledTextColor` | সিলেক্টেড রো হাইলাইট, ডেস্কটপ হোভার ও নিষ্ক্রিয় এলিমেন্ট |
| **স্ট্যাটাস অ্যালার্ট** | `errorColor` / `errorBackgroundColor` / `warningColor` / `warningBackgroundColor` / `successColor` / `successBackgroundColor` / `infoColor` / `infoBackgroundColor` | এরর, সতর্কতা, সফল ও তথ্য ব্যানারের বর্ডার/আইকন ও হালকা ব্যাকগ্রাউন্ড |
| **শিমার ও ওভারলে** | `shimmerBaseColor` / `shimmerHighlightColor` / `overlayColor` / `shadowColor` | লোডিং স্কেলেটন শিমার, ডায়ালগ ব্যাকড্রপ ও কার্ড শ্যাডো |

---

### ৬.২. ১৫টি রেসপন্সিভ টেক্সট স্টাইল (`context.textStyles` — `OmniTextStyles`)

প্রতিবার `TextStyle(fontSize: ..., fontWeight: ..., color: ...)` লেখার বদলে **`final t = context.textStyles;`** লিখুন — প্রতিটি স্টাইল ডিভাইস টিয়ার অনুযায়ী অটো স্কেলড এবং লাইট/ডার্ক মোডে সঠিক কন্ট্রাস্ট পায়:

| নাম (`t.*`) | ব্যবহার ক্ষেত্র | ডিফল্ট সাইজ/বৈশিষ্ট্য |
|---|---|---|
| `t.display` | হিরো ব্যানার / অনবোর্ডিং বড় শিরোনাম | `tokens.displaySize`, `headingWeight` |
| `t.heading` | পেজ হেডার (`H1` / বড় সেকশন) | `tokens.headlineSize`, `headingWeight` |
| `t.title` | কার্ড, লিস্ট বা ডায়ালগের শিরোনাম | `tokens.titleSize`, `FontWeight.w600` |
| `t.subtitle` | শিরোনামের নিচের সাবটাইটেল | `tokens.bodySize + 1`, `secondaryTextColor` |
| `t.body` | স্বাভাবিক অনুচ্ছেদ ও মূল লেখা | `tokens.bodySize`, `textColor` |
| `t.bodyMuted` | হালকা বিবরণ ও সেকেন্ডারি প্যারাগ্রাফ | `tokens.bodySize`, `secondaryTextColor` |
| `t.label` | ফর্ম ফিল্ড লেবেল, ট্যাগ ও ব্যাজ | `tokens.labelSize`, `FontWeight.w600` |
| `t.caption` | সময়, ফুটার, হেল্পার নোট | `tokens.labelSize - 1`, `secondaryTextColor` |
| `t.hint` | খালি অবস্থার প্লেসহোল্ডার/হিন্ট টেক্সট | `tokens.bodySize`, `hintTextColor` |
| `t.button` | বাটনের ভেতরের লেখা | `tokens.bodySize`, `FontWeight.w600` |
| `t.link` | ক্লিকেবল টেক্সট লিংক | `linkColor`, আন্ডারলাইন ও `FontWeight.w600` |
| `t.error` | ফর্ম ভ্যালিডেশন ও এরর মেসেজ | `labelSize`, `errorColor` |
| `t.warning` | সতর্কবার্তা টেক্সট | `labelSize`, `warningColor` |
| `t.success` | সফল/ভেরিফাইড মেসেজ টেক্সট | `labelSize`, `successColor` |
| `t.code` | OTP, ট্রানজ্যাকশন/অর্ডার কোড বা টোকেন | `monospace` (`tabularFigures`) |

---

### ৬.৩. প্রি-ক্যাশড UI ডেকোরেশন ও বাটন স্টাইল (`context.styles` — `OmniStyles`)

স্ক্রলিং লিস্ট বা প্রতি `build()`-এ নতুন `BoxDecoration(...)` বা `ButtonStyle(...)` অ্যালোকেট না করে সরাসরি **`final s = context.styles;`** ব্যবহার করুন — এতে মেমরি প্রেশার শূন্য থাকে:

- **প্রি-ক্যাশড বক্স ও কার্ড ডেকোরেশন:**
  - `s.cardDecoration` (স্বাভাবিক কার্ড: `cardColor`, `borderColor`, `cardRadius`)
  - `s.elevatedCardDecoration` (হালকা ড্রপ-শ্যাডোযুক্ত কার্ড)
  - `s.selectedCardDecoration` (সিলেক্টেড কার্ড: `selectedItemColor` + `primaryColor` বর্ডার)
  - `s.errorBoxDecoration`, `s.warningBoxDecoration`, `s.successBoxDecoration`, `s.infoBoxDecoration`
  - `s.chipDecoration` (ট্যাগ/ফিল্টার কন্টেইনার), `s.badgeDecoration` (পিল কাউন্টার ব্যাজ)
- **রেডি বাটন স্টাইল (`ButtonStyle`):**
  - `s.primaryButton`, `s.secondaryButton`, `s.dangerButton`, `s.outlineButton`, `s.linkButton`
- **টেক্সট ফিল্ড হেল্পার:**
  - `s.inputDecoration(label:, hint:, helper:, error:, prefixIcon:, suffixIcon:)`
  - `s.searchDecoration(hint:, onClear:, prefixIcon:)`

```dart
final t = context.textStyles;
final s = context.styles;

Container(
  padding: context.tokens.cardPadding,
  decoration: s.warningBoxDecoration, // আর প্রতিবার BoxDecoration বানাতে হবে না!
  child: Row(
    children: [
      Icon(Icons.warning_amber_rounded, color: s.colors.warningColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'আপনার সাবস্ক্রিপশন ৩ দিনের মধ্যে শেষ হবে',
          style: t.warning,
        ),
      ),
    ],
  ),
)
```

- শুধু ইমেজ বা লোগো বদলাতে চাইলে `context.isDarkMode` ব্যবহার করুন:

```dart
Image.asset(
  context.isDarkMode ? 'assets/logo_dark.png' : 'assets/logo_light.png',
)
```

---

## ৭. কাস্টম `OmniThemeController` (অ্যাপের বাইরে বা Bloc থেকে কন্ট্রোল)

যদি Bloc, Repository বা `OmniConfig.splash.onInit`-এর ভেতর থেকে থিম মোড নিয়ন্ত্রণ করতে চান:

```dart
final themeController = OmniThemeController(
  initialMode: ThemeMode.system,
  persist: true,
);

// অ্যাপ শুরুতে:
OmniApp.material(
  omniTheme: OmniTheme(
    seedColor: Colors.teal,
    controller: themeController,
  ),
  routes: [...],
)

// বাইরে বা ইভেন্ট থেকে:
themeController.useDark();
themeController.useLight();
themeController.useSystem();
themeController.toggle();
await themeController.resetSavedMode(); // সেভ করা পছন্দ মুছে ডিফল্টে ফেরা
```

*(নোট: নিজে কন্ট্রোলার তৈরি করলে প্রয়োজন শেষে সেটি `dispose()` করবেন; আর না দিলে `OmniApp` নিজেই তৈরি ও ডিসপোজ করে — মেমরি লিক হওয়ার কোনো সুযোগ নেই।)*

---

## ৮. পারফরম্যান্স ও মেমরি নীতি (`0` এক্সট্রা রি-বিল্ড)

1. **Memoized `ThemeData`, `OmniTextStyles` ও `OmniStyles`:** `OmniResponsiveThemeHost` শুধু ব্রেকপয়েন্ট টিয়ার (`mobile` ↔ `tablet` ↔ `desktop`) বদলালেই একবারে সব কালার, টেক্সট স্টাইল, বক্স ডেকোরেশন ও বাটন স্টাইল ক্যাশ করে রাখে। উইন্ডো রিসাইজে একই ইনস্ট্যান্স রিটার্ন হয়।
2. **মোড টগলে ন্যূনতম কাজ:** `Dark ↔ Light` টগল করলে নতুন `ThemeData` রিকম্পিউট হয় না; শুধু `MaterialApp`-এর `themeMode` বদলায় এবং `const` চাইল্ড উইজেটগুলো রি-বিল্ড হয় না।
3. **কোনো কিবোর্ড জ্যাঙ্ক নেই:** কীবোর্ড উঠা-নামায় (`viewInsets`) `OmniTheme` বা `OmniResponsiveScope` কেউই ট্রিগার হয় না।

---

## ৯. পূর্ণাঙ্গ ব্যবহারিক উদাহরণ (Login + Settings + Form)

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
      omniTheme: OmniTheme(
        id: 'brand',
        name: 'Brand Indigo',
        seedColor: const Color(0xFF2563EB),
        inputVariant: OmniInputVariant.outlined,
        headingWeight: FontWeight.w800,
        warningColor: const Color(0xFFD97706),
        errorColor: const Color(0xFFDC2626),
        dangerButtonColor: const Color(0xFFDC2626),
        mode: ThemeMode.system,
        persistMode: true,
        customizer: (base, device, _) => base.copyWith(
          navigationBarTheme: base.navigationBarTheme.copyWith(
            height: device == OmniDeviceType.mobile ? 68 : 72,
          ),
        ),
      ),
      themes: OmniTheme.presets, // Ocean, Emerald, Sunset, Rose, Slate যুক্ত!
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
    final tk = context.tokens;
    final c = context.colors;
    final t = context.textStyles;
    final s = context.styles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('থিমিং ডেমো'),
        actions: const [
          OmniThemeButton(),     // ১ ক্লিকে পরের কালার থিমে যান!
          OmniThemeModeButton(allowSystemMode: true),
        ],
      ),
      body: SingleChildScrollView(
        child: OmniResponsiveContainer(
          maxWidth: 560,
          child: Padding(
            padding: tk.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: s.searchDecoration(hint: 'ফিচার খুঁজুন...'),
                ),
                tk.gapMd,
                Container(
                  padding: tk.cardPadding,
                  decoration: s.cardDecoration, // প্রি-ক্যাশড কার্ড বর্ডার ও রঙ!
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('অ্যাকাউন্টে প্রবেশ করুন', style: t.heading),
                      tk.gapXs,
                      Text('আপনার নিবন্ধিত ইমেইল ও পাসওয়ার্ড দিন', style: t.bodyMuted),
                      tk.gapMd,
                      Container(
                        padding: tk.cardPadding,
                        decoration: s.warningBoxDecoration,
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, color: c.warningColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'নিরাপত্তার জন্য শক্তিশালী পাসওয়ার্ড দিন',
                                style: t.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      tk.gapMd,
                      TextField(
                        decoration: s.inputDecoration(
                          label: 'ইমেইল',
                          hint: 'you@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      tk.gapSm,
                      TextField(
                        obscureText: true,
                        decoration: s.inputDecoration(
                          label: 'পাসওয়ার্ড',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      tk.gapMd,
                      FilledButton(
                        onPressed: () {},
                        child: const Text('লগইন'),
                      ),
                      tk.gapSm,
                      FilledButton(
                        style: s.secondaryButton,
                        onPressed: () {},
                        child: const Text('পরে প্রবেশ করুন'),
                      ),
                      tk.gapSm,
                      FilledButton(
                        style: s.dangerButton,
                        onPressed: () {},
                        child: const Text('অ্যাকাউন্ট মুছুন'),
                      ),
                    ],
                  ),
                ),
                tk.gapLg,
                const OmniThemePanel(
                  modeTitle: 'ডার্ক/লাইট মোড',
                  themeTitle: '১ ক্লিকে অ্যাপের থিম পাল্টান',
                  systemLabel: 'অটো',
                  lightLabel: 'লাইট',
                  darkLabel: 'ডার্ক',
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
