# OmniRoute Responsive System — পূর্ণাঙ্গ বাংলা গাইড (সেটআপ, উইজেট ও জিরো-ল্যাগ আর্কিটেকচার)

> `.w` / `.h` / `.sp` গুনতি বা `MediaQuery.of(context)` ব্যবহারের ফলে কিবোর্ড উঠলে পুরো স্ক্রিন রি-বিল্ড হওয়া ও ফ্রেম ড্রপ ছাড়াই কীভাবে `OmniRoute`-এর **নেটিভ-মানের জিরো-ল্যাগ Responsive Engine** (Phone, Small Phone, Tablet, Desktop, Large Desktop, Foldable ও Master-Detail) সেটআপ ও ব্যবহার করবেন — এই ডকে ধাপে ধাপে সম্পূর্ণ উদাহরণসহ দেখানো হয়েছে।

> মূল গাইড: [doc/guide.bn.md](guide.bn.md) · থিমিং গাইড: [doc/theming.bn.md](theming.bn.md) · প্রজেক্ট ওভারভিউ: [README.md](../README.md)

---

## সূচিপত্র

1. [১ মিনিটে শুরু — জিরো-সেটআপ ও কাস্টম সেটআপ](#১-১-মিনিটে-শুরু--জিরো-সেটআপ-ও-কাস্টম-সেটআপ)
2. [ব্রেকপয়েন্ট, ডিভাইস টিয়ার ও `OmniResponsiveConfig`](#২-ব্রেকপয়েন্ট-ডিভাইস-টিয়ার-ও-omniresponsiveconfig)
3. [প্রি-ক্যাশড ডিজাইন টোকেন (`OmniResponsiveTokens`) ও `context` শর্টকাট](#৩-প্রি-ক্যাশড-ডিজাইন-টোকেন-omniresponsivetokens-ও-context-শর্টকাট)
4. [জিরো-ল্যাগ রেসপন্সিভ লেআউট উইজেটসমূহ](#৪-জিরো-ল্যাগ-রেসপন্সিভ-লেআউট-উইজেটসমূহ)
5. [মাস্টার-ডিটেইল, ফোল্ডেবল ডুয়াল-স্ক্রিন ও লোকাল Container Query](#৫-মাস্টার-ডিটেইল-ফোল্ডেবল-ডুয়াল-স্ক্রিন-ও-লোকাল-container-query)
6. [অ্যাডাপ্টিভ নেভিগেশন শেল, ব্রেডক্রাম্ব, মোডাল ও প্রিফেচ](#৬-অ্যাডাপ্টিভ-নেভিগেশন-শেল-ব্রেডক্রাম্ব-মোডাল-ও-প্রিফেচ)
7. [অটো টেক্সট স্কেলিং, ওরিয়েন্টেশন ও থিমিং-এর সাথে সমন্বয়](#৭-অটো-টেক্সট-স্কেলিং-ওরিয়েন্টেশন-ও-থিমিং-এর-সাথে-সমন্বয়)
8. [মেমরি, পারফরম্যান্স ও `0` রি-বিল্ড আর্কিটেকচার নীতি](#৮-মেমরি-পারফরম্যান্স-ও-0-রি-বিল্ড-আর্কিটেকচার-নীতি)
9. [পূর্ণাঙ্গ প্রোডাকশন উদাহরণ (Adaptive Shell + SliverGrid + MasterDetail + Modal)](#৯-পূর্ণাঙ্গ-প্রোডাকশন-উদাহরণ-adaptive-shell--slivergrid--masterdetail--modal)

---

## ১. ১ মিনিটে শুরু — জিরো-সেটআপ ও কাস্টম সেটআপ

### ক. কিছুই সেট না করলেও ডিফল্ট চালু থাকে

প্রতিটি `OmniApp(...)`, `OmniApp.material(...)` ও `OmniApp.cupertino(...)` রুট লেভেলে স্বয়ংক্রিয়ভাবে `OmniResponsiveScope` (এবং `OmniResponsiveTextScaleHost`) বসিয়ে দেয়:

```dart
OmniApp.material(
  title: 'My App',
  // কিছুই দিতে হয় না — mobile / tablet / desktop ব্রেকপয়েন্ট ও টোকেন অটো চালু!
  routes: [
    OmniPage('/', (_) => const HomeScreen()),
  ],
)
```

যে কোনো স্ক্রিনের ভেতরে সরাসরি ব্যবহার করতে পারেন:

```dart
final t = context.tokens; // বর্তমান টিয়ারের প্রি-অ্যালোকেটেড padding, gap, fontSize, radius
if (context.isMobile) { ... }
final cols = context.responsiveColumns(); // mobile: 2, tablet: 3, desktop: 4, largeDesktop: 5
```

### খ. কাস্টম ব্রেকপয়েন্ট, টেক্সট স্কেল লিমিট ও রেসপন্সিভ রোটেশনসহ সেটআপ

```dart
OmniApp.material(
  title: 'Enterprise App',
  orientation: OmniOrientation.portraitOnMobile, // ফোনে portrait লক, ট্যাবলেটে ৪ দিকেই রোটেশন!
  minTextScale: 0.85,
  maxTextScale: 1.4,
  responsive: const OmniResponsiveConfig(
    enabled: true,
    smallPhoneMaxWidth: 360,
    mobileMaxWidth: 600,
    tabletMaxWidth: 1024,
    desktopMaxWidth: 1440,
    useShortestSide: false, // ল্যান্ডস্কেপ ফোনেও mobile রাখতে চাইলে true দিন
    adaptTextScaling: true,
  ),
  routes: [...],
)
```

> **রেডিমেড কনফিগ প্রিসেট:**
> - `const OmniResponsiveConfig.phoneFriendly()` — `useShortestSide: true` করে দেয়, ফলে বড় ফোন ল্যান্ডস্কেপে ঘুরালেও `mobile` লেআউটেই থাকে।
> - `const OmniResponsiveConfig.desktopDense()` — `900dp` থেকেই ডেস্কটপ লেআউট চালু করে (অ্যাডমিন প্যানেল/ড্যাশবোর্ডের জন্য)।
> - `const OmniResponsiveConfig.disabled()` — রেসপন্সিভ টেক্সট স্কেলিং বন্ধ করে।
> - `OmniApp`-এর বাইরে আলাদা উইজেট সাবট্রিতে ব্যবহার করতে চাইলে `OmniResponsiveScope(child: ...)` বসাতে পারেন।

---

## ২. ব্রেকপয়েন্ট, ডিভাইস টিয়ার ও `OmniResponsiveConfig`

`OmniRoute` পিক্সেল-প্রতি রি-বিল্ড না করে নেটিভ Android WindowSize / iOS TraitCollection-এর মতো **ডিসক্রিট টিয়ারে** কাজ করে:

| `OmniDeviceType` | ডিফল্ট প্রস্থ (`width`) | কোন ডিভাইসের জন্য |
|---|---|---|
| `OmniDeviceType.mobile` | `< 600dp` *(এর মধ্যে `< 360dp` হলে `isSmallPhone == true`)* | সব স্মার্টফোন ও ছোট হ্যান্ডসেট |
| `OmniDeviceType.tablet` | `600dp .. 1023dp` | ট্যাবলেট ও আনফোল্ড করা ফোল্ডেবল |
| `OmniDeviceType.desktop` | `1024dp .. 1439dp` | ল্যাপটপ, ওয়েব ও স্ট্যান্ডার্ড ডেস্কটপ মনিটর |
| `OmniDeviceType.largeDesktop` | `>= 1440dp` | বড় মনিটর ও আল্ট্রাওয়াইড ডিসপ্লে |

এছাড়া Material 3 স্ট্যান্ডার্ড **`OmniWindowSize`** (`context.windowSize`)-ও রয়েছে:

| `OmniWindowSize` | ডিফল্ট প্রস্থ |
|---|---|
| `OmniWindowSize.compact` | `< 600dp` |
| `OmniWindowSize.medium` | `600dp .. 839dp` |
| `OmniWindowSize.expanded` | `840dp .. 1199dp` |
| `OmniWindowSize.large` | `1200dp .. 1599dp` |
| `OmniWindowSize.extraLarge` | `>= 1600dp` |

### `OmniResponsiveConfig`-এর সব প্যারামিটার

| প্যারামিটার | ডিফল্ট | কাজ |
|---|---|---|
| `enabled` | `true` | রেসপন্সিভ ও অ্যাডাপ্টিভ টেক্সট স্কেলিং চালু/বন্ধ (`OmniResponsiveConfig.disabled()` দিলে বন্ধ) |
| `smallPhoneMaxWidth` | `360` | এর নিচে `context.isSmallPhone == true` এবং `OmniResponsiveTokens.smallPhone` টোকেন ব্যবহৃত হয় |
| `mobileMaxWidth` | `600` | `OmniDeviceType.mobile`-এর সর্বোচ্চ সীমা (exclusive) |
| `tabletMaxWidth` | `1024` | `OmniDeviceType.tablet`-এর সর্বোচ্চ সীমা |
| `desktopMaxWidth` | `1440` | `OmniDeviceType.desktop`-এর সর্বোচ্চ সীমা (এর ওপরে `largeDesktop`) |
| `useShortestSide` | `false` | `true` দিলে প্রস্থের বদলে `size.shortestSide` দেখে টিয়ার ঠিক করে — ফোন ল্যান্ডস্কেপ ঘোরালেও `mobile` থাকে |
| `adaptTextScaling` | `true` | ডিসপ্লে টিয়ারের `textScale` + OS Accessibility `TextScaler` + `minTextScale`/`maxTextScale` নিরাপদে সমন্বয় করে |
| `tokens` | `const OmniResponsiveTokenSet()` | প্রতিটি টিয়ারের কাস্টম `OmniResponsiveTokens` দেওয়ার জন্য |

#### নিজস্ব কাস্টম টোকেন সেট (`OmniResponsiveTokenSet`) দেওয়া

```dart
final customTokens = OmniResponsiveTokenSet(
  mobile: OmniResponsiveTokens.mobile.copyWith(
    pagePadding: const EdgeInsets.all(20),
    gridColumns: 1,
    cardRadius: 16,
  ),
  tablet: OmniResponsiveTokens.tablet.copyWith(
    gridColumns: 2,
    maxContentWidth: 720,
  ),
);

OmniApp.material(
  responsive: OmniResponsiveConfig(tokens: customTokens),
  routes: [...],
);
```

---

## ৩. প্রি-ক্যাশড ডিজাইন টোকেন (`OmniResponsiveTokens`) ও `context` শর্টকাট

### ৩.১. প্রতি টিয়ারের প্রি-অ্যালোকেটেড টোকেন মান (`context.tokens`)

প্রতিটি `OmniResponsiveTokens` একবারই `const` হিসেবে মেমরিতে তৈরি থাকে (`0` প্রতি-ফ্রেম অ্যালোকেশন):

| টোকেন (`t.*`) | `smallPhone` (`<360`) | `mobile` (`<600`) | `tablet` (`600..1023`) | `desktop` (`1024..1439`) | `largeDesktop` (`>=1440`) |
|---|---|---|---|---|---|
| `spaceXs / Sm / Md / Lg` | `4 / 8 / 12 / 18` | `4 / 8 / 16 / 24` | `6 / 10 / 20 / 28` | `6 / 12 / 24 / 32` | `8 / 14 / 28 / 40` |
| `spaceXl / 2xl` | `24 / 32` | `32 / 44` | `40 / 52` | `44 / 60` | `52 / 68` |
| `pagePadding` | `all(12)` | `all(16)` | `all(24)` | `all(28)` | `all(32)` |
| `horizontalPadding` | `symmetric(h: 12)` | `symmetric(h: 16)` | `symmetric(h: 24)` | `symmetric(h: 32)` | `symmetric(h: 40)` |
| `cardPadding` | `all(12)` | `all(14)` | `all(18)` | `all(20)` | `all(24)` |
| `cardRadius / buttonRadius / dialogRadius` | `10 / 8 / 14` | `12 / 10 / 16` | `14 / 12 / 20` | `16 / 12 / 22` | `16 / 12 / 24` |
| `maxContentWidth` | `∞` | `∞` | `780` | `1140` | `1320` |
| `gridColumns / gridSpacing` | `2 / 10` | `2 / 12` | `3 / 16` | `4 / 20` | `5 / 24` |
| `minTapTarget / iconSize` | `48 / 20` | `48 / 22` | `44 / 24` | `40 / 24` | `40 / 26` |
| `display / headline / title / body / label` | `28 / 20 / 16 / 13.5 / 11.5` | `32 / 22 / 17 / 14 / 12` | `36 / 24 / 18 / 15 / 13` | `40 / 26 / 19 / 15.5 / 13` | `44 / 28 / 20 / 16 / 13.5` |
| `textScale / scaleFactor` | `0.94 / 0.92` | `1.0 / 1.0` | `1.0 / 1.08` | `1.05 / 1.14` | `1.08 / 1.2` |

**প্রি-অ্যালোকেটেড স্পেসার উইজেট:** নতুন `SizedBox(...)` না লিখে সরাসরি ব্যবহার করুন —
- লম্বালম্বি ফাঁকা: `t.gapXs`, `t.gapSm`, `t.gapMd`, `t.gapLg`, `t.gapXl`
- পাশাপাশি ফাঁকা (`Row`-তে): `t.gapWidthSm`, `t.gapWidthMd`, `t.gapWidthLg`
- বর্ডার রেডিয়াস: `t.cardBorderRadius`, `t.buttonBorderRadius`, `t.dialogBorderRadius`

```dart
final t = context.tokens;
Padding(
  padding: t.pagePadding,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('ড্যাশবোর্ড', style: context.textStyles.heading),
      t.gapMd,
      Container(
        padding: t.cardPadding,
        decoration: BoxDecoration(borderRadius: t.cardBorderRadius),
        child: const Text('কনটেন্ট'),
      ),
    ],
  ),
)
```

### ৩.২. সব `BuildContext` শর্টকাট (`OmniResponsiveContext`)

| গেটার / মেথড | কী করে | কখন রি-বিল্ড হয় (Aspect Splitting) |
|---|---|---|
| `context.isSmallPhone` / `isMobile` / `isTablet` / `isDesktop` / `isLargeDesktop` | ডিভাইস টিয়ার চেক (`bool`) | কেবল `OmniDeviceType` বা small-phone সীমানা পার হলে |
| `context.isTabletOrLarger` / `isDesktopOrLarger` | ট্যাবলেট+ বা ডেস্কটপ+ চেক | কেবল `OmniDeviceType` বদলালে |
| `context.deviceType` | `OmniDeviceType` রিটার্ন করে | কেবল `OmniDeviceType` বদলালে |
| `context.windowSize` | Material 3 `OmniWindowSize` | কেবল `OmniWindowSize` বদলালে |
| `context.isPortrait` / `isLandscape` / `screenOrientation` | ডাইমেনশন-ভিত্তিক ওরিয়েন্টেশন | কেবল পোর্ট্রেট ↔ ল্যান্ডস্কেপ বদলালে *(কিবোর্ড উঠলে রি-বিল্ড হয় না!)* |
| `context.isCompactHeight` | `height < 480dp` (ল্যান্ডস্কেপ ফোন/ছোট প্যানেল) | কেবল `480dp` পার হলে |
| `context.tokens` | `OmniResponsiveTokens` | কেবল টিয়ার টোকেন বদলালে |
| `context.pagePadding` / `horizontalPadding` / `cardPadding` / `sectionPadding` | টিয়ার অনুযায়ী প্রি-অ্যালোকেটেড `EdgeInsets` | কেবল টিয়ার টোকেন বদলালে |
| `context.gridColumns` / `maxContentWidth` | টিয়ার অনুযায়ী ডিফল্ট কলাম ও ম্যাক্স চওড়া | কেবল টিয়ার টোকেন বদলালে |
| `context.isKeyboardOpen` | নরম কিবোর্ড খোলা আছে কি না (`bool`) | কেবল `viewInsets.bottom` বদলালে *(রিসাইজে নয়!)* |
| `context.responsiveValue(mobile: ..., tablet: ..., desktop: ..., largeDesktop: ...)` | ডিভাইস অনুযায়ী যেকোনো ভ্যালু (`largeDesktop -> desktop -> tablet -> mobile` ফলব্যাক) | কেবল `OmniDeviceType` বদলালে |
| `context.responsiveColumns(mobile: 1, tablet: 2, desktop: 4)` | গ্রিডের কলাম সংখ্যা (`tokens.gridColumns` ফলব্যাক) | কেবল `OmniDeviceType` বদলালে |
| `context.responsiveSize(18)` | `tokens.scaleFactor` দিয়ে স্কেলড সাইজ | কেবল টিয়ার টোকেন বদলালে |
| `context.responsive` | সম্পূর্ণ `OmniResponsiveData` স্ন্যাপশট | স্ট্রাকচারাল অ্যাস্পেক্ট বদলালে |
| `context.responsiveRead` | **নন-লিসেনিং (`O(1)`) রিড!** | **কখনো রি-বিল্ড করে না** — `onPressed`, `initState` ও কলব্যাকে নিরাপদ |
| `context.screenSize` / `screenWidth` / `screenHeight` | লাইভ লজিক্যাল সাইজ | প্রতি পিক্সেল রিসাইজে *(একান্ত প্রয়োজন না হলে `deviceType`/`tokens` ব্যবহার করুন)* |

---

## ৪. জিরো-ল্যাগ রেসপন্সিভ লেআউট উইজেটসমূহ

### ৪.১. `OmniResponsiveLayout` (ডিভাইস অনুযায়ী আলাদা লেআউট)

ডাউনওয়ার্ড ফলব্যাক (`largeDesktop -> desktop -> tablet -> mobile`):

```dart
const OmniResponsiveLayout(
  mobile: MobileFeedView(),
  tablet: TwoColumnFeedView(),
  desktop: ThreeColumnDashboardView(),
)
```

### ৪.২. `OmniResponsiveBuilder`

শুধু ব্রেকপয়েন্ট টিয়ার বদলালেই বিল্ডার ফাংশন চলে (একই টিয়ারে উইন্ডো টেনে ছোট-বড় করলেও রি-বিল্ড হয় না):

```dart
OmniResponsiveBuilder(
  builder: (context, device, tokens) => Padding(
    padding: tokens.cardPadding,
    child: Text('বর্তমান ডিভাইস: ${device.name}'),
  ),
)
```

### ৪.৩. `OmniResponsiveContainer` (বড় স্ক্রিনে readable চওড়া ও সেন্টারিং)

ডেস্কটপ বা বড় ট্যাবলেটে ফর্ম বা প্রবন্ধ পুরো স্ক্রিনে ছড়িয়ে পড়া আটকাতে (`maxContentWidth`: মোবাইল ∞, ট্যাবলেট `780dp`, ডেস্কটপ `1140dp`, বড় মনিটর `1320dp`):

```dart
OmniResponsiveContainer(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      ProfileHeader(),
      SettingsForm(),
    ],
  ),
)
```

- কাস্টম সর্বোচ্চ চওড়া চাইলে `maxWidth: 640`, নিজের প্যাডিং চাইলে `padding:`, আর ডান-বাম চওড়া পূর্ণ না করে shrink-wrap চাইলে `fillWidth: false` দিতে পারেন।

### ৪.৪. `OmniResponsiveRowColumn` (মোবাইলে `Column` ↔ বড় স্ক্রিনে `Row`)

```dart
OmniResponsiveRowColumn(
  rowFrom: OmniDeviceType.tablet, // ট্যাবলেট ও তার বড় স্ক্রিনে Row হবে
  expandInRow: true,              // কেবল Row হলে child-গুলোতে স্বয়ংক্রিয় Expanded দেয়!
  gap: 16,                        // নেটিভ Flex.spacing (অতিরিক্ত SizedBox ছাড়া)
  children: const [
    RevenueSummaryCard(),
    OrdersChartCard(),
  ],
)
```

*(উপকারিতা: Vertical `Column`-এ `Expanded` না বসানোয় `ListView`/`SingleChildScrollView`-এর ভেতরে unbounded height ক্র্যাশ হয় না!)*

### ৪.৫. `OmniResponsiveVisibility` (সহজ শর্টহ্যান্ডসহ)

নির্দিষ্ট ডিভাইস টিয়ারে উইজেট দেখাতে বা লুকাতে (কোনো `bool` না লিখেই রেডিমেড শর্টহ্যান্ড):

```dart
const OmniResponsiveVisibility.mobileOnly(child: MobileFilterButton())
const OmniResponsiveVisibility.tabletUp(child: NavigationRailsHeader())
const OmniResponsiveVisibility.desktopUp(child: DesktopFilterSidebar())
const OmniResponsiveVisibility.hideOnMobile(child: QuickStatsStrip())
// অথবা কাস্টম কম্বিনেশন:
const OmniResponsiveVisibility(mobile: false, tablet: true, child: PromoBanner())
```

### ৪.৬. `const OmniGap` ও `const OmniResponsivePadding` (জিরো বয়লারপ্লেট স্পেসিং!)

প্রতিবার `final t = context.tokens;` না লিখে সরাসরি `const` উইজেট হিসেবে `Column`, `Row` বা `ListView`-তে বসান (ভেতরে প্রি-ক্যাশড টোকেন ব্যবহার করে — নতুন কোনো `SizedBox` অ্যালোকেট হয় না):

```dart
const OmniResponsivePadding( // বা .horizontal() / .card() / .section()
  child: Column(
    children: [
      Text('শিরোনাম'),
      OmniGap.md(), // .xs() / .sm() / .md() / .lg() / .xl()
      Row(
        children: [
          Icon(Icons.star),
          OmniGap.horizontalSm(), // .horizontalSm() / .horizontalMd() / .horizontalLg()
          Text('রেটিং'),
        ],
      ),
    ],
  ),
)
```

### ৪.৭. `OmniResponsiveColumns` (কোনো `childAspectRatio` বা Overflow ছাড়াই কার্ড গ্রিড!)

সাধারণ `GridView`-তে `childAspectRatio` ঠিক না থাকলে বড় লেখায় **overflow** হয়। `OmniResponsiveColumns` প্রতিটি কার্ডকে তার নিজের স্বাভাবিক উচ্চতা (`intrinsic height`) রেখেই `mobile / tablet / desktop / largeDesktop` সমান-চওড়া কলামে সাজায়:

```dart
OmniResponsiveColumns(
  mobileColumns: 1,
  tabletColumns: 2,
  desktopColumns: 3,
  largeDesktopColumns: 4,
  children: [
    for (final stat in dashboardStats) StatSummaryCard(stat),
  ],
)
```

### ৪.৮. `OmniResponsiveGrid`, `OmniResponsiveGrid.builder` ও `OmniResponsiveSliverGrid`

দুইভাবে ব্যবহার করা যায়:
1. **মোড ক (`maxItemWidth:` দিলে — C++ `RenderSliverGrid` এ 120fps অটো-রিফ্লো, উইন্ডো রিসাইজে `0` Dart রি-বিল্ড!)**
2. **মোড খ (`mobileColumns:`, `tabletColumns:`, `desktopColumns:`, `largeDesktopColumns:` দিলে — টিয়ার অনুযায়ী নির্দিষ্ট কলাম সংখ্যা)**

```dart
// ক) লং লিস্টের জন্য Lazy Grid (শুধু দৃশ্যমান আইটেম তৈরি হয়):
OmniResponsiveGrid.builder(
  itemCount: products.length,
  maxItemWidth: 260,      // অথবা: mobileColumns: 2, tabletColumns: 3, desktopColumns: 4
  mainAxisExtent: 220,    // স্থির উচ্চতা (ঐচ্ছিক)
  itemBuilder: (context, index) => ProductCard(products[index]),
)

// খ) CustomScrollView-এর ভেতরে O(visible) মেমরির Sliver Grid:
CustomScrollView(
  slivers: [
    const SliverAppBar(title: Text('Catalog')),
    SliverPadding(
      padding: context.tokens.pagePadding,
      sliver: OmniResponsiveSliverGrid(
        itemCount: products.length,
        maxItemWidth: 280,
        mainAxisExtent: 210,
        itemBuilder: (context, i) => ProductCard(products[i]),
      ),
    ),
  ],
)
```

---

## ৫. মাস্টার-ডিটেইল, ফোল্ডেবল ডুয়াল-স্ক্রিন ও লোকাল Container Query

### ৫.১. `OmniMasterDetail<T>` (`0` তালিকা রি-বিল্ড ও মোবাইলে `0` অফ-স্ক্রিন অ্যালোকেশন)

- **মোবাইলে (`< 600dp`):** কেবল `masterBuilder` দেখায় (`detailBuilder` মেমরিতে তৈরিই হয় না!) এবং ট্যাপ করলে `onOpenMobile(context, item)` চলে (যেমন `context.push('/orders/${item.id}')`)।
- **ট্যাবলেট/ডেস্কটপে (`>= 600dp`):** বামে `masterWidth` (ডিফল্ট `340dp`) মাস্টার লিস্ট ও ডানে `Expanded` ডিটেইল পেইন।
- আইটেম সিলেক্ট করলে `OmniMasterDetailController<T>` কেবল **ডিটেইল পেইন** ও `selectionListenable` শোনা নির্দিষ্ট রো আপডেট করে — পুরো তালিকা **কখনোই রি-বিল্ড হয় না**।

```dart
OmniMasterDetail<Order>(
  initialSelection: orders.first,
  masterWidth: 360,
  onOpenMobile: (context, order) => context.push('/orders/${order.id}'),
  emptyDetailBuilder: (_) => const Center(child: Text('একটি অর্ডার বেছে নিন')),
  masterBuilder: (context, selection, onSelect) => ListView.builder(
    itemCount: orders.length,
    itemBuilder: (context, index) {
      final order = orders[index];
      return ValueListenableBuilder<Order?>(
        valueListenable: selection,
        builder: (context, current, _) => ListTile(
          selected: current?.id == order.id,
          title: Text(order.title),
          onTap: () => onSelect(order),
        ),
      );
    },
  ),
  detailBuilder: (context, order) => OrderDetailPane(order: order),
)
```

### ৫.২. `OmniFoldableSplit` (ফোল্ডেবল হার্ডওয়্যার হিঞ্জ-সচেতন লেআউট)

ফোল্ডেবল ডিভাইসে (`DisplayFeatureType.hinge` বা `fold`) স্বয়ংক্রিয়ভাবে ভাঁজের (`hinge.bounds`) বামে `primary` এবং ডানে `secondary` বসায় যাতে কোনো লেখা বা ছবি হিঞ্জের নিচে চাপা না পড়ে। সাধারণ ট্যাবলেট/ডেস্কটপে `splitFrom` (ডিফল্ট `OmniDeviceType.tablet`) অনুযায়ী পাশে পাশে স্প্লিট হয়, আর মোবাইলে শুধু `primary` (অথবা `stackOnMobile: true` দিলে ওপর-নিচে) দেখায়:

```dart
const OmniFoldableSplit(
  splitFrom: OmniDeviceType.tablet,
  primaryFlex: 2,
  secondaryFlex: 3,
  stackOnMobile: true,
  primary: InboxListPane(),
  secondary: MessageReaderPane(),
)
```

### ৫.৩. লোকাল Container Query (`OmniResponsiveScope.constrained`)

`OmniMasterDetail` এবং `OmniFoldableSplit` ভেতরেই এটি ব্যবহার করে। আপনি চাইলে ড্রয়ার, ডায়ালগ বা যেকোনো কার্ডের প্রস্থ অনুযায়ী ভেতরের চাইল্ডগুলোকে আলাদাভাবে রেসপন্সিভ করতে পারেন:

```dart
SizedBox(
  width: 340, // উইন্ডো 1440px ডেস্কটপ হলেও এই সাবট্রির কাছে প্রস্থ 340dp -> mobile!
  child: OmniResponsiveScope.constrained(
    child: const MyCardGrid(),
  ),
)
```

---

## ৬. অ্যাডাপ্টিভ নেভিগেশন শেল, ব্রেডক্রাম্ব, মোডাল ও প্রিফেচ

### ৬.১. `OmniStatefulShell.adaptive` (Bottom Bar ↔ Compact Rail ↔ Extended Rail)

একই কোডে মোবাইলে নিচে `NavigationBar`, ট্যাবলেটে পাশে আইকনসহ `NavigationRail`, এবং ডেস্কটপে লেখা+আইকনসহ এক্সটেন্ডেড `NavigationRail` — প্রতিটি ট্যাবের নিজের রাউট স্ট্যাক ও স্ক্রল পজিশন `IndexedStack`-এ অক্ষুণ্ণ রেখে:

```dart
OmniStatefulShell.adaptive(
  destinations: const [
    OmniAdaptiveDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'হোম',
    ),
    OmniAdaptiveDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'ক্রেতা',
    ),
    OmniAdaptiveDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'সেটিংস',
    ),
  ],
  branches: [
    OmniBranch(routes: [OmniPage('/', (_) => const HomeScreen())]),
    OmniBranch(routes: [OmniPage('/customers', (_) => const CustomersScreen())]),
    OmniBranch(routes: [OmniPage('/settings', (_) => const SettingsScreen())]),
  ],
  extendedDesktopRail: true, // ডেস্কটপে লেবেলসহ চওড়া রেল
  resetTabOnReselect: true,
)
```

### ৬.২. `OmniPages.adaptiveModal` (মোবাইলে BottomSheet ↔ বড় স্ক্রিনে Dialog)

```dart
OmniPage(
  '/filters',
  (_) => const FilterPanel(),
  transition: OmniPages.adaptiveModal(maxDialogWidth: 560),
)
```

### ৬.৩. `OmniBreadcrumbBar` ও `OmniPrefetch`

- **`OmniBreadcrumbBar`:** মোবাইলে (`< 600dp`) অটো লুকানো থাকে (`showOnMobile: false`), ট্যাবলেট/ডেস্কটপে বর্তমান URL (`/orders/2026/101`) সেগমেন্ট আকারে দেখায় এবং ক্লিক করলেই `context.go(...)` করে:

```dart
const OmniBreadcrumbBar(rootLabel: 'ড্যাশবোর্ড')
```

- **`OmniPrefetch`:** ডেস্কটপে হোভার (`MouseRegion.onEnter`) বা মোবাইলে ট্যাপ ডাউনের (`Listener.onPointerDown`) মুহূর্তেই `OmniPage(onPrefetch: ...)` চালিয়ে দেয় (ডিফল্ট ৩০ সেকেন্ড `ttl` ডিডুপ্লিকেশনসহ):

```dart
OmniPrefetch(
  location: '/products/${item.id}',
  child: ListTile(
    title: Text(item.name),
    onTap: () => context.push('/products/${item.id}'),
  ),
)
```

---

## ৭. অটো টেক্সট স্কেলিং, ওরিয়েন্টেশন ও থিমিং-এর সাথে সমন্বয়

1. **অ্যাক্সেসিবিলিটি-নিরাপদ টেক্সট স্কেলিং (`OmniResponsiveTextScaleHost`):** প্রতিটি টিয়ারের `textScale` (`smallPhone: 0.94`, `mobile: 1.0`, `tablet: 1.0`, `desktop: 1.05`, `largeDesktop: 1.08`) OS-এর ফন্ট স্কেলিং এবং `OmniApp(minTextScale: ..., maxTextScale: ...)`-এর সাথে সমন্বিত হয় — এমনকি আপনার সব `const Text('হ্যালো')` উইজেট রি-বিল্ড না করেই।
2. **অ্যাডাপ্টিভ ওরিয়েন্টেশন ও সিস্টেম বার:**
   - `OmniApp(orientation: OmniOrientation.portraitOnMobile)` দিলে ফোনে পোর্ট্রেট লক থাকে এবং ট্যাবলেট/বড় স্ক্রিনে গেলে স্বয়ংক্রিয়ভাবে ৪ দিকে রোটেশন চালু হয়।
   - বিস্তারিত থিম, সিস্টেম স্ট্যাটাস বার (`OmniStatusBarStyle`) ও বটম গেস্টচার বার (`OmniSystemNavigationBarStyle`) জানতে দেখুন [doc/theming.bn.md](theming.bn.md)।
3. **থিমিং-এর সাথে ১-লাইনের সমন্বয়:** `context.ui` দিলে একসাথে রেসপন্সিভ `tokens`, `colors`, `text` (ডিভাইস টিয়ার অনুযায়ী স্কেলড `OmniTextStyles`), `styles`, `device`, `isMobile`/`isTablet`/`isDesktop` সব পাওয়া যায়!

---

## ৮. মেমরি, পারফরম্যান্স ও `0` রি-বিল্ড আর্কিটেকচার নীতি

`omni_route`-এর রেসপন্সিভ ইঞ্জিন কেন সাধারণ প্যাকেজের চেয়ে দ্রুত:

1. **Aspect Splitting (`InheritedModel`):** `_OmniResponsiveAspect` ৬টি আলাদা ভাগে বিভক্ত (`device`, `windowSize`, `orientation`, `compactHeight`, `tokens`, `metrics`)। তাই উইন্ডো `390dp -> 420dp -> 550dp`-এ রিসাইজ হলেও `context.isMobile`, `context.tokens`, `OmniResponsiveLayout`, `OmniStatefulShell.adaptive` বা `OmniMasterDetail` একবারও রি-বিল্ড হয় না!
2. **কিবোর্ড জ্যাঙ্ক শূন্য (`0` কিবোর্ড রি-বিল্ড):** `OmniResponsiveScope` কখনোই `viewInsets` (নরম কিবোর্ড ওঠা-নামা) পড়ে না — শুধু `MediaQuery.maybeSizeOf` / `FlutterView` ডাইমেনশন ব্যবহার করে। তাই `TextField`-এ ট্যাপ করলে রেসপন্সিভ ট্রি স্থির থাকে।
3. **`const` অবজেক্ট পুনর্ব্যবহার:** `OmniResponsiveTokens.smallPhone`..`largeDesktop` এবং এর ভেতরের `EdgeInsets`, `BorderRadius`, `SizedBox` (`gapMd` ইত্যাদি) কম্পাইল-টাইম `const` — প্রতি ফ্রেমে নতুন অবজেক্ট তৈরি হয় না।
4. **C++ রেন্ডার লেভেল গ্রিড:** `OmniResponsiveGrid(maxItemWidth: ...)` এবং `OmniResponsiveSliverGrid` সরাসরি `SliverGridDelegateWithMaxCrossAxisExtent` চালায়, ফলে ড্র্যাগ করে উইন্ডো বড়-ছোট করলেও Dart স্তরে উইজেট রি-বিল্ড হয় না।
5. **পরামর্শ:** `onPressed`, `initState`, বা `Redirect`-এর ভেতর ডিভাইস টিয়ার চেক করতে `context.isMobile`-এর বদলে নন-লিসেনিং `context.responsiveRead.isMobile` ব্যবহার করুন। আর `context.screenWidth` / `context.screenSize` কেবল যেখানে প্রতি পিক্সেল প্রস্থ দরকার সেখানেই ব্যবহার করুন।

---

## ৯. পূর্ণাঙ্গ প্রোডাকশন উদাহরণ (Adaptive Shell + SliverGrid + MasterDetail + Modal)

```dart
import 'package:flutter/material.dart';
import 'package:omni_route/omni_route.dart';

void main() => runApp(const ShopApp());

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OmniApp.material(
      title: 'OmniStore',
      screenMode: OmniScreenMode.edgeToEdge,
      orientation: OmniOrientation.portraitOnMobile,
      minTextScale: 0.9,
      maxTextScale: 1.35,
      omniTheme: OmniTheme.ocean,
      themes: OmniTheme.presets,
      routes: [
        OmniStatefulShell.adaptive(
          destinations: const [
            OmniAdaptiveDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'স্টোর',
            ),
            OmniAdaptiveDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'অর্ডার',
            ),
            OmniAdaptiveDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'সেটিংস',
            ),
          ],
          branches: [
            OmniBranch(
              routes: [
                OmniPage('/', (_) => const StoreHomePage()),
                OmniPage(
                  '/filters',
                  (_) => const FilterModalPage(),
                  transition: OmniPages.adaptiveModal(maxDialogWidth: 520),
                ),
              ],
            ),
            OmniBranch(
              routes: [
                OmniPage('/orders', (_) => const OrdersPage()),
                OmniPage('/orders/:id', (p) => OrderDetailPage(id: p.get('id'))),
              ],
            ),
            OmniBranch(
              routes: [
                OmniPage('/settings', (_) => const SettingsPage()),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class StoreHomePage extends StatelessWidget {
  const StoreHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টোর ক্যাটালগ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => context.push('/filters'), // মোবাইলে Sheet, ট্যাবলেটে Dialog!
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: OmniBreadcrumbBar(rootLabel: 'স্টোর'),
            ),
          ),
          SliverPadding(
            padding: t.pagePadding,
            sliver: OmniResponsiveSliverGrid(
              itemCount: 40,
              maxItemWidth: 260,
              mainAxisExtent: 180,
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: t.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('পণ্য #${index + 1}', style: context.textStyles.title),
                      t.gapSm,
                      const Text('১২০fps রেসপন্সিভ গ্রিড কার্ড'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilterModalPage extends StatelessWidget {
  const FilterModalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: t.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ফিল্টার অপশন', style: context.textStyles.heading),
          t.gapMd,
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('প্রয়োগ করুন'),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = List.generate(15, (i) => 'অর্ডার #${1001 + i}');
    return Scaffold(
      appBar: AppBar(title: const Text('অর্ডার তালিকা')),
      body: OmniMasterDetail<String>(
        initialSelection: items.first,
        onOpenMobile: (c, order) => c.push('/orders/${order.split('#').last}'),
        masterBuilder: (context, selection, onSelect) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return ValueListenableBuilder<String?>(
              valueListenable: selection,
              builder: (_, active, _) => ListTile(
                selected: active == item,
                title: Text(item),
                onTap: () => onSelect(item),
              ),
            );
          },
        ),
        detailBuilder: (context, order) => Center(
          child: Text('ডিটেইল ভিউ: $order', style: context.textStyles.title),
        ),
      ),
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('অর্ডার #$id')),
    body: OmniResponsiveContainer(
      child: Center(child: Text('অর্ডার #$id-এর বিস্তারিত তথ্য')),
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: OmniResponsiveContainer(
        child: ListView(
          padding: t.pagePadding,
          children: const [
            OmniThemePanel(showStylePicker: true),
          ],
        ),
      ),
    );
  }
}
```
