# OmniRoute Localization — একদম সহজ “Zero-Boilerplate” লোকালাইজেশন প্রস্তাবনা (রিভিউ)

আপনার নির্দেশনা অনুযায়ী — **“কোনো অতিরিক্ত ফাইল বা জটিল কী-স্ট্রিং ছাড়াই সরাসরি কাজ করবে, চাইলে অন্য ফাইলে তুলে রাখা যাবে, আর একাধিক ভাষা হলে খুব সহজ একটি ক্লাস বা ফাংশনে মেইনটেইন করা যাবে”** — এই দর্শনের ওপর ভিত্তি করে **নতুন `OmniL10n` (Inline-First + Easy-Extract)** পদ্ধতিটি নিচে সাজানো হলো।

---

## তুলনামূলক রেটিং

| বৈশিষ্ট্য | 🌟 **নতুন: `OmniL10n` Inline-First** *(প্রস্তাবিত)* | পুরোনো কী-ম্যাপ (`'auth.login'`) | ডার্ট `abstract` ক্লাস | Flutter `.arb` (`gen-l10n`) |
|---|---|---|---|---|
| **রেটিং** | **💯 ১০ / ১০ (সহজতম ও পরিপূর্ণ)** | **৮.৫ / ১০** | **৭.৮ / ১০** | **৬.৫ / ১০** |
| **নতুন ফাইল বানাতে হয়?** | **মোটেও না** (ইচ্ছে হলে তবেই বানাবেন!) | হ্যাঁ (শুরুতেই ম্যাপ ফাইল) | হ্যাঁ (প্রতি ভাষায় ক্লাস) | হ্যাঁ (`.yaml` + `.arb`) |
| **কী-স্ট্রিং (`'a.b.c'`) মনে রাখা** | **প্রয়োজন নেই** | লাগে | লাগে না | `.arb`-তে লাগে |
| **ডায়নামিক ভ্যালু ও প্লুরাল** | **সাধারণ Dart** (`'Hi, $name'`) | `{name}` + ICU স্ট্রিং | সাধারণ Dart | ICU জটিল সিনট্যাক্স |
| **ছোট থেকে বড় স্কেল করা** | **৫ সেকেন্ডে কপি-পেস্ট** (`context.l10n` → আলাদা ফাংশন/ক্লাস) | সহজ | কঠিন | কঠিন |
| **IDE অটোকমপ্লিট** | **১০০%** (নেমড প্যারামিটার ও `OmniLang` ক্লাস) | ম্যাপে নেই | আছে | Codegen-এর পর |
| **`OmniFields` ও `OmniApp` সাপোর্ট** | **শূন্য সেটআপে অটো কাজ করে** | আছে | অ্যাডাপ্টার লাগে | ডুপ্লিকেট লিখতে হয় |

---

## 🌟 কীভাবে কাজ করবে নতুন এই ১০/১০ সিস্টেম? (মাত্র ৪টি সহজ ধাপ)

### ধাপ ১: কোনোরকম আলাদা ফাইল ছাড়াই সরাসরি স্ক্রিনে ব্যবহার!
আপনি `OmniApp.material(...)` চালালেই সিস্টেম রেডি। কোথাও কোনো `.arb`, `.json`, বা আলাদা ডিকশনারি ফাইল না বানিয়েই সরাসরি উইজেটের ভেতরে লিখবেন:

```dart
// ✅ ১. একদম সরাসরি ইনলাইন (কোনো এক্সট্রা ফাইল বা কী-নাম লাগবে না!)
Text(context.l10n(
  en: 'Sign In',
  bn: 'লগইন করুন',
))

// ✅ ২. ভ্যারিয়েবল বা ডায়নামিক ভ্যালু? সাধারণ Dart স্ট্রিং ইন্টারপোলেশনই যথেষ্ট!
Text(context.l10n(
  en: 'Welcome back, $userName!',
  bn: 'আবার স্বাগতম, $userName!',
))

// ✅ ৩. প্লুরাল? কোনো জটিল সিনট্যাক্স ছাড়াই সাধারণ শর্ত!
Text(context.l10n(
  en: count == 1 ? '1 item left' : '$count items left',
  bn: '$countটি পণ্য বাকি',
))

// ✅ ৪. সাথে সাথে আরবি, হিন্দি, উর্দু, স্প্যানিশ বা যেকোনো ভাষা যোগ করুন:
Text(context.l10n(
  en: 'Checkout',
  bn: 'চেকআউট',
  ar: 'الدفع',
  hi: 'चेकआउट',
  other: {'ja': 'チェックアウト', 'ko': '결제'}, // দুনিয়ার যেকোনো ভাষার কোড!
))
```

**যদি কোনো একটি জায়গায় সব ভাষা না লিখে শুধু `en` আর `bn` দেন?**
সিস্টেম **কখনো ক্র্যাশ করবে না বা ফাঁকা দেখাবে না** — ইউজার তৃতীয় কোনো ভাষা (`ar`) বেছে নিলে সে জায়গায় স্বয়ংক্রিয়ভাবে `en` (বা আপনার সেট করা ফলব্যাক) দেখাবে!

---

### ধাপ ২: যখন চাইবেন অন্য ফাইলে তুলে রাখবেন (৩টি একদম সহজ উপায়)

প্রজেক্ট বড় হলে UI কোড পরিষ্কার রাখতে চাইলে, আপনি UI-র ঐ একই লাইনগুলো কাট-পেস্ট করে আলাদা একটি ফাইলে (যেমন `lib/l10n/app_texts.dart`) তুলে দিতে পারবেন:

#### উপায় A — সহজ কনস্ট্যান্ট হিসেবে (`OmniText`)
```dart
// 📄 lib/l10n/auth_texts.dart
class AuthTexts {
  static const title = OmniText(
    en: 'Create Account',
    bn: 'নতুন অ্যাকাউন্ট তৈরি করুন',
    ar: 'إنشاء حساب',
  );

  static const submit = OmniText(
    en: 'Continue',
    bn: 'এগিয়ে যান',
    ar: 'متابعة',
  );
}

// 👉 স্ক্রিনে ব্যবহার:
Text(AuthTexts.title.tr(context))
// অথবা Bloc / Validator / Repo-তে BuildContext ছাড়াই:
final msg = AuthTexts.title.value;
```

#### উপায় B — সহজ ফাংশন হিসেবে (প্যারামিটার থাকলে!)
```dart
// 📄 lib/l10n/auth_texts.dart
String welcomeMessage(BuildContext context, String name) => context.l10n(
  en: 'Hello, $name!',
  bn: 'হ্যালো, $name!',
  ar: 'مرحباً يا $name!',
);

// অথবা BuildContext ছাড়াই কাজ করবে এমন OmniText ফাংশন:
OmniText otpNotice(int seconds) => OmniText(
  en: 'Resend code in ${seconds}s',
  bn: '$seconds সেকেন্ড পর আবার কোড পাঠান',
  ar: 'إعادة الإرسال خلال $seconds ثانية',
);

// 👉 ব্যবহার:
Text(welcomeMessage(context, 'Juwel'))
Text(otpNotice(20).tr(context))
```

#### উপায় C — অনেকগুলো ভাষা ও বড় অ্যাপের জন্য একটি পরিচ্ছন্ন ক্লাস (`OmniLang`) 🏆
যখন একাধিক ভাষা মেইনটেইন করতে চান, তখন ১০টি আলাদা `.arb`/ম্যাপ ফাইলে ঘুরপাক না খেয়ে **একটি সহজ Dart ক্লাস** বানাবেন (কোনো `abstract`, `implements`, বা কোড জেনারেটর ছাড়াই!):

```dart
// 📄 lib/l10n/app_lang.dart (চাইলে AuthLang, ProfileLang, CartLang আলাদা ভাগ করতে পারবেন!)
class AppLang extends OmniLang {
  const AppLang([super.context]); // context না দিলে গ্লোবাল কন্ট্রোলার থেকেই কাজ করবে!

  // ১. প্রতিটি টেক্সটের পাশে সব ভাষা একসাথে — খোঁজা ও মেইনটেইন করা ১০০% সহজ!
  String get homeTitle => pick(
    en: 'Home',
    bn: 'হোম',
    ar: 'الرئيسية',
    hi: 'होम',
  );

  String get saveButton => pick(
    en: 'Save Changes',
    bn: 'পরিবর্তন সেভ করুন',
    ar: 'حفظ التغييرات',
    other: {'es': 'Guardar cambios', 'fr': 'Enregistrer'},
  );

  String welcomeUser(String name) => pick(
    en: 'Welcome, $name!',
    bn: 'স্বাগতম, $name!',
    ar: 'أهلاً بك يا $name!',
  );

  String unreadCount(int count) => pick(
    en: count == 0 ? 'No unread alerts' : '$count unread',
    bn: count == 0 ? 'কোনো নতুন নোটিফিকেশন নেই' : '$countটি অপঠিত',
  );
}
```
আর অ্যাপে ব্যবহার দেখুন — একদম পানির মতো সহজ ও **১০০% IDE অটোকমপ্লিট**:
```dart
// স্ক্রিনে:
final lang = AppLang(context);
Text(lang.homeTitle)
Text(lang.welcomeUser('Juwel'))
ElevatedButton(onPressed: () {}, child: Text(lang.saveButton))

// Bloc / Guard / API Error হ্যান্ডলারে (context ছাড়া):
const AppLang().homeTitle;
```

---

### ধাপ ৩: ভাষা সেটআপ ও পরিবর্তন — মাত্র ১ লাইন!

#### ক. সর্বনিম্ন সেটআপ (কিছু না লিখলেও চলে, চাইলে ভাষা লিস্ট দিন)
```dart
OmniApp.material(
  // শুধু কোন কোন ভাষা অ্যাপে দেখাতে চান তা বলে দিলেই যথেষ্ট:
  supportedLocales: const [Locale('en'), Locale('bn'), Locale('ar')],
  routes: [...],
)
```
*(চাইলে আরও কাস্টমাইজেশনের জন্য `localization: OmniLocalization(fallbackLocale: Locale('en'), animateTransition: true, useLocaleDigits: true, localeFonts: {'bn': 'HindSiliguri'})` ব্যবহার করা যাবে!)*

#### খ. ভাষা পরিবর্তন ও রেডিমেড উইজেট (অটো `SharedPreferences`-এ সেভ হয়!)
```dart
// ১. কোড থেকে ভাষা বদলানো (সাথে সাথে পুরো অ্যাপ + RTL + অ্যানিমেশন আপডেট হবে!):
context.setLocale(const Locale('bn'));   // বাংলা
context.setLocale(const Locale('ar'));   // আরবি (পুরো অ্যাপ অটো RTL হবে!)
context.useSystemLocale();               // ডিভাইসের ভাষা ফলো করবে

// ২. বর্তমান ভাষা জানা:
context.currentLocale;   // Locale('bn')
context.languageCode;    // 'bn'
context.isRtl;           // false (ar হলে true)

// ৩. Settings পেজে ১ লাইনে রেডিমেড পিকার (OmniThemePanel-এর মতোই!):
const OmniLocaleTile()        // ক্লিক করলে সুন্দর ভাষা বাছাই শিট খুলবে
const OmniLocalePicker()      // চিপ / ড্রপডাউন / কার্ড হিসেবে সব ভাষা দেখাবে
OmniLocaleButton()            // ট্যাপ করলেই পরের ভাষায় সুইচ (🇺🇸 EN / 🇧🇩 বাংলা)
```

---

### ধাপ ৪: প্যাকেজের বাকি সবকিছুর সাথে অটো-ইন্টিগ্রেশন

1. **সব প্রি-ডিফাইনড ফিল্ড (`OmniFields`) অটো বাংলা/ইংরেজি হবে**:
   - `OmniEmailField`, `OmniPasswordField` (`Weak`/`Fair`/`Strong`), `OmniPhoneField` (`Verify`/`Verified`), `OmniOtpField` (`Resend Code`, `OTP Verified`, `Verifying...`) এবং সব `OmniValidators` এরর মেসেজ ভাষা বদলানোর সাথে সাথেই বদলে যাবে!
2. **অ্যানিমেটেড ট্রানজিশন & RTL**:
   - থিম মোডের মতোই ভাষা বদলালে স্ক্রিনে হালকা অ্যানিমেশন চলবে (`OmniThemeTransition`), আর `ar`/`ur`/`fa`/`he` হলে অটো ডান-থেকে-বামে (`Directionality.rtl`) ঘুরবে।
3. **বাংলা অঙ্ক সাপোর্ট (ঐচ্ছিক)**:
   - `context.trDigits('01712-345678')` বা `context.formatNumber(12500)` → বাংলা মোডে `'০১৭১২-৩৪৫৬৭৮'` ও `'১২,৫০০'`!
4. **কোনো Flutter ডেলিগেট ওয়ার্নিং বা নতুন ডিপেন্ডেন্সি নেই**:
   - `flutter_localizations` ইনস্টল না করলেও `OmniApp` অভ্যন্তরীণ নিরাপদ ফলব্যাক ডেলিগেট দিয়ে দেয় — শূন্য ক্র্যাশ ও শূন্য ওয়ার্নিং।
5. **ভবিষ্যতে যদি কখনো `.json` বা সার্ভার থেকে অনুবাদ আনতে হয়?**
   - শুধু ঐচ্ছিক `key:` প্যারামিটার (`context.l10n(key: 'home.title', en: 'Home', bn: 'হোম')`) ও `context.mergeLocaleJson(...)` যোগ করলেই রিমোট ওভাররাইডও কাজ করবে — কিন্তু সাধারণ ব্যবহারে কোনো `key:` বা `.json` লেখারই দরকার নেই!

---

## আপনার মতামত দিন

এই ডিজাইনটি কেমন হলো? সরাসরি ব্যবহারের জন্য **`context.l10n(en: '...', bn: '...')`**, আলাদা ফাইলে রাখার জন্য **`OmniText` / সাধারণ ফাংশন**, আর একাধিক ভাষার জন্য সহজ **`OmniLang` ক্লাস** — এই সম্পূর্ণ সিস্টেমটি এখন ইমপ্লিমেন্ট করবো কি না জানাবেন!
