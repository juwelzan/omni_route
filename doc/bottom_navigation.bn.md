# বটম নেভিগেশন গাইড

`OmniBottomNavigationBar` হলো একটা বটম নেভিগেশন বার: ১২টা স্টাইল, route-এর সাথে নিজে থেকে মেলে, controller দিয়েও চালানো যায়। এই গাইডে কোন অপশন কী করে আর কখন কোনটা ব্যবহার করবেন, তা আছে।

## ১. সবচেয়ে সহজ ব্যবহার

```dart
Scaffold(
  extendBody: true, // ভাসমান স্টাইলে পেজ বারের নিচ পর্যন্ত যায়
  bottomNavigationBar: OmniBottomNavigationBar(
    style: OmniBottomNavigationStyle.materialPill,
    items: const [
      OmniBottomNavigationItem(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
        routePath: '/home', // OmniApp-এ এই পাথে গেলে ট্যাবটা নিজে সিলেক্ট হয়
      ),
      OmniBottomNavigationItem(
        icon: Icon(Icons.inbox_outlined),
        label: 'Inbox',
        routePath: '/inbox',
        badgeCount: 3,
      ),
    ],
  ),
)
```

কোন ট্যাব সিলেক্টেড থাকবে, তা তিনভাবে ঠিক হয়। আগেরটা থাকলে সেটাই খাটে:
১. `currentIndex`
২. `controller` (`OmniBottomNavigationController`)
৩. বর্তমান route-এর সাথে আইটেমের `routePath` মিলিয়ে

## ২. স্টাইল ও চেহারা

| অপশন | কী করে |
|---|---|
| `style` | ১২টা স্টাইলের একটা: `floating`, `floatingBubble`, `slidingPill`, `curvedNotch`, `centerFabNotch`, `splitIsland`, `glass`, `glowingDot`, `topIndicator`, `floatingCircles`, `materialPill`, `cupertino` |
| `labelMode` | লেবেল দেখানো: `styleDefault` (স্টাইল অনুযায়ী) / `alwaysShow` (সবসময়) / `selectedOnly` (শুধু সিলেক্টেড ট্যাবে) / `never` (শুধু আইকন) |
| `itemLayout` | আইকন আর লেবেলের সাজানো: `stacked` (লেবেল আইকনের নিচে, ডিফল্ট) / `inline` (পাশাপাশি; সিলেক্টেড পিল দুটোকেই ঘিরে রাখে, Material 3 Expressive-এর মতো) / `adaptive` (স্ক্রিন ৬০০ বা তার বেশি চওড়া হলে পাশাপাশি) |
| `docked` | `true`: যেকোনো স্টাইল স্ক্রিনের দুই পাশ জুড়ে নিচে লাগানো ক্লাসিক বার। `false`: নিচে লাগানো স্টাইলকে ভাসমান কার্ড বানায়। `null`: স্টাইল যেমন আছে |
| `notch` | `curvedNotch` আর `centerFabNotch` স্টাইলের কাটা অংশের আকার (`smooth` / `circular` / `none`), ট্যাব বদলানোর অ্যানিমেশন (`slide` / `dip` / `pop`), আর অর্বের সাইজ, উচ্চতা (`lift`), ফাঁক (`gap`) ও গভীরতা (`depth`) |
| `indicatorAtBottom`, `showSpotlight` | শুধু `topIndicator`-এ: দাগটা নিচে আন্ডারলাইনের মতো দেখানো, আর আলোর কোণটা চালু বা বন্ধ করা |
| রং, সাইজ, blur, gradient, ছায়া | সব আলাদা প্যারামিটার, অথবা `theme:` দিয়ে একসাথে |

পুরো অ্যাপে একই সেটিং চাইলে theme extension-এ দিন:

```dart
ThemeData(extensions: const [
  OmniBottomNavigationStyleData(
    style: OmniBottomNavigationStyle.materialPill,
    itemLayout: OmniBottomNavItemLayout.adaptive,
    docked: true,
  ),
])
```

কোন সেটিং খাটবে, তার ক্রম: বারে সরাসরি দেওয়া প্যারামিটার, তারপর `theme:`, তারপর theme extension, শেষে ডিফল্ট।

## ৩. আচরণ

- **`hideOnScroll` (সাথে `scrollController` দিতে হবে):** নিচে স্ক্রল করলে বার লুকায়, উপরে স্ক্রল করলে ফিরে আসে। স্ক্রিন রিডার বা switch access চালু থাকলে বার লুকায় না, যাতে ব্যবহারকারী বারটা খুঁজে পান।
- **`hideOnKeyboard`:** কিবোর্ড খুললে বার সরে যায়।
- **Reduced motion:** ডিভাইসে অ্যানিমেশন কমানো চালু থাকলে বারের সব অ্যানিমেশন সাথে সাথে শেষ হয়।
- **`syncSystemNavigationBar: true`:** নিচে লাগানো বারের রঙে Android-এর সিস্টেম নেভিগেশন বারও রাঙানো হয়, আইকন এমন রঙে যাতে পড়া যায়। ভাসমান বারে সিস্টেম বার স্বচ্ছ থাকে। বার লুকালে আবার পেজের নিজের সেটিং খাটে। এটা ডিফল্টে বন্ধ।
- **`centerAction`:** মাঝখানে একটা অ্যাকশন বাটন।
- **`onReselect`:** যে ট্যাব আগে থেকে সিলেক্টেড, তাতে আবার চাপলে এটা ডাকা হয়। যেমন লিস্ট উপরে নিয়ে যেতে।

## ৪. সিলেকশন মোড: `OmniContextualActionBar`

Gmail বা Files-এর মতো কয়েকটা আইটেম বেছে নিলে নেভিগেশন বারের জায়গায় অ্যাকশন বার চলে আসে:

```dart
bottomNavigationBar: OmniContextualActionBar(
  active: selected.isNotEmpty,
  title: '${selected.length} selected',
  onClose: clearSelection,
  actions: [
    OmniContextualAction(
      icon: const Icon(Icons.share_outlined),
      label: 'Share',
      onPressed: share,
    ),
    OmniContextualAction(
      icon: const Icon(Icons.delete_outline),
      label: 'Delete',
      destructive: true,
      onPressed: delete,
    ),
  ],
  child: OmniBottomNavigationBar(items: [...]),
),
```

- **যা জায়গায় আঁটে না:** সেই অ্যাকশনগুলো "আরও" মেনুতে চলে যায়।
- **Back বাটন:** প্রথমে সিলেকশন মোড বন্ধ করে, তারপর স্বাভাবিকভাবে পেজ থেকে বের হয়।
- **নিচের বার:** নেভিগেশন বার পুরোপুরি থেকে যায়, তার state হারায় না। এই সময় সেটা চাপা বা focus করা যায় না, আর স্ক্রিন রিডার সেটা পড়ে না।
- **ভাসমান বারের সাথে মেলানো:** নেভিগেশন বার ভাসমান হলে `margin` আর `borderRadius` একই দিন।

## ৫. পেজ বদলালেও বার স্থির রাখা (`OmniPage`)

`OmniPage(bottomNavigationBar: ...)` দিলে পেজ বদলানোর সময় বারটা নিজের জায়গায় স্থির থাকে, শুধু পেজটা বদলায়। কয়েকটা পেজ একই বার ব্যবহার করলে সেটা আসলে একটাই বার, তাই ইন্ডিকেটর আগের ট্যাব থেকে নতুন ট্যাবে সরে যায়।

| `OmniPageBarTransition` | পেজ বদলালে | যে পেজে বার নেই সেখানে গেলে |
|---|---|---|
| `slide` (ডিফল্ট) | বার স্থির থাকে | নিচে নেমে যায়, ফেরার সময় উঠে আসে |
| `fade` | বার স্থির থাকে | মিলিয়ে যায়, ফেরার সময় ফিরে আসে |
| `withPage` | বার পেজের সাথে সরে | পেজের সাথে চলে যায় |

প্রতিটা পেজে আলাদা করে দিতে `bottomNavigationBarTransition:`, পুরো অ্যাপে একবারে দিতে `OmniApp(bottomBarTransition:)`।

এখানে প্রতিটা ট্যাব আলাদা route। তাই ট্যাব বদলালে আগের ট্যাবের স্ক্রল অবস্থান বা স্ট্যাক থাকে না। সেটা ধরে রাখতে চাইলে নিচের `OmniStatefulShell` ব্যবহার করুন।

## ৬. ফোন, ট্যাবলেট, ডেস্কটপ: `OmniStatefulShell.adaptive`

ফোনে বটম বার, ট্যাবলেটে NavigationRail, ডেস্কটপে চওড়া (extended) rail দেখায়। প্রতিটা ট্যাবের স্ট্যাক আর স্ক্রল অবস্থান থেকে যায়।

```dart
OmniStatefulShell.adaptive(
  bottomBarStyle: OmniBottomNavigationStyle.materialPill, // না দিলে Material-এর NavigationBar
  destinations: const [
    OmniAdaptiveDestination(
      icon: Icon(Icons.inbox_outlined),
      label: 'Inbox',
      badgeCount: 12,
      tooltip: 'Your inbox',
      semanticLabel: 'Inbox, 12 unread',
    ),
    OmniAdaptiveDestination(
      icon: Icon(Icons.chat_outlined),
      label: 'Chat',
      showDotBadge: true,
    ),
  ],
  branches: [...],
)
```

- **ব্যাজ:** তিন জায়গাতেই দেখায়: Material বার, Omni বার আর rail।
- **`semanticLabel`:** স্ক্রিন রিডার এটা পড়ে Omni বার আর rail-এ। Material-এর NavigationBar `label`-টাই পড়ে।
- **Tooltip:** rail-এও দেখায়।
