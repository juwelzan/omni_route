# প্রি-ডিফাইনড UI এলিমেন্ট — কী কী রাখা যায় (প্রস্তাব)

> **অবস্থা:** শুধু প্রস্তাব, এখনো কিছু তৈরি হয়নি। কোনগুলো বানাতে হবে বেছে দিলে সেগুলো তৈরি করা হবে।
> নিচের সব নাম ও API প্রস্তাবিত; বানানোর সময় সামান্য বদলাতে পারে।

## কেন

এখন প্যাকেজে আছে: টেক্সট ফিল্ড (`OmniEmailField`, `OmniPasswordField`, `OmniOtpField` …), থিম পিকার/প্যানেল,
ভাষা পিকার, লেখার আকার পিকার, রেসপন্সিভ লেআউট। কিন্তু প্রায় প্রতিটি অ্যাপে যা বারবার লিখতে হয় —
বাটনের লোডিং অবস্থা, কনফার্ম ডায়ালগ, খালি/এরর স্ক্রিন, অ্যালার্ট বক্স, স্কেলেটন — সেগুলো নেই।

## প্রতিটি এলিমেন্টের নিয়ম (যাতে ডেভেলপারকে নতুন কোড লিখতে না হয়)

1. **রঙ শুধু থিম থেকে:** `context.colors` (৭৫টি রঙ), `context.styles`। থিম বা ডার্ক মোড বদলালে নিজে থেকেই বদলায়।
2. **লেখা শুধু `context.textStyles` থেকে:** লেখার আকার (ছোট/মাঝারি/বড়) ও ভাষার ফন্ট নিজে থেকেই প্রযোজ্য।
3. **বিল্ট-ইন লেখা অনুবাদ করা:** "Retry", "Cancel", "Delete", "No results" ইত্যাদি en/bn/ar/hi-তে আগে থেকেই থাকবে। RTL ঠিক থাকবে।
4. **রেসপন্সিভ:** প্যাডিং, রেডিয়াস, আকার `context.ui.tokens` থেকে আসবে। মোবাইলে বটমশিট, ডেস্কটপে ডায়ালগ।
5. **পারফরম্যান্স:** `const` কনস্ট্রাক্টর, যা বদলায় শুধু সেটুকু রিবিল্ড, অ্যানিমেশন `RepaintBoundary`-তে,
   সিস্টেমে "Reduce motion" চালু থাকলে অ্যানিমেশন বন্ধ।
6. **অ্যাক্সেসিবিলিটি:** স্ক্রিন রিডারের `Semantics`, ন্যূনতম ৪৮dp ট্যাপ এরিয়া, কিবোর্ড ফোকাস (`focusColor`)।

---

## অগ্রাধিকার এক নজরে

| অগ্রাধিকার | এলিমেন্ট |
|---|---|
| **P1** — প্রায় সব অ্যাপে লাগে | `OmniButton`, `OmniCard`, `OmniAlert`, `OmniEmptyState` / `OmniErrorState` / `OmniLoadingState`, `showOmniConfirm`, `context.showSuccess(...)` টোস্ট, `OmniSkeleton`, `OmniAvatar` |
| **P2** — বেশিরভাগ অ্যাপে লাগে | `OmniAsyncView`, `OmniSection`, `OmniSwitchTile` / `OmniCheckboxTile`, `OmniBadge` / `OmniStatusChip`, `OmniStatTile`, `OmniDropdownField`, `OmniDateField`, `showOmniActionSheet`, `OmniDividerText` |
| **P3** — নির্দিষ্ট ধরনের অ্যাপে | `OmniStepper`, `OmniRating`, `OmniPriceText`, `OmniKeyValueRow`, `OmniTagList`, `showOmniInputDialog` |

---

## ১. বাটন

### `OmniButton` (P1)
এক উইজেটে সব ধরনের বাটন, লোডিং অবস্থা ও আইকনসহ। রঙ ও আকৃতি থিমের `buttonColor`, `dangerButtonColor`,
`buttonShape` থেকে আসে।

```dart
OmniButton(
  label: 'সেভ করুন',
  onPressed: save,                 // async হলে নিজে থেকেই লোডিং দেখায়, দুবার চাপা যায় না
)

OmniButton.secondary(label: 'বাতিল', onPressed: () => context.pop())
OmniButton.danger(label: 'মুছে ফেলুন', icon: Icons.delete, onPressed: delete)
OmniButton.outline(label: 'আরও দেখুন', onPressed: more)
OmniButton.link(label: 'পাসওয়ার্ড ভুলে গেছেন?', onPressed: forgot)

OmniButton(
  label: 'অর্ডার করুন',
  size: OmniButtonSize.large,      // small · medium · large
  expand: true,                    // পুরো প্রস্থ
  onPressed: order,
)
```

- `onPressed` একটা `Future` ফেরত দিলে শেষ না হওয়া পর্যন্ত স্পিনার দেখায় এবং আবার চাপা আটকায়।
- স্পিনার দেখানোর সময়ও বাটনের প্রস্থ একই থাকে (লেআউট লাফ দেয় না)।

### `OmniIconButton` (P2)
`filled`, `tonal`, `outline`, `plain` ধরনের আইকন বাটন। এতে টুলটিপ ও স্ক্রিন রিডারের লেবেল বাধ্যতামূলক।

```dart
OmniIconButton.tonal(icon: Icons.favorite, tooltip: 'পছন্দ', onPressed: like)
```

---

## ২. অবস্থা ও ফিডব্যাক

### `OmniAlert` (P1)
তথ্য / সফল / সতর্কতা / এরর বক্স। থিমের `infoBoxDecoration` ইত্যাদি ব্যবহার করে।

```dart
const OmniAlert.warning(
  title: 'পেমেন্ট বাকি',
  message: 'আপনার সাবস্ক্রিপশন ৩ দিনে শেষ হবে।',
)

OmniAlert.error(
  message: 'ইন্টারনেট সংযোগ নেই',
  action: OmniAlertAction(label: 'আবার চেষ্টা', onPressed: retry),
  onClose: dismiss,
)
```

### টোস্ট / স্ন্যাকবার: `context.showSuccess(...)` (P1)
এক লাইনে থিমড স্ন্যাকবার। একসাথে কয়েকটা এলে লাইনে দাঁড়ায়, একটার ওপর আরেকটা পড়ে না।

```dart
context.showSuccess('প্রোফাইল আপডেট হয়েছে');
context.showError('সেভ হয়নি', action: ('আবার', retry));
context.showInfo('নতুন ভার্সন এসেছে');
context.showWarning('ব্যাটারি কম');
```

### `OmniEmptyState`, `OmniErrorState`, `OmniLoadingState` (P1)
খালি লিস্ট, এরর ও লোডিং স্ক্রিন। ডিফল্ট লেখা অনুবাদ করা থাকে।

```dart
const OmniEmptyState(
  icon: Icons.inbox_outlined,
  title: 'কোনো অর্ডার নেই',
  message: 'প্রথম অর্ডার করলে এখানে দেখা যাবে।',
)

OmniErrorState(error: e, onRetry: load)  // "Retry" বাটন নিজে থেকেই অনুবাদ হয়
const OmniLoadingState(message: 'লোড হচ্ছে…')
```

### `OmniSkeleton` (P1)
লোডিংয়ের সময় শিমার করা প্লেসহোল্ডার। রঙ আসে `shimmerBaseColor` আর `shimmerHighlightColor` থেকে।

```dart
OmniSkeleton.listTile(count: 6)         // অ্যাভাটার + ২ লাইন
OmniSkeleton.card(height: 120)
OmniSkeleton.text(lines: 3)
OmniSkeleton(child: MyRealLayout())     // আসল লেআউটের আকারেই শিমার
```

- পুরো স্ক্রিনে একটাই অ্যানিমেশন কন্ট্রোলার চলে, প্রতিটা বক্সের জন্য আলাদা নয়।
- "Reduce motion" চালু থাকলে শিমার না করে স্থির থাকে।

### `OmniBadge`, `OmniStatusChip` (P2)

```dart
OmniBadge(count: 5, child: Icon(Icons.notifications))   // 99+ নিজে থেকে
const OmniStatusChip.success('পরিশোধিত')
const OmniStatusChip.warning('পেন্ডিং')
const OmniStatusChip.error('বাতিল')
```

---

## ৩. কন্টেইনার ও তালিকা

### `OmniCard` (P1)

```dart
OmniCard(
  onTap: open,                        // ট্যাপ, হোভার ও ফোকাস ইফেক্ট থিম থেকে
  child: Text('অর্ডার #1024'),
)
OmniCard.elevated(child: ...)
OmniCard.subtle(child: ...)
OmniCard.selectable(selected: isSelected, onTap: select, child: ...)  // প্ল্যান/পেমেন্ট বাছাই
```

### `OmniSection` (P2)
শিরোনাম, ঐচ্ছিক "সব দেখুন" অ্যাকশন আর কনটেন্ট। ড্যাশবোর্ড ও সেটিংস স্ক্রিনের জন্য।

```dart
OmniSection(
  title: 'সাম্প্রতিক লেনদেন',
  action: OmniSectionAction.seeAll(onPressed: openAll),  // "See all" অনুবাদ করা
  child: TransactionList(),
)
```

### `OmniSwitchTile`, `OmniCheckboxTile`, `OmniRadioGroup<T>` (P2)

```dart
OmniSwitchTile(
  title: 'নোটিফিকেশন',
  subtitle: 'নতুন মেসেজ এলে জানাবে',
  value: on,
  onChanged: (v) => setState(() => on = v),
)

OmniRadioGroup<Plan>(
  value: plan,
  options: {Plan.free: 'ফ্রি', Plan.pro: 'প্রো'},
  onChanged: (p) => setState(() => plan = p),
)
```

### `OmniDividerText` (P2)

```dart
const OmniDividerText('অথবা')   // ─────── অথবা ───────
```

---

## ৪. ডায়ালগ ও শিট

### `showOmniConfirm` (P1)
নিশ্চিত করার ডায়ালগ। মোবাইলে বটমশিট, ট্যাবলেট ও ডেস্কটপে ডায়ালগ হিসেবে দেখায়। `danger: true` দিলে
নিশ্চিত করার বাটন লাল হয়।

```dart
final ok = await showOmniConfirm(
  context,
  title: 'অ্যাকাউন্ট মুছবেন?',
  message: 'এটি আর ফেরানো যাবে না।',
  confirmLabel: 'মুছে ফেলুন',      // না দিলে "OK"/"ঠিক আছে" অনুবাদ করা
  danger: true,
);
if (ok) deleteAccount();
```

### `showOmniActionSheet` (P2)

```dart
final choice = await showOmniActionSheet<String>(
  context,
  actions: [
    OmniSheetAction('camera', 'ক্যামেরা', icon: Icons.photo_camera),
    OmniSheetAction('gallery', 'গ্যালারি', icon: Icons.photo),
    OmniSheetAction.danger('remove', 'ছবি সরান', icon: Icons.delete),
  ],
);
```

### `showOmniInputDialog` (P3)

```dart
final name = await showOmniInputDialog(
  context,
  title: 'ফোল্ডারের নাম',
  validator: OmniValidators.required(),
);
```

---

## ৫. ডেটা দেখানো

### `OmniAvatar` (P1)
ছবি না থাকলে নামের আদ্যক্ষর দেখায়। রঙ নাম থেকে ঠিক হয় বলে একই নামের রঙ সবসময় একই থাকে।
বাংলা ও আরবি নামেও কাজ করে।

```dart
OmniAvatar(name: 'জুয়েল রানা', imageUrl: user.photo, size: OmniAvatarSize.medium)
OmniAvatar.group(names: members, max: 3)    // ৩টা + "+5"
```

### `OmniStatTile` (P2)
ড্যাশবোর্ডের KPI টাইল। সংখ্যা ভাষা অনুযায়ী ফরম্যাট হয় (বাংলায় ১২,৫০০)।

```dart
OmniStatTile(
  label: 'আজকের বিক্রি',
  value: 12500,
  change: 0.12,          // ▲ 12% সবুজ, নেগেটিভ হলে লাল
  icon: Icons.trending_up,
)
```

### `OmniKeyValueRow`, `OmniPriceText`, `OmniTagList`, `OmniRating` (P3)

```dart
const OmniKeyValueRow('অর্ডার আইডি', '#A-1024', copyable: true)
OmniPriceText(1299.5, currency: 'BDT')         // ৳১,২৯৯.৫০
OmniTagList(tags: ['Flutter', 'Dart'], onTap: filter)
OmniRating(value: 4.5, onChanged: rate)
```

---

## ৬. ফর্ম (এখনকার ফিল্ডের সাথে মিলিয়ে)

### `OmniDropdownField<T>`, `OmniDateField`, `OmniTimeField` (P2)
এখনকার Omni ফিল্ডের মতোই লেবেল, এরর, থিম ও অনুবাদ থাকবে। ডেট পিকার থিমের `dialogColor` নেয়।

```dart
OmniDropdownField<String>(
  label: 'জেলা',
  items: districts,
  value: district,
  onChanged: (v) => setState(() => district = v),
  searchable: true,
)

OmniDateField(
  label: 'জন্মতারিখ',
  lastDate: DateTime.now(),
  onChanged: (d) => birth = d,
)
```

### `OmniForm` (P2)
সাবমিট করার সময় সব ফিল্ড যাচাই করে প্রথম ভুল ফিল্ডে স্ক্রল ও ফোকাস করে। সাবমিট চলার সময়
`OmniButton` নিজে থেকেই লোডিং দেখায়।

```dart
OmniForm(
  onSubmit: (values) async => api.register(values),
  child: Column(children: [
    const OmniNameField(),
    const OmniEmailField(),
    const OmniPasswordField(),
    OmniForm.submitButton(label: 'রেজিস্টার'),
  ]),
)
```

---

## ৭. অ্যাসিঙ্ক ডেটা

### `OmniAsyncView<T>` (P2)
একটা `Future` বা `Stream` দিলেই লোডিং, এরর (আবার চেষ্টাসহ), খালি অবস্থা আর ডেটা দেখায়। ওপরের
`OmniLoadingState`, `OmniErrorState` আর `OmniEmptyState` ব্যবহার করে, তাই আলাদা কোড লাগে না।

```dart
OmniAsyncView<List<Order>>(
  load: api.orders,                 // বারবার রিবিল্ডেও একবারই কল হয়
  isEmpty: (list) => list.isEmpty,
  empty: const OmniEmptyState(title: 'কোনো অর্ডার নেই'),
  skeleton: OmniSkeleton.listTile(count: 5),
  builder: (context, orders) => OrderList(orders),
)
```

---

## ৮. ধাপ ও নেভিগেশন (P3)

```dart
OmniStepper(
  steps: const ['ঠিকানা', 'পেমেন্ট', 'নিশ্চিত'],
  current: 1,                       // প্রগ্রেসের রঙ আসে progressColor থেকে
)
```

---

## যা রাখা উচিত নয়

- **নিজস্ব AppBar বা Scaffold:** Flutter-এরটাই যথেষ্ট, আর থিম আগে থেকেই সেটাকে স্টাইল করে।
- **রঙ ও আকার হার্ডকোড করা যেকোনো উইজেট:** তাতে থিম আর লেখার আকারের সুবিধা হারায়।
- **চার্ট লাইব্রেরি:** এটা বড় আর আলাদা প্যাকেজের কাজ। শুধু `tertiaryColor` আর প্যালেটের রঙ দিয়ে সাহায্য করা যায়।
- **প্রতি উইজেটে আলাদা কনফিগ অবজেক্ট:** একটাই `OmniTheme` আর `OmniFieldTheme`-এর মতো ধরন যথেষ্ট।

## কোথায় রাখা হবে

`omni_responsive`-এর ভেতরে `lib/src/widgets/`-এ প্রতিটি উইজেট আলাদা ফাইলে থাকবে, ফিল্ডগুলোর মতো।
প্রতিটির সাথে থাকবে:
- থিম ও ডার্ক মোডের টেস্ট
- RTL টেস্ট
- লেখার আকার বড় করলেও লেআউট না ভাঙার টেস্ট
- রিবিল্ড গোনার টেস্ট
- `doc/`-এ বাংলা উদাহরণ

## সিদ্ধান্ত দরকার

1. কোন অগ্রাধিকার থেকে শুরু হবে? (প্রস্তাব: আগে পুরো P1)
2. নামগুলো কি ঠিক আছে (`OmniButton`, `showOmniConfirm`, `context.showSuccess`)?
3. `OmniForm` কি এখনকার Omni ফিল্ডগুলোর সাথে এখনই যুক্ত হবে, নাকি পরে?
