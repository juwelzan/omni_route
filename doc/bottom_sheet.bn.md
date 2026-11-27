# Omni Bottom Sheet (`showOmniBottomSheet`)

iOS-এর মতো স্প্রিং অ্যানিমেশন, আঙুলের সাথে চলা ড্র্যাগ, ডিটেন্ট (মাঝারি/বড়), ভেতরের লিস্ট থেকে
শিট টেনে নামানো — Material ও Cupertino দুই অ্যাপেই। `omni_responsive` (এবং `omni_route`) থেকে পাওয়া যায়।

## সবচেয়ে সহজ ব্যবহার

```dart
final city = await showOmniBottomSheet<String>(
  context: context,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(title: const Text('ঢাকা'), onTap: () => OmniSheet.of(context).close('ঢাকা')),
      ListTile(title: const Text('চট্টগ্রাম'), onTap: () => OmniSheet.of(context).close('চট্টগ্রাম')),
    ],
  ),
);
```

শিটের উচ্চতা কনটেন্টের সমান হয় (ডিফল্ট `OmniSheetDetent.content`)। বাইরে ট্যাপ করলে, নিচে টানলে বা
জোরে ফ্লিক করলে বন্ধ হয়।

## স্টাইল

| স্টাইল | দেখতে | চলন |
|---|---|---|
| `OmniSheetStyle.adaptive` (ডিফল্ট) | iOS/macOS-এ `cupertino`, বাকি সব জায়গায় `material` | — |
| `OmniSheetStyle.material` | উপরে ২৮dp গোল কোণ, ড্র্যাগ হ্যান্ডেল | দ্রুত, বাউন্স নেই, উপরে টানলে থেমে যায় |
| `OmniSheetStyle.cupertino` | iOS grabber, ১৪dp কোণ, বড় ডিটেন্টে স্ট্যাটাস বারের নিচে ফাঁকা | iOS স্প্রিং, উপরে টানলে রাবার-ব্যান্ডের মতো প্রসারিত হয় |
| `OmniSheetStyle.floating` | চারপাশে মার্জিন ও শ্যাডোসহ ভাসমান কার্ড, সব কোণ গোল | iOS স্প্রিং |

```dart
showOmniBottomSheet(context: context, style: OmniSheetStyle.floating, builder: ...);
```

## ডিটেন্ট (কোন উচ্চতায় থামবে)

```dart
showOmniBottomSheet(
  context: context,
  detents: const [OmniSheetDetent.medium, OmniSheetDetent.large], // ৫০% ও পুরো
  initialDetent: 0,
  builder: (context) => ListView.builder(   // কিছু না দিলেও লিস্ট শিটকে টানে
    itemCount: 100,
    itemBuilder: (_, i) => ListTile(title: Text('আইটেম $i')),
  ),
);
```

- ডিটেন্ট: `OmniSheetDetent.medium`, `.large`, `.fraction(0.3)`, `.height(420)`, `.content` (শুধু একা)।
- আঙুল ছাড়লে গতি (velocity) হিসাব করে কাছের ডিটেন্টে স্প্রিং করে থামে, iOS-এর মতো।
- **লিস্ট হ্যান্ড-অফ:** মাঝারি অবস্থায় লিস্ট উপরে টানলে আগে শিট বড় হয়, তারপর লিস্ট স্ক্রল হয়। লিস্ট
  একদম উপরে থাকলে নিচে টানলে শিট নামে। iOS/Android-এ নিজে থেকেই হয়; ডেস্কটপে
  `controller: OmniSheet.of(context).scrollController` দিন।

## শিটের ভেতর থেকে নিয়ন্ত্রণ

```dart
final sheet = OmniSheet.of(context);
sheet.snapTo(1);              // বড় ডিটেন্টে যাও
sheet.close(result);          // বন্ধ করে ফলাফল ফেরত দাও
ValueListenableBuilder(       // কোন ডিটেন্টে আছে
  valueListenable: sheet.detent,
  builder: (_, i, _) => Text(i == 0 ? 'আরও দেখুন' : 'কম দেখুন'),
);
```

হ্যান্ডেলে ট্যাপ করলে পরের ডিটেন্টে যায় (স্ক্রিন রিডার ও মাউসের জন্যও)।

## বন্ধ হওয়া আটকানো (ফর্মে না-সেভ করা লেখা)

```dart
builder: (context) => PopScope(
  canPop: !hasUnsavedChanges,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop) showDiscardDialog(context);
  },
  child: MyForm(),
),
```

টেনে নামালে শিট আবার স্প্রিং করে উপরে ফিরে আসে এবং `onPopInvokedWithResult` চলে।
`isDismissible: false` দিলে বাইরে ট্যাপ ও টেনে নামানো — দুটোই বন্ধ (টানলে রাবার-ব্যান্ড)।

## নিজের মতো সাজানো

```dart
showOmniBottomSheet(
  context: context,
  style: OmniSheetStyle.cupertino,
  backgroundColor: Colors.white,
  handleColor: Colors.black26,
  barrierColor: Colors.black38,
  cornerRadius: 24,
  maxWidth: 520,                       // ট্যাবলেট/ডেস্কটপে মাঝখানে
  margin: const EdgeInsets.all(16),    // floating স্টাইলে
  shadow: const [BoxShadow(blurRadius: 30, color: Color(0x33000000))],
  showHandle: false,
  enableDrag: true,
  motion: OmniSheetMotion.bouncy,      // ios · material · snappy · bouncy
  builder: ...,
);

// নিজের স্প্রিং: response = এক দোলনের সময় (সেকেন্ড), dampingRatio 1 = বাউন্স নেই
const OmniSheetMotion(response: 0.38, dampingRatio: 0.85, rubberBand: true, dismissVelocity: 800);
```

রঙ না দিলে আসে: Omni থিম থাকলে `bottomSheetColor` / `overlayColor`, শুধু Material থিম থাকলে
`bottomSheetTheme`, আর `CupertinoApp`-এ iOS সিস্টেম রঙ (ডার্ক মোডসহ)।

নিজে route push করতে চাইলে: `Navigator.of(context).push(OmniSheetRoute(builder: ...))`।

## পারফরম্যান্স

- খোলা, বন্ধ আর টানার সময় শুধু একটি লেয়ার নতুন করে আঁকা হয়। কনটেন্ট একবারই build হয় (টেস্টে মাপা)।
- এক ডিটেন্ট থেকে আরেকটিতে যাওয়ার সময় শিট iOS-এর মতো আকার বদলায়, তাই নিচে আটকানো বাটনও দেখা যায়।
- স্প্রিং ঠিক জায়গায় এসে থামে, তারপর আর কোনো frame চলে না।
- কিবোর্ড খুললে শিট কিবোর্ডের ওপরে ওঠে।
- সিস্টেমে "Reduce motion" চালু থাকলে স্লাইড না করে শুধু ফেড হয়।

---

# স্কেলেবল শিট — পেজের ওপর থাকা শিট (`OmniScalableSheet`)

Maps বা Music অ্যাপের মতো: শিট পেজের ওপরেই থাকে, পেছনের পেজ ব্যবহার করা যায়। টেনে ছোট-বড় করা যায়,
নির্দিষ্ট সাইজগুলোতে গিয়ে আটকে থাকে, আর প্রথমবার খোলার সময় নির্দিষ্ট সাইজে খোলে। চারটি স্টাইলেই
(`floating`-সহ) কাজ করে।

```dart
final sheet = OmniScalableSheetController();   // ঐচ্ছিক; dispose() করবেন

Scaffold(
  appBar: AppBar(title: const Text('Map')),
  body: OmniScalableSheet(
    controller: sheet,
    style: OmniSheetStyle.floating,          // adaptive · material · cupertino · floating
    detents: const [
      OmniSheetDetent.height(150),           // সবচেয়ে ছোট = নিচের সীমা
      OmniSheetDetent.medium,
      OmniSheetDetent.large,                 // সবচেয়ে বড় = ওপরের সীমা
    ],
    initialDetent: 1,                        // প্রথমবার মাঝারি সাইজে খুলবে
    dimFromDetent: 1,                        // মাঝারির পর বড় হলে পেছনের পেজ ধীরে ধীরে কালচে
    body: const MapView(),
    builder: (context) => ListView(...),     // ভেতরের লিস্ট টেনেও শিট বড়-ছোট হয়
  ),
)
```

- **আটকে থাকা:** আঙুল ছাড়লে গতি দেখে কাছের সাইজে spring করে থামে। সবচেয়ে ছোটটির নিচে বা সবচেয়ে বড়টির
  ওপরে যায় না — টানলে রাবারের মতো একটু প্রসারিত হয়ে ফিরে আসে।
- **প্রথম খোলা:** `initialDetent` সাইজে নিচ থেকে স্লাইড করে ওঠে; `animateOnOpen: false` দিলে প্রথম
  frame-এই জায়গামতো থাকে।
- **পেছনের পেজ:** শিটের বাইরে ট্যাপ সরাসরি পেজে যায়। `dimFromDetent` দিলে সেই সাইজের পর পেজ কালচে হয় এবং
  তখন পেজে ট্যাপ করলে শিট আবার ছোট হয়।
- **Back বাটন:** বড় অবস্থায় Back চাপলে আগে শিট ছোট হয় (`collapseOnBack`, ডিফল্ট চালু)।
- **লুকানো:** `isDismissible: true` দিলে সবচেয়ে ছোটটির নিচে টানলে শিট লুকায় (`onDismissed`);
  `sheet.show()` দিয়ে ফেরত আনুন। কোড থেকে `sheet.hide()` সবসময় কাজ করে।

### কন্ট্রোলার

```dart
sheet.snapTo(2);        // সূচক ছোট থেকে বড় ক্রমে
sheet.expand();         // সবচেয়ে বড়
sheet.collapse();       // সবচেয়ে ছোট
sheet.detent;           // ValueListenable<int>
sheet.isShown;          // ValueListenable<bool>
sheet.height;           // ValueListenable<double> — প্রতি frame-এ দৃশ্যমান উচ্চতা

// শিটের ঠিক ওপরে ভাসমান বাটন (পেজ রিবিল্ড ছাড়াই সাথে সাথে চলে)
AnimatedBuilder(
  animation: sheet.height,
  builder: (context, child) =>
      Positioned(right: 16, bottom: sheet.height.value + 16, child: child!),
  child: FloatingActionButton(onPressed: sheet.expand, child: const Icon(Icons.list)),
)
```

শিটের ভেতর থেকে `OmniSheet.of(context)` (`snapTo`, `close` = লুকানো, `detent`, `scrollController`)
একইভাবে কাজ করে।

রঙ, কোণ, মার্জিন, শ্যাডো, হ্যান্ডেল, `motion`, `onDetentChanged` — modal শিটের মতোই সব বদলানো যায়।
Modal শিট ও স্কেলেবল শিট একই ইঞ্জিন ব্যবহার করে, তাই ড্র্যাগ, স্প্রিং ও পারফরম্যান্স (শুধু রিপেইন্ট,
কনটেন্ট একবার build) দুটোতেই এক।
