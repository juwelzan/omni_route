import 'package:flutter/material.dart';

/// ডেভেলপার-বান্ধব, পিওর নামে সহজে বোধগম্য ৫৫টি সেমান্টিক কালার প্যালেট (`context.colors`)।
///
/// Material-এর জটিল নাম (`onPrimaryContainer`, `surfaceContainerHigh`,
/// `outlineVariant`) মুখস্থ করার বদলে সরাসরি অর্থপূর্ণ নামে সব রঙ ব্যবহার করুন।
/// IDE-তে প্রতিটি নামের ওপর মাউস হোভার করলেই দেখতে পারবেন কালারটি কোথায় ও
/// কী কাজে ব্যবহার করা হয়।
///
/// হালকা থেকে ডার্ক বা এক থিম থেকে অন্য থিমে সুইচ করলে ফ্লাটারের নেটিভ
/// [ThemeExtension.lerp] স্বয়ংক্রিয়ভাবে রঙগুলো স্মুথলি পরিবর্তন করে দেয়।
@immutable
class OmniColors extends ThemeExtension<OmniColors> {
  /// প্রতিটি সেমান্টিক রোলের জন্য সুস্পষ্ট রঙসহ [OmniColors] তৈরি করে।
  const OmniColors({
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    required this.secondaryBackgroundColor,
    required this.cardColor,
    required this.appBarColor,
    required this.appBarTextColor,
    required this.navBarColor,
    required this.navSelectedColor,
    required this.navUnselectedColor,
    required this.statusBarColor,
    required this.systemNavigationBarColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.secondaryButtonColor,
    required this.secondaryButtonTextColor,
    required this.dangerButtonColor,
    required this.dangerButtonTextColor,
    required this.linkColor,
    required this.inputFillColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.dividerColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.hintTextColor,
    required this.iconColor,
    required this.chipColor,
    required this.chipTextColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.selectedItemColor,
    required this.hoverColor,
    required this.rippleColor,
    required this.disabledColor,
    required this.disabledTextColor,
    required this.disabledBorderColor,
    required this.switchActiveColor,
    required this.switchInactiveColor,
    required this.snackbarColor,
    required this.snackbarTextColor,
    required this.tooltipColor,
    required this.tooltipTextColor,
    required this.errorColor,
    required this.errorBackgroundColor,
    required this.warningColor,
    required this.warningBackgroundColor,
    required this.successColor,
    required this.successBackgroundColor,
    required this.infoColor,
    required this.infoBackgroundColor,
    required this.shimmerBaseColor,
    required this.shimmerHighlightColor,
    required this.overlayColor,
    required this.shadowColor,
  });

  /// ব্র্যান্ডের প্রধান প্রাইমারি কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** প্রগ্রেস বার, চেকবক্স/সুইচ অ্যাক্টিভ অবস্থা, সিলেক্টেড
  /// বর্ডার এবং ব্র্যান্ড হাইলাইট।
  /// **কী কাজে লাগে:** পুরো অ্যাপে ব্র্যান্ডের মূল পরিচিতি ও ফোকাস ফুটিয়ে তুলতে।
  final Color primaryColor;

  /// অ্যাপের সেকেন্ডারি বা সহায়ক অ্যাকসেন্ট কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** প্রোমো ব্যাজ, চার্ট হাইলাইট ও দ্বিতীয় অ্যাকসেন্ট ট্যাগ।
  /// **কী কাজে লাগে:** মূল [primaryColor]-এর পাশে দ্বিতীয় পর্যায়ের গুরুত্ব বোঝাতে।
  final Color secondaryColor;

  /// পুরো স্ক্রিন বা `Scaffold`-এর মূল ব্যাকগ্রাউন্ড কালার (সারফেস)।
  ///
  /// **কোথায় ব্যবহার হয়:** পেজের `Scaffold.backgroundColor`, মূল স্ক্রল ভিউ ও
  /// স্ক্রিনের বেস ক্যানভাস।
  /// **কী কাজে লাগে:** লাইট ও ডার্ক মোডে চোখের আরামদায়ক মূল পেজ ব্যাকগ্রাউন্ড দিতে।
  final Color surfaceColor;

  /// সেকশন হেডার, কোড ব্লক, টেবিলের বিকল্প রো ও ইনফো প্যানেলের দ্বিতীয় ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** গ্রুপড সেটিংস সেকশন, সামারি স্ট্রিপ, `subtleBoxDecoration`।
  /// **কী কাজে লাগে:** মূল [surfaceColor] ও [cardColor]-এর মাঝে হালকা লেয়ার আলাদা করতে।
  final Color secondaryBackgroundColor;

  /// কার্ড, কন্টেইনার, ডায়ালগ ও মোডাল শিটের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `Card`, `Dialog`, `BottomSheet`, `Container` বক্স
  /// এবং ড্যাশবোর্ড টাইল।
  /// **কী কাজে লাগে:** মূল [surfaceColor] পেজের ওপর থেকে তথ্য ব্লকগুলোকে আলাদা
  /// করে পরিষ্কারভাবে ফুটিয়ে তুলতে।
  final Color cardColor;

  /// অ্যাপবারের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** স্ক্রিনের ওপরের `AppBar.backgroundColor`।
  /// **কী কাজে লাগে:** টপ হেডারকে কন্টেন্ট থেকে পরিচ্ছন্নভাবে আলাদা করতে।
  final Color appBarColor;

  /// অ্যাপবারের টাইটেল টেক্সট ও অ্যাকশন আইকনের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `AppBar` শিরোনাম, ব্যাক বাটন আইকন ও মেনু আইকন।
  /// **কী কাজে লাগে:** [appBarColor]-এর ওপর স্পষ্ট কনট্রাস্ট নিশ্চিত করতে।
  final Color appBarTextColor;

  /// বটম নেভিগেশন বার ও সাইড নেভিগেশন রেলের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `NavigationBar`, `BottomNavigationBar` এবং ট্যাবলেট/
  /// ডেস্কটপ `NavigationRail`।
  /// **কী কাজে লাগে:** নেভিগেশন মেনু এবং মূল স্ক্রিন কন্টেন্টের মধ্যে লেয়ার আলাদা করতে।
  final Color navBarColor;

  /// নেভিগেশন বার/রেলে বর্তমানে সিলেক্ট করা ট্যাবের আইকন ও লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** সক্রিয় ট্যাব আইকন, অ্যাক্টিভ লেবেল এবং ড্রয়ার অ্যাক্টিভ আইটেম।
  /// **কী কাজে লাগে:** ইউজার এখন কোন ট্যাবে আছেন তা সঙ্গে সঙ্গে চিনিয়ে দিতে।
  final Color navSelectedColor;

  /// নেভিগেশন বার/রেলে আনসিলেক্টেড ট্যাবের আইকন ও লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** নিষ্ক্রিয় ট্যাব আইকন ও সাধারণ মেনু আইটেম টেক্সট।
  /// **কী কাজে লাগে:** সক্রিয় ট্যাবের তুলনায় বাকি ট্যাবগুলোকে শান্ত ও হালকা রাখতে।
  final Color navUnselectedColor;

  /// ডিভাইসের উপরের সিস্টেম স্ট্যাটাস বারের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** Android/iOS-এর সময়, নেটওয়ার্ক ও ব্যাটারি আইকন বার
  /// (ডিফল্ট `Colors.transparent` যাতে এজ-টু-এডজ মোডে পেজের সাথে মিশে যায়)।
  /// **কী কাজে লাগে:** প্রতিটি স্ক্রিনের ওপরের সিস্টেম বারকে থিমের সাথে মিলিয়ে রাখতে।
  final Color statusBarColor;

  /// ডিভাইসের নিচের সিস্টেম নেভিগেশন বার ও সোয়াইপ গেস্টচার বারের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** Android 3-বাটন নেভিগেশন ও গেস্টচার সোয়াইপ পিল এরিয়া
  /// (ডিফল্ট `Colors.transparent` — নিচে কোনো কালো বক্স বা ব্ল্যাক এরিয়া রাখে না)।
  /// **কী কাজে লাগে:** সোয়াইপ গেস্টচারের নিচের অংশকে কালো ডট/দাগ ছাড়াই অ্যাপের
  /// থিমের সাথে একদম মসৃণভাবে মিশিয়ে দিতে।
  final Color systemNavigationBarColor;

  /// প্রধান অ্যাকশন বাটনের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `FilledButton`, `ElevatedButton`, লগইন/সাবমিট/সেভ
  /// বাটন এবং `FloatingActionButton`।
  /// **কী কাজে লাগে:** স্ক্রিনের সবচেয়ে গুরুত্বপূর্ণ ক্লিকেবল বাটন চোখে তুলে ধরতে।
  final Color buttonColor;

  /// প্রধান বাটনের ভেতরের লেখা ও আইকনের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `FilledButton` ও `ElevatedButton`-এর ভেতরের `Text`
  /// ও `Icon`।
  /// **কী কাজে লাগে:** [buttonColor]-এর ওপর উচ্চ-কনট্রাস্ট পরিষ্কার লেখা দেখাতে।
  final Color buttonTextColor;

  /// সেকেন্ডারি বা সহায়ক বাটনের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** "Cancel", "Back", "Filter", "Edit" বা সাবমিটের
  /// পাশের দ্বিতীয় বাটন (`context.styles.secondaryButton`)।
  /// **কী কাজে লাগে:** প্রাইমারি বাটনের চেয়ে গুরুত্ব একটু কম কিন্তু পরিষ্কার বাটন দিতে।
  final Color secondaryButtonColor;

  /// সেকেন্ডারি বাটনের ভেতরের লেখা ও আইকনের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** সেকেন্ডারি বাটনের `Text` ও `Icon`।
  /// **কী কাজে লাগে:** [secondaryButtonColor]-এর ওপর লেখা পড়া সহজ করতে।
  final Color secondaryButtonTextColor;

  /// ডিলিট, রিমুভ বা লগআউট জাতীয় ঝুঁকিপূর্ণ বাটনের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** "Delete Account", "Remove Item", "Logout" বাটন
  /// (`context.styles.dangerButton`)।
  /// **কী কাজে লাগে:** ডেস্ট্রাক্টিভ বাটন চাপার আগে ইউজারকে সতর্ক সংকেত দিতে।
  final Color dangerButtonColor;

  /// ডিলিট/ডেঞ্জার বাটনের ভেতরের লেখা ও আইকনের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ডিলিট বা লগআউট বাটনের ভেতরের `Text` ও `Icon`।
  /// **কী কাজে লাগে:** [dangerButtonColor]-এর ওপর স্পষ্ট সাদা/হালকা লেখা দেখাতে।
  final Color dangerButtonTextColor;

  /// ক্লিকেবল লিংক ও `TextButton`-এর লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** "Forgot Password?", "See All", ব্রেডক্রাম্ব লিংক ও
  /// সব `TextButton`।
  /// **কী কাজে লাগে:** টেক্সটটি যে ক্লিক করা যায় তা বোঝাতে।
  final Color linkColor;

  /// `TextField` ও `TextFormField`-এর ভেতরের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ফর্ম ইনপুট বক্স, সার্চ বার, ও ড্রপডাউন ফিল্ড।
  /// **কী কাজে লাগে:** ইউজার কোথায় টাইপ করবেন তা পরিষ্কারভাবে চিহ্নিত করতে।
  final Color inputFillColor;

  /// সাধারণ কার্ড, বক্স, আউটলাইন বাটন ও টেক্সট ফিল্ডের নরমাল চারপাশের বর্ডার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `BoxDecoration(border: ...)`, `OutlinedButton` এবং
  /// আনফোকাসড `TextField` বর্ডার।
  /// **কী কাজে লাগে:** অতিরিক্ত শ্যাডো ছাড়াই উপাদানগুলোর সীমানা সূক্ষ্মভাবে বোঝাতে।
  final Color borderColor;

  /// ইনপুট ফিল্ড বা কার্ড ফোকাস/সিলেক্ট হলে চারপাশে যে উজ্জ্বল বর্ডার কালার হয়।
  ///
  /// **কোথায় ব্যবহার হয়:** টাইপ করার সময় সক্রিয় `TextField` বর্ডার, এবং সিলেক্ট
  /// করা অপশন কার্ড।
  /// **কী কাজে লাগে:** ইউজার কোন ফিল্ড বা কার্ডে কাজ করছেন তা হাইলাইট করতে।
  final Color focusedBorderColor;

  /// দুটি সেকশন, রো বা লিস্ট আইটেমের মাঝের পাতলা বিভাজক লাইন কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `Divider`, `VerticalDivider` এবং `ListView.separated`।
  /// **কী কাজে লাগে:** পাশাপাশি থাকা ডেটা রো আলাদা করে সাজাতে।
  final Color dividerColor;

  /// মূল হেডলাইন, টাইটেল ও প্যারাগ্রাফ লেখার সাধারণ টেক্সট কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** পেজ টাইটেল, কার্ড শিরোনাম, ইনপুট লেখা ও বডি টেক্সট।
  /// **কী কাজে লাগে:** [surfaceColor] ও [cardColor]-এর ওপর সর্বোচ্চ পঠনযোগ্যতা দিতে।
  final Color textColor;

  /// সাবটাইটেল, তারিখ, ক্যাপশন বা দ্বিতীয় পর্যায়ের লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `ListTile.subtitle`, বিবরণ, মেটাডেটা ও সময়/সংখ্যা।
  /// **কী কাজে লাগে:** মূল লেখার তুলনায় সহায়ক তথ্যকে হালকা ও গোছানো রাখতে।
  final Color secondaryTextColor;

  /// টেক্সট ফিল্ডের ভেতরের খালি অবস্থার হিন্ট বা প্লেসহোল্ডার টেক্সট কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `InputDecoration.hintText` ও সার্চ প্লেসহোল্ডার।
  /// **কী কাজে লাগে:** আসল ইনপুট আর উদাহরণের লেখার মধ্যে পার্থক্য বোঝাতে।
  final Color hintTextColor;

  /// সাধারণ আইকন ও টুলবার চিহ্নের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `ListTile` আইকন, সার্চ আইকন, ট্রেলিং অ্যারো।
  /// **কী কাজে লাগে:** পুরো অ্যাপের আইকনগুলোর সামঞ্জস্য বজায় রাখতে।
  final Color iconColor;

  /// ট্যাগ, ক্যাটাগরি চিপ ও ফিল্টার পিলের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `Chip`, `FilterChip`, ক্যাটাগরি ট্যাগ ও সার্চ টোকেন।
  /// **কী কাজে লাগে:** ছোট ফিল্টার বা ট্যাগগুলোকে নরম ব্যাকগ্রাউন্ডে আলাদা দেখাতে।
  final Color chipColor;

  /// ট্যাগ বা ফিল্টার চিপের ভেতরের লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `Chip` ও ট্যাগের `Text`/`Icon`।
  /// **কী কাজে লাগে:** [chipColor]-এর ওপর পরিষ্কার কনট্রাস্ট দিতে।
  final Color chipTextColor;

  /// নোটিফিকেশন কাউন্টার ডট, "NEW" বা ডিসকাউন্ট ব্যাজের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** বেল আইকনের লাল/ব্র্যান্ড ডট, কার্ট কাউন্ট, `"50% OFF"`।
  /// **কী কাজে লাগে:** গুরুত্বপূর্ণ সংখ্যা বা নতুন নোটিফিকেশনে দৃষ্টি আকর্ষণ করতে।
  final Color badgeColor;

  /// ব্যাজের ভেতরের সংখ্যা বা ছোট লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** নোটিফিকেশন ব্যাজের ভেতরের টেক্সট (`"9+"`)।
  /// **কী কাজে লাগে:** ছোট ব্যাজের ভেতরের সংখ্যা স্পষ্ট রাখতে।
  final Color badgeTextColor;

  /// লিস্ট, ড্রপডাউন বা মাস্টার-ডিটেইল টেবিলে সিলেক্ট করা সারির ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** মাস্টার-ডিটেইল অ্যাক্টিভ রো, সিলেক্টেড ড্রয়ার মেনু আইটেম।
  /// **কী কাজে লাগে:** কোন আইটেমটি সিলেক্ট করা আছে তা হালকা হাইলাইটে দেখাতে।
  final Color selectedItemColor;

  /// ডেস্কটপ/ওয়েবে মাউস হোভার করলে কার্ড বা লিস্ট রো-তে হালকা যে রঙ দেখা যায়।
  ///
  /// **কোথায় ব্যবহার হয়:** `InkWell.hoverColor`, টেবিল রো হোভার ও বাটন হোভার।
  /// **কী কাজে লাগে:** মাউস পয়েন্টারে ইন্টার‍্যাক্টিভ ফিডব্যাক দিতে।
  final Color hoverColor;

  /// বাটন, কার্ড বা `ListTile`-এ ট্যাপ করলে যে রিপল/স্প্ল্যাশ ঢেউ ছড়িয়ে পড়ে তার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `InkWell.splashColor`, বাটন ট্যাপ ফিডব্যাক ও রিপল ইফেক্ট।
  /// **কী কাজে লাগে:** টাচ বা ক্লিকের তাৎক্ষণিক ভিজ্যুয়াল সাড়া প্যালেট অনুযায়ী দিতে।
  final Color rippleColor;

  /// নিষ্ক্রিয় বা ডিজেবল অবস্থার বাটন ও ইনপুটের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `onPressed: null` বাটন ও `enabled: false` ফিল্ড।
  /// **কী কাজে লাগে:** উপাদানটি এখন কাজ করছে না তা স্পষ্টভাবে বোঝাতে।
  final Color disabledColor;

  /// নিষ্ক্রিয় বা ডিজেবল অবস্থার বাটন/ইনপুটের ভেতরের লেখা ও আইকনের কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ডিজেবল বাটনের টেক্সট ও রিড-অনলি ফিল্ডের লেখা।
  /// **কী কাজে লাগে:** নিষ্ক্রিয় অবস্থা পরিষ্কারভাবে প্রকাশ করতে।
  final Color disabledTextColor;

  /// নিষ্ক্রিয় (disabled) `TextField`, ড্রপডাউন বা `OutlinedButton`-এর বর্ডার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** নিষ্ক্রিয় ইনপুটের চারপাশের বর্ডার, `disabledBoxDecoration`।
  /// **কী কাজে লাগে:** সক্রিয় ইনপুট বর্ডার থেকে ডিজেবল ফিল্ড সহজে আলাদা করতে।
  final Color disabledBorderColor;

  /// `Switch`, `Checkbox`, ও `Radio` বাটন চালু/সিলেক্টেড (active) অবস্থার রঙ।
  ///
  /// **কোথায় ব্যবহার হয়:** সেটিংস `Switch`, ফর্ম `Checkbox` ও `Radio`।
  /// **কী কাজে লাগে:** কোনো অপশন চালু আছে তা প্যালেট রঙের সাথে মিলিয়ে দেখাতে।
  final Color switchActiveColor;

  /// `Switch`, `Checkbox`, ও স্লাইডার ট্র্যাকের বন্ধ/আনচেকড (inactive) অবস্থার রঙ।
  ///
  /// **কোথায় ব্যবহার হয়:** বন্ধ অবস্থার `Switch` নাব/ট্র্যাক এবং আনসিলেক্টেড `Radio`।
  /// **কী কাজে লাগে:** চালু বনাম বন্ধ অবস্থার মধ্যে পরিষ্কার পার্থক্য তৈরি করতে।
  final Color switchInactiveColor;

  /// `SnackBar` বা নিচের টোস্ট নোটিফিকেশনের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `ScaffoldMessenger.showSnackBar`, স্ট্যাটাস টোস্ট।
  /// **কী কাজে লাগে:** লাইট ও ডার্ক দুই মোডেই চোখে পড়ার মতো নোটিফিকেশন বার দেখাতে।
  final Color snackbarColor;

  /// `SnackBar` বা টোস্টের ভেতরের লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** স্ন্যাকবার মেসেজ টেক্সট।
  /// **কী কাজে লাগে:** [snackbarColor]-এর ওপর স্পষ্ট পঠনযোগ্য লেখা নিশ্চিত করতে।
  final Color snackbarTextColor;

  /// হোভার বা লং-প্রেস `Tooltip` বক্সের ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** আইকন বাটন হোভার হিন্ট ও `Tooltip`।
  /// **কী কাজে লাগে:** ছোট সহায়ক টিপস মূল কনটেন্ট থেকে আলাদা দেখাতে।
  final Color tooltipColor;

  /// `Tooltip` বক্সের ভেতরের লেখার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** টুলটিপ হিন্ট টেক্সট।
  /// **কী কাজে লাগে:** [tooltipColor]-এর ওপর উচ্চ-কনট্রাস্ট পরিষ্কার লেখা দিতে।
  final Color tooltipTextColor;

  /// ভুল, ফর্ম এরর বা কানেকশন ব্যর্থতার মূল লাল কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ফর্ম ভ্যালিডেশন মেসেজ, এরর বর্ডার ও ফেইলড আইকন।
  /// **কী কাজে লাগে:** কোনো সমস্যা বা ভুল তাৎক্ষণিকভাবে ইউজারকে জানাতে।
  final Color errorColor;

  /// এরর ব্যানার বা অ্যালার্ট বক্সের পেছনের হালকা ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** এরর `SnackBar`/`Card` ব্যাকগ্রাউন্ড (লেখা হবে [errorColor])।
  /// **কী কাজে লাগে:** চোখে না লেগে পরিষ্কারভাবে এরর অ্যালার্ট বক্স সাজাতে।
  final Color errorBackgroundColor;

  /// সতর্কতা, পেন্ডিং অবস্থা বা মনোযোগ আকর্ষণের মূল ওয়ার্নিং কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** পেন্ডিং পেমেন্ট, ওয়ার্নিং অ্যালার্ট ও সতর্কতা আইকন।
  /// **কী কাজে লাগে:** সাবধান থাকা বা অ্যাকশন নেওয়া দরকার এমন সংকেত দিতে।
  final Color warningColor;

  /// ওয়ার্নিং কার্ড বা নোটিশ ব্যানারের পেছনের হালকা ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ওয়ার্নিং ট্যাগ বা ব্যানারের ব্যাকগ্রাউন্ড।
  /// **কী কাজে লাগে:** [warningColor] লেখার নিচে আরামদায়ক ব্যাকগ্রাউন্ড দিতে।
  final Color warningBackgroundColor;

  /// সফল, ভেরিফাইড, পেইড বা অনলাইন অবস্থার মূল সাকসেস কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** অর্ডার কনফার্ম, ভেরিফাইড চেকমার্ক ও "Paid" ব্যাজ।
  /// **কী কাজে লাগে:** কাজ সফল হয়েছে বা সবকিছু ঠিক আছে তা জানাতে।
  final Color successColor;

  /// সাকসেস ব্যানার বা "Paid/Verified" ট্যাগের পেছনের হালকা ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** সফল টোস্ট, স্ট্যাটাস চিপ ও সাকসেস কার্ড।
  /// **কী কাজে লাগে:** [successColor] টেক্সটের নিচে স্পষ্ট কনট্রাস্ট দিতে।
  final Color successBackgroundColor;

  /// তথ্য, হিন্ট, গাইড বা নতুন আপডেট নোটিশের মূল ইনফো কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** ইনফরমেশন ব্যানার, টিপস আইকন ও ভার্সন নোটিশ।
  /// **কী কাজে লাগে:** নিরপেক্ষ গুরুত্বপূর্ণ তথ্য সুন্দরভাবে আলাদা করতে।
  final Color infoColor;

  /// ইনফরমেশন বক্স বা টিপস ব্যানারের পেছনের হালকা ব্যাকগ্রাউন্ড কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** টিউটোরিয়াল ব্যানার ও ইনফো কার্ড।
  /// **কী কাজে লাগে:** [infoColor] লেখা ও আইকনের নিচে নরম ব্যাকগ্রাউন্ড দিতে।
  final Color infoBackgroundColor;

  /// ডেটা লোডিং অবস্থায় স্কেলেটন/প্লেসহোল্ডার কার্ডের মূল শিমার বেস কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** লোডিং শিমার কার্ড ও প্লেসহোল্ডার লাইন।
  /// **কী কাজে লাগে:** ডার্ক ও লাইট দুই মোডেই স্মুথ লোডিং অ্যানিমেশন তৈরি করতে।
  final Color shimmerBaseColor;

  /// শিমার স্কেলেটনের ভেতর দিয়ে বয়ে যাওয়া উজ্জ্বল হাইলাইট কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** স্কেলেটন লোডার শিমার গ্রেডিয়েন্ট।
  /// **কী কাজে লাগে:** কন্টেন্ট লোড হচ্ছে তা ভিজ্যুয়ালি সুন্দরভাবে দেখাতে।
  final Color shimmerHighlightColor;

  /// ডায়ালগ, ড্রয়ার ও বটম শিটের পেছনে স্ক্রিন ঢেকে দেওয়া আধা-স্বচ্ছ পর্দার কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** মডাল ব্যারিয়ার, লোডিং ওভারলে ও ড্রয়ার স্ক্রিম।
  /// **কী কাজে লাগে:** খোলা থাকা পপআপ ডায়ালগে ইউজারের মনোযোগ ধরে রাখতে।
  final Color overlayColor;

  /// কার্ড, মেনু ও ফ্লোটিং বক্সের নিচে ফেলা নরম শ্যাডো (ছায়া) কালার।
  ///
  /// **কোথায় ব্যবহার হয়:** `BoxShadow(color: context.colors.shadowColor)`।
  /// **কী কাজে লাগে:** লাইট মোডে হালকা ও ডার্ক মোডে গভীর এলিভেশন তৈরি করতে।
  final Color shadowColor;

  /// [Brightness.light] মোডের জন্য সরাসরি কাস্টম [OmniColors] তৈরি করে।
  ///
  /// যেকোনো রঙ না দিলে সুন্দর ডিফল্ট লাইট প্যালেট স্বয়ংক্রিয়ভাবে তৈরি হয়।
  factory OmniColors.light({
    Color primaryColor = const Color(0xFF2563EB),
    Color? secondaryColor,
    Color? surfaceColor,
    Color? secondaryBackgroundColor,
    Color? cardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? statusBarColor,
    Color? systemNavigationBarColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? inputFillColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? errorBackgroundColor,
    Color? warningColor,
    Color? warningBackgroundColor,
    Color? successColor,
    Color? successBackgroundColor,
    Color? infoColor,
    Color? infoBackgroundColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
  }) => OmniColors.fromSeed(
    primaryColor: primaryColor,
    brightness: Brightness.light,
    secondaryColor: secondaryColor,
    surfaceColor: surfaceColor,
    secondaryBackgroundColor: secondaryBackgroundColor,
    cardColor: cardColor,
    appBarColor: appBarColor,
    appBarTextColor: appBarTextColor,
    navBarColor: navBarColor,
    navSelectedColor: navSelectedColor,
    navUnselectedColor: navUnselectedColor,
    statusBarColor: statusBarColor,
    systemNavigationBarColor: systemNavigationBarColor,
    buttonColor: buttonColor,
    buttonTextColor: buttonTextColor,
    secondaryButtonColor: secondaryButtonColor,
    secondaryButtonTextColor: secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor,
    dangerButtonTextColor: dangerButtonTextColor,
    linkColor: linkColor,
    inputFillColor: inputFillColor,
    borderColor: borderColor,
    focusedBorderColor: focusedBorderColor,
    dividerColor: dividerColor,
    textColor: textColor,
    secondaryTextColor: secondaryTextColor,
    hintTextColor: hintTextColor,
    iconColor: iconColor,
    chipColor: chipColor,
    chipTextColor: chipTextColor,
    badgeColor: badgeColor,
    badgeTextColor: badgeTextColor,
    selectedItemColor: selectedItemColor,
    hoverColor: hoverColor,
    rippleColor: rippleColor,
    disabledColor: disabledColor,
    disabledTextColor: disabledTextColor,
    disabledBorderColor: disabledBorderColor,
    switchActiveColor: switchActiveColor,
    switchInactiveColor: switchInactiveColor,
    snackbarColor: snackbarColor,
    snackbarTextColor: snackbarTextColor,
    tooltipColor: tooltipColor,
    tooltipTextColor: tooltipTextColor,
    errorColor: errorColor,
    errorBackgroundColor: errorBackgroundColor,
    warningColor: warningColor,
    warningBackgroundColor: warningBackgroundColor,
    successColor: successColor,
    successBackgroundColor: successBackgroundColor,
    infoColor: infoColor,
    infoBackgroundColor: infoBackgroundColor,
    shimmerBaseColor: shimmerBaseColor,
    shimmerHighlightColor: shimmerHighlightColor,
    overlayColor: overlayColor,
    shadowColor: shadowColor,
  );

  /// [Brightness.dark] মোডের জন্য সরাসরি কাস্টম [OmniColors] তৈরি করে।
  ///
  /// যেকোনো রঙ না দিলে চোখের আরামদায়ক ডার্ক প্যালেট স্বয়ংক্রিয়ভাবে তৈরি হয়।
  factory OmniColors.dark({
    Color primaryColor = const Color(0xFF60A5FA),
    Color? secondaryColor,
    Color? surfaceColor,
    Color? secondaryBackgroundColor,
    Color? cardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? statusBarColor,
    Color? systemNavigationBarColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? inputFillColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? errorBackgroundColor,
    Color? warningColor,
    Color? warningBackgroundColor,
    Color? successColor,
    Color? successBackgroundColor,
    Color? infoColor,
    Color? infoBackgroundColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
  }) => OmniColors.fromSeed(
    primaryColor: primaryColor,
    brightness: Brightness.dark,
    secondaryColor: secondaryColor,
    surfaceColor: surfaceColor,
    secondaryBackgroundColor: secondaryBackgroundColor,
    cardColor: cardColor,
    appBarColor: appBarColor,
    appBarTextColor: appBarTextColor,
    navBarColor: navBarColor,
    navSelectedColor: navSelectedColor,
    navUnselectedColor: navUnselectedColor,
    statusBarColor: statusBarColor,
    systemNavigationBarColor: systemNavigationBarColor,
    buttonColor: buttonColor,
    buttonTextColor: buttonTextColor,
    secondaryButtonColor: secondaryButtonColor,
    secondaryButtonTextColor: secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor,
    dangerButtonTextColor: dangerButtonTextColor,
    linkColor: linkColor,
    inputFillColor: inputFillColor,
    borderColor: borderColor,
    focusedBorderColor: focusedBorderColor,
    dividerColor: dividerColor,
    textColor: textColor,
    secondaryTextColor: secondaryTextColor,
    hintTextColor: hintTextColor,
    iconColor: iconColor,
    chipColor: chipColor,
    chipTextColor: chipTextColor,
    badgeColor: badgeColor,
    badgeTextColor: badgeTextColor,
    selectedItemColor: selectedItemColor,
    hoverColor: hoverColor,
    rippleColor: rippleColor,
    disabledColor: disabledColor,
    disabledTextColor: disabledTextColor,
    disabledBorderColor: disabledBorderColor,
    switchActiveColor: switchActiveColor,
    switchInactiveColor: switchInactiveColor,
    snackbarColor: snackbarColor,
    snackbarTextColor: snackbarTextColor,
    tooltipColor: tooltipColor,
    tooltipTextColor: tooltipTextColor,
    errorColor: errorColor,
    errorBackgroundColor: errorBackgroundColor,
    warningColor: warningColor,
    warningBackgroundColor: warningBackgroundColor,
    successColor: successColor,
    successBackgroundColor: successBackgroundColor,
    infoColor: infoColor,
    infoBackgroundColor: infoBackgroundColor,
    shimmerBaseColor: shimmerBaseColor,
    shimmerHighlightColor: shimmerHighlightColor,
    overlayColor: overlayColor,
    shadowColor: shadowColor,
  );

  /// একটি [primaryColor] ও [brightness] থেকে স্বয়ংক্রিয়ভাবে সুষম ৫৫টি কালার
  /// তৈরি করে; চাইলে যেকোনো রঙ আলাদা করে ওভাররাইডও করা যায়।
  factory OmniColors.fromSeed({
    required Color primaryColor,
    required Brightness brightness,
    DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
    double contrastLevel = 0.0,
    Color? secondaryColor,
    Color? surfaceColor,
    Color? secondaryBackgroundColor,
    Color? cardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? statusBarColor,
    Color? systemNavigationBarColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? inputFillColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? errorBackgroundColor,
    Color? warningColor,
    Color? warningBackgroundColor,
    Color? successColor,
    Color? successBackgroundColor,
    Color? infoColor,
    Color? infoBackgroundColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      secondary: secondaryColor,
      dynamicSchemeVariant: variant,
      contrastLevel: contrastLevel,
    );
    final isDark = brightness == Brightness.dark;

    final resolvedSurface =
        surfaceColor ??
        (isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC));
    final resolvedSecondaryBg =
        secondaryBackgroundColor ??
        (isDark ? const Color(0xFF162033) : const Color(0xFFF1F5F9));
    final resolvedCard =
        cardColor ?? (isDark ? const Color(0xFF131C31) : Colors.white);
    final resolvedPrimary = primaryColor;
    final resolvedButton = buttonColor ?? resolvedPrimary;
    final resolvedButtonText = buttonTextColor ?? _readableOn(resolvedButton);
    final resolvedError =
        errorColor ??
        (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));
    final resolvedDanger =
        dangerButtonColor ?? (isDark ? const Color(0xFFEF4444) : resolvedError);
    final resolvedDangerText =
        dangerButtonTextColor ?? _readableOn(resolvedDanger);
    final resolvedWarning =
        warningColor ??
        (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final resolvedSuccess =
        successColor ??
        (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));
    final resolvedInfo =
        infoColor ??
        (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
    final resolvedText =
        textColor ??
        (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A));
    final resolvedSecondaryText =
        secondaryTextColor ??
        (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final resolvedSecondaryBtn =
        secondaryButtonColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final resolvedChip =
        chipColor ?? resolvedPrimary.withValues(alpha: isDark ? 0.18 : 0.10);
    final resolvedBadge = badgeColor ?? resolvedError;

    return OmniColors(
      primaryColor: resolvedPrimary,
      secondaryColor: secondaryColor ?? scheme.secondary,
      surfaceColor: resolvedSurface,
      secondaryBackgroundColor: resolvedSecondaryBg,
      cardColor: resolvedCard,
      appBarColor: appBarColor ?? resolvedCard,
      appBarTextColor: appBarTextColor ?? resolvedText,
      navBarColor: navBarColor ?? resolvedCard,
      navSelectedColor: navSelectedColor ?? resolvedPrimary,
      navUnselectedColor: navUnselectedColor ?? resolvedSecondaryText,
      statusBarColor: statusBarColor ?? Colors.transparent,
      systemNavigationBarColor: systemNavigationBarColor ?? Colors.transparent,
      buttonColor: resolvedButton,
      buttonTextColor: resolvedButtonText,
      secondaryButtonColor: resolvedSecondaryBtn,
      secondaryButtonTextColor: secondaryButtonTextColor ?? resolvedText,
      dangerButtonColor: resolvedDanger,
      dangerButtonTextColor: resolvedDangerText,
      linkColor: linkColor ?? resolvedPrimary,
      inputFillColor:
          inputFillColor ??
          (isDark ? const Color(0xFF1B263B) : const Color(0xFFF1F5F9)),
      borderColor:
          borderColor ??
          (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      focusedBorderColor: focusedBorderColor ?? resolvedPrimary,
      dividerColor:
          dividerColor ??
          (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      textColor: resolvedText,
      secondaryTextColor: resolvedSecondaryText,
      hintTextColor:
          hintTextColor ??
          (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      iconColor:
          iconColor ??
          (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
      chipColor: resolvedChip,
      chipTextColor: chipTextColor ?? resolvedPrimary,
      badgeColor: resolvedBadge,
      badgeTextColor: badgeTextColor ?? Colors.white,
      selectedItemColor:
          selectedItemColor ??
          resolvedPrimary.withValues(alpha: isDark ? 0.16 : 0.08),
      hoverColor:
          hoverColor ?? resolvedText.withValues(alpha: isDark ? 0.06 : 0.04),
      rippleColor:
          rippleColor ??
          resolvedPrimary.withValues(alpha: isDark ? 0.22 : 0.12),
      disabledColor:
          disabledColor ??
          (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      disabledTextColor:
          disabledTextColor ??
          (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      disabledBorderColor:
          disabledBorderColor ??
          (isDark ? const Color(0xFF283548) : const Color(0xFFCBD5E1)),
      switchActiveColor: switchActiveColor ?? resolvedPrimary,
      switchInactiveColor:
          switchInactiveColor ??
          (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      snackbarColor:
          snackbarColor ??
          (isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
      snackbarTextColor: snackbarTextColor ?? const Color(0xFFF8FAFC),
      tooltipColor:
          tooltipColor ??
          (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
      tooltipTextColor:
          tooltipTextColor ?? (isDark ? const Color(0xFF0F172A) : Colors.white),
      errorColor: resolvedError,
      errorBackgroundColor:
          errorBackgroundColor ??
          resolvedError.withValues(alpha: isDark ? 0.16 : 0.10),
      warningColor: resolvedWarning,
      warningBackgroundColor:
          warningBackgroundColor ??
          resolvedWarning.withValues(alpha: isDark ? 0.16 : 0.12),
      successColor: resolvedSuccess,
      successBackgroundColor:
          successBackgroundColor ??
          resolvedSuccess.withValues(alpha: isDark ? 0.16 : 0.10),
      infoColor: resolvedInfo,
      infoBackgroundColor:
          infoBackgroundColor ??
          resolvedInfo.withValues(alpha: isDark ? 0.16 : 0.10),
      shimmerBaseColor:
          shimmerBaseColor ??
          (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      shimmerHighlightColor:
          shimmerHighlightColor ??
          (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC)),
      overlayColor:
          overlayColor ?? Colors.black.withValues(alpha: isDark ? 0.65 : 0.45),
      shadowColor:
          shadowColor ?? Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
    );
  }

  /// ডিফল্ট লাইট [OmniColors] ফলব্যাক।
  static final OmniColors lightDefault = OmniColors.fromSeed(
    primaryColor: const Color(0xFF2563EB),
    brightness: Brightness.light,
  );

  /// ডিফল্ট ডার্ক [OmniColors] ফলব্যাক।
  static final OmniColors darkDefault = OmniColors.fromSeed(
    primaryColor: const Color(0xFF60A5FA),
    brightness: Brightness.dark,
  );

  /// নির্দিষ্ট কিছু কালার পরিবর্তন করে নতুন কপি তৈরি করে।
  @override
  OmniColors copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? surfaceColor,
    Color? secondaryBackgroundColor,
    Color? cardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? statusBarColor,
    Color? systemNavigationBarColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? inputFillColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? errorBackgroundColor,
    Color? warningColor,
    Color? warningBackgroundColor,
    Color? successColor,
    Color? successBackgroundColor,
    Color? infoColor,
    Color? infoBackgroundColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
  }) => OmniColors(
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    secondaryBackgroundColor:
        secondaryBackgroundColor ?? this.secondaryBackgroundColor,
    cardColor: cardColor ?? this.cardColor,
    appBarColor: appBarColor ?? this.appBarColor,
    appBarTextColor: appBarTextColor ?? this.appBarTextColor,
    navBarColor: navBarColor ?? this.navBarColor,
    navSelectedColor: navSelectedColor ?? this.navSelectedColor,
    navUnselectedColor: navUnselectedColor ?? this.navUnselectedColor,
    statusBarColor: statusBarColor ?? this.statusBarColor,
    systemNavigationBarColor:
        systemNavigationBarColor ?? this.systemNavigationBarColor,
    buttonColor: buttonColor ?? this.buttonColor,
    buttonTextColor: buttonTextColor ?? this.buttonTextColor,
    secondaryButtonColor: secondaryButtonColor ?? this.secondaryButtonColor,
    secondaryButtonTextColor:
        secondaryButtonTextColor ?? this.secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor ?? this.dangerButtonColor,
    dangerButtonTextColor: dangerButtonTextColor ?? this.dangerButtonTextColor,
    linkColor: linkColor ?? this.linkColor,
    inputFillColor: inputFillColor ?? this.inputFillColor,
    borderColor: borderColor ?? this.borderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    dividerColor: dividerColor ?? this.dividerColor,
    textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
    hintTextColor: hintTextColor ?? this.hintTextColor,
    iconColor: iconColor ?? this.iconColor,
    chipColor: chipColor ?? this.chipColor,
    chipTextColor: chipTextColor ?? this.chipTextColor,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextColor: badgeTextColor ?? this.badgeTextColor,
    selectedItemColor: selectedItemColor ?? this.selectedItemColor,
    hoverColor: hoverColor ?? this.hoverColor,
    rippleColor: rippleColor ?? this.rippleColor,
    disabledColor: disabledColor ?? this.disabledColor,
    disabledTextColor: disabledTextColor ?? this.disabledTextColor,
    disabledBorderColor: disabledBorderColor ?? this.disabledBorderColor,
    switchActiveColor: switchActiveColor ?? this.switchActiveColor,
    switchInactiveColor: switchInactiveColor ?? this.switchInactiveColor,
    snackbarColor: snackbarColor ?? this.snackbarColor,
    snackbarTextColor: snackbarTextColor ?? this.snackbarTextColor,
    tooltipColor: tooltipColor ?? this.tooltipColor,
    tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
    errorColor: errorColor ?? this.errorColor,
    errorBackgroundColor: errorBackgroundColor ?? this.errorBackgroundColor,
    warningColor: warningColor ?? this.warningColor,
    warningBackgroundColor:
        warningBackgroundColor ?? this.warningBackgroundColor,
    successColor: successColor ?? this.successColor,
    successBackgroundColor:
        successBackgroundColor ?? this.successBackgroundColor,
    infoColor: infoColor ?? this.infoColor,
    infoBackgroundColor: infoBackgroundColor ?? this.infoBackgroundColor,
    shimmerBaseColor: shimmerBaseColor ?? this.shimmerBaseColor,
    shimmerHighlightColor: shimmerHighlightColor ?? this.shimmerHighlightColor,
    overlayColor: overlayColor ?? this.overlayColor,
    shadowColor: shadowColor ?? this.shadowColor,
  );

  @override
  OmniColors lerp(covariant ThemeExtension<OmniColors>? other, double t) {
    if (other is! OmniColors) return this;
    return OmniColors(
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t)!,
      surfaceColor: Color.lerp(surfaceColor, other.surfaceColor, t)!,
      secondaryBackgroundColor: Color.lerp(
        secondaryBackgroundColor,
        other.secondaryBackgroundColor,
        t,
      )!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      appBarColor: Color.lerp(appBarColor, other.appBarColor, t)!,
      appBarTextColor: Color.lerp(appBarTextColor, other.appBarTextColor, t)!,
      navBarColor: Color.lerp(navBarColor, other.navBarColor, t)!,
      navSelectedColor: Color.lerp(
        navSelectedColor,
        other.navSelectedColor,
        t,
      )!,
      navUnselectedColor: Color.lerp(
        navUnselectedColor,
        other.navUnselectedColor,
        t,
      )!,
      statusBarColor: Color.lerp(statusBarColor, other.statusBarColor, t)!,
      systemNavigationBarColor: Color.lerp(
        systemNavigationBarColor,
        other.systemNavigationBarColor,
        t,
      )!,
      buttonColor: Color.lerp(buttonColor, other.buttonColor, t)!,
      buttonTextColor: Color.lerp(buttonTextColor, other.buttonTextColor, t)!,
      secondaryButtonColor: Color.lerp(
        secondaryButtonColor,
        other.secondaryButtonColor,
        t,
      )!,
      secondaryButtonTextColor: Color.lerp(
        secondaryButtonTextColor,
        other.secondaryButtonTextColor,
        t,
      )!,
      dangerButtonColor: Color.lerp(
        dangerButtonColor,
        other.dangerButtonColor,
        t,
      )!,
      dangerButtonTextColor: Color.lerp(
        dangerButtonTextColor,
        other.dangerButtonTextColor,
        t,
      )!,
      linkColor: Color.lerp(linkColor, other.linkColor, t)!,
      inputFillColor: Color.lerp(inputFillColor, other.inputFillColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      focusedBorderColor: Color.lerp(
        focusedBorderColor,
        other.focusedBorderColor,
        t,
      )!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      secondaryTextColor: Color.lerp(
        secondaryTextColor,
        other.secondaryTextColor,
        t,
      )!,
      hintTextColor: Color.lerp(hintTextColor, other.hintTextColor, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      chipColor: Color.lerp(chipColor, other.chipColor, t)!,
      chipTextColor: Color.lerp(chipTextColor, other.chipTextColor, t)!,
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t)!,
      badgeTextColor: Color.lerp(badgeTextColor, other.badgeTextColor, t)!,
      selectedItemColor: Color.lerp(
        selectedItemColor,
        other.selectedItemColor,
        t,
      )!,
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t)!,
      rippleColor: Color.lerp(rippleColor, other.rippleColor, t)!,
      disabledColor: Color.lerp(disabledColor, other.disabledColor, t)!,
      disabledTextColor: Color.lerp(
        disabledTextColor,
        other.disabledTextColor,
        t,
      )!,
      disabledBorderColor: Color.lerp(
        disabledBorderColor,
        other.disabledBorderColor,
        t,
      )!,
      switchActiveColor: Color.lerp(
        switchActiveColor,
        other.switchActiveColor,
        t,
      )!,
      switchInactiveColor: Color.lerp(
        switchInactiveColor,
        other.switchInactiveColor,
        t,
      )!,
      snackbarColor: Color.lerp(snackbarColor, other.snackbarColor, t)!,
      snackbarTextColor: Color.lerp(
        snackbarTextColor,
        other.snackbarTextColor,
        t,
      )!,
      tooltipColor: Color.lerp(tooltipColor, other.tooltipColor, t)!,
      tooltipTextColor: Color.lerp(
        tooltipTextColor,
        other.tooltipTextColor,
        t,
      )!,
      errorColor: Color.lerp(errorColor, other.errorColor, t)!,
      errorBackgroundColor: Color.lerp(
        errorBackgroundColor,
        other.errorBackgroundColor,
        t,
      )!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      warningBackgroundColor: Color.lerp(
        warningBackgroundColor,
        other.warningBackgroundColor,
        t,
      )!,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      successBackgroundColor: Color.lerp(
        successBackgroundColor,
        other.successBackgroundColor,
        t,
      )!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      infoBackgroundColor: Color.lerp(
        infoBackgroundColor,
        other.infoBackgroundColor,
        t,
      )!,
      shimmerBaseColor: Color.lerp(
        shimmerBaseColor,
        other.shimmerBaseColor,
        t,
      )!,
      shimmerHighlightColor: Color.lerp(
        shimmerHighlightColor,
        other.shimmerHighlightColor,
        t,
      )!,
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniColors &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          surfaceColor == other.surfaceColor &&
          secondaryBackgroundColor == other.secondaryBackgroundColor &&
          cardColor == other.cardColor &&
          appBarColor == other.appBarColor &&
          appBarTextColor == other.appBarTextColor &&
          navBarColor == other.navBarColor &&
          navSelectedColor == other.navSelectedColor &&
          navUnselectedColor == other.navUnselectedColor &&
          statusBarColor == other.statusBarColor &&
          systemNavigationBarColor == other.systemNavigationBarColor &&
          buttonColor == other.buttonColor &&
          buttonTextColor == other.buttonTextColor &&
          secondaryButtonColor == other.secondaryButtonColor &&
          secondaryButtonTextColor == other.secondaryButtonTextColor &&
          dangerButtonColor == other.dangerButtonColor &&
          dangerButtonTextColor == other.dangerButtonTextColor &&
          linkColor == other.linkColor &&
          inputFillColor == other.inputFillColor &&
          borderColor == other.borderColor &&
          focusedBorderColor == other.focusedBorderColor &&
          dividerColor == other.dividerColor &&
          textColor == other.textColor &&
          secondaryTextColor == other.secondaryTextColor &&
          hintTextColor == other.hintTextColor &&
          iconColor == other.iconColor &&
          chipColor == other.chipColor &&
          chipTextColor == other.chipTextColor &&
          badgeColor == other.badgeColor &&
          badgeTextColor == other.badgeTextColor &&
          selectedItemColor == other.selectedItemColor &&
          hoverColor == other.hoverColor &&
          rippleColor == other.rippleColor &&
          disabledColor == other.disabledColor &&
          disabledTextColor == other.disabledTextColor &&
          disabledBorderColor == other.disabledBorderColor &&
          switchActiveColor == other.switchActiveColor &&
          switchInactiveColor == other.switchInactiveColor &&
          snackbarColor == other.snackbarColor &&
          snackbarTextColor == other.snackbarTextColor &&
          tooltipColor == other.tooltipColor &&
          tooltipTextColor == other.tooltipTextColor &&
          errorColor == other.errorColor &&
          errorBackgroundColor == other.errorBackgroundColor &&
          warningColor == other.warningColor &&
          warningBackgroundColor == other.warningBackgroundColor &&
          successColor == other.successColor &&
          successBackgroundColor == other.successBackgroundColor &&
          infoColor == other.infoColor &&
          infoBackgroundColor == other.infoBackgroundColor &&
          shimmerBaseColor == other.shimmerBaseColor &&
          shimmerHighlightColor == other.shimmerHighlightColor &&
          overlayColor == other.overlayColor &&
          shadowColor == other.shadowColor;

  @override
  int get hashCode => Object.hashAll([
    primaryColor,
    secondaryColor,
    surfaceColor,
    secondaryBackgroundColor,
    cardColor,
    appBarColor,
    appBarTextColor,
    navBarColor,
    navSelectedColor,
    navUnselectedColor,
    statusBarColor,
    systemNavigationBarColor,
    buttonColor,
    buttonTextColor,
    secondaryButtonColor,
    secondaryButtonTextColor,
    dangerButtonColor,
    dangerButtonTextColor,
    linkColor,
    inputFillColor,
    borderColor,
    focusedBorderColor,
    dividerColor,
    textColor,
    secondaryTextColor,
    hintTextColor,
    iconColor,
    chipColor,
    chipTextColor,
    badgeColor,
    badgeTextColor,
    selectedItemColor,
    hoverColor,
    rippleColor,
    disabledColor,
    disabledTextColor,
    disabledBorderColor,
    switchActiveColor,
    switchInactiveColor,
    snackbarColor,
    snackbarTextColor,
    tooltipColor,
    tooltipTextColor,
    errorColor,
    errorBackgroundColor,
    warningColor,
    warningBackgroundColor,
    successColor,
    successBackgroundColor,
    infoColor,
    infoBackgroundColor,
    shimmerBaseColor,
    shimmerHighlightColor,
    overlayColor,
    shadowColor,
  ]);
}

/// যেকোনো `OmniTheme` প্যালেটে **লাইট মোড** ও **ডার্ক মোড**-এর জন্য আলাদা রঙ
/// যোগ করার `const`-বান্ধব ঐচ্ছিক কালার প্যালেট (`OmniTheme(light: ..., dark: ...)`).
///
/// ৫৫টি রঙের সবগুলো দেওয়ার প্রয়োজন নেই — শুধু যে রঙগুলো নির্দিষ্ট মোডে বদলাতে
/// চান সেগুলো দিলেই বাকি রঙগুলো `seedColor` ও মোড অনুযায়ী স্বয়ংক্রিয়ভাবে তৈরি হবে।
@immutable
class OmniColorPalette {
  /// ঐচ্ছিক লাইট বা ডার্ক মোড কালার ওভাররাইড তৈরি করে।
  const OmniColorPalette({
    this.primaryColor,
    this.secondaryColor,
    this.surfaceColor,
    this.secondaryBackgroundColor,
    this.cardColor,
    this.appBarColor,
    this.appBarTextColor,
    this.navBarColor,
    this.navSelectedColor,
    this.navUnselectedColor,
    this.statusBarColor,
    this.systemNavigationBarColor,
    this.buttonColor,
    this.buttonTextColor,
    this.secondaryButtonColor,
    this.secondaryButtonTextColor,
    this.dangerButtonColor,
    this.dangerButtonTextColor,
    this.linkColor,
    this.inputFillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.dividerColor,
    this.textColor,
    this.secondaryTextColor,
    this.hintTextColor,
    this.iconColor,
    this.chipColor,
    this.chipTextColor,
    this.badgeColor,
    this.badgeTextColor,
    this.selectedItemColor,
    this.hoverColor,
    this.rippleColor,
    this.disabledColor,
    this.disabledTextColor,
    this.disabledBorderColor,
    this.switchActiveColor,
    this.switchInactiveColor,
    this.snackbarColor,
    this.snackbarTextColor,
    this.tooltipColor,
    this.tooltipTextColor,
    this.errorColor,
    this.errorBackgroundColor,
    this.warningColor,
    this.warningBackgroundColor,
    this.successColor,
    this.successBackgroundColor,
    this.infoColor,
    this.infoBackgroundColor,
    this.shimmerBaseColor,
    this.shimmerHighlightColor,
    this.overlayColor,
    this.shadowColor,
  });

  /// ব্র্যান্ডের প্রধান প্রাইমারি কালার (এই মোডের জন্য)।
  final Color? primaryColor;

  /// সেকেন্ডারি বা সহায়ক অ্যাকসেন্ট কালার।
  final Color? secondaryColor;

  /// পুরো স্ক্রিন বা `Scaffold`-এর মূল ব্যাকগ্রাউন্ড কালার।
  final Color? surfaceColor;

  /// সেকশন, কোড ব্লক ও বিকল্প সারির দ্বিতীয় ব্যাকগ্রাউন্ড কালার।
  final Color? secondaryBackgroundColor;

  /// কার্ড, ডায়ালগ ও বটম শিটের ব্যাকগ্রাউন্ড কালার।
  final Color? cardColor;

  /// ওপরের `AppBar`-এর ব্যাকগ্রাউন্ড কালার।
  final Color? appBarColor;

  /// `AppBar`-এর টাইটেল ও আইকনের কালার।
  final Color? appBarTextColor;

  /// বটম নেভিগেশন বার ও সাইড রেলের ব্যাকগ্রাউন্ড কালার।
  final Color? navBarColor;

  /// সিলেক্ট করা ট্যাবের আইকন ও লেখার কালার।
  final Color? navSelectedColor;

  /// আন-সিলেক্টেড ট্যাবের আইকন ও লেখার কালার।
  final Color? navUnselectedColor;

  /// ওপরের সিস্টেম স্ট্যাটাস বারের কালার।
  final Color? statusBarColor;

  /// নিচের সিস্টেম নেভিগেশন ও গেস্টচার সোয়াইপ বারের কালার।
  final Color? systemNavigationBarColor;

  /// প্রধান অ্যাকশন বাটনের ব্যাকগ্রাউন্ড কালার।
  final Color? buttonColor;

  /// প্রধান বাটনের ভেতরের লেখা ও আইকনের কালার।
  final Color? buttonTextColor;

  /// সেকেন্ডারি বাটনের ("Cancel", "Back") ব্যাকগ্রাউন্ড কালার।
  final Color? secondaryButtonColor;

  /// সেকেন্ডারি বাটনের ভেতরের লেখার কালার।
  final Color? secondaryButtonTextColor;

  /// ডেঞ্জার/ডিলিট বাটনের ব্যাকগ্রাউন্ড কালার।
  final Color? dangerButtonColor;

  /// ডেঞ্জার বাটনের ভেতরের লেখার কালার।
  final Color? dangerButtonTextColor;

  /// ক্লিকেবল লিংক টেক্সটের কালার।
  final Color? linkColor;

  /// `TextField` / ইনপুট ফিল্ডের ভেতরের ব্যাকগ্রাউন্ড কালার।
  final Color? inputFillColor;

  /// সাধারণ কার্ড/ইনপুটের বর্ডার কালার।
  final Color? borderColor;

  /// ফোকাস হওয়া ইনপুট ফিল্ডের বর্ডার কালার।
  final Color? focusedBorderColor;

  /// সেকশন ও তালিকা আইটেমের ডিভাইডার লাইনের কালার।
  final Color? dividerColor;

  /// মূল হেডিং ও বডি টেক্সটের কালার।
  final Color? textColor;

  /// সাবটাইটেল ও তুলনামূলক হালকা টেক্সটের কালার।
  final Color? secondaryTextColor;

  /// ইনপুট ফিল্ডের হিন্ট/প্লেসহোল্ডার লেখার কালার।
  final Color? hintTextColor;

  /// সাধারণ UI আইকনের ডিফল্ট কালার।
  final Color? iconColor;

  /// ট্যাগ ও চিপের ব্যাকগ্রাউন্ড কালার।
  final Color? chipColor;

  /// ট্যাগ ও চিপের ভেতরের লেখার কালার।
  final Color? chipTextColor;

  /// নোটিফিকেশন ব্যাজের ব্যাকগ্রাউন্ড কালার।
  final Color? badgeColor;

  /// নোটিফিকেশন ব্যাজের লেখার কালার।
  final Color? badgeTextColor;

  /// সিলেক্ট করা তালিকা বা মেনু আইটেমের হাইলাইট কালার।
  final Color? selectedItemColor;

  /// মাউস হোভার বা প্রেস হাইলাইট কালার।
  final Color? hoverColor;

  /// বাটন ট্যাপ রিপল/স্প্ল্যাশ কালার।
  final Color? rippleColor;

  /// নিষ্ক্রিয় (`disabled`) বাটন ও ইনপুটের ব্যাকগ্রাউন্ড কালার।
  final Color? disabledColor;

  /// নিষ্ক্রিয় (`disabled`) বাটন ও ইনপুটের লেখার কালার।
  final Color? disabledTextColor;

  /// নিষ্ক্রিয় (`disabled`) উপাদানের বর্ডার কালার।
  final Color? disabledBorderColor;

  /// `Switch`, `Checkbox`, ও `Radio` চালু অবস্থার কালার।
  final Color? switchActiveColor;

  /// `Switch`, `Checkbox`, ও স্লাইডার বন্ধ অবস্থার কালার।
  final Color? switchInactiveColor;

  /// `SnackBar` / টোস্টের ব্যাকগ্রাউন্ড কালার।
  final Color? snackbarColor;

  /// `SnackBar` / টোস্টের ভেতরের লেখার কালার।
  final Color? snackbarTextColor;

  /// `Tooltip` পপআপ বক্সের ব্যাকগ্রাউন্ড কালার।
  final Color? tooltipColor;

  /// `Tooltip` পপআপের ভেতরের লেখার কালার।
  final Color? tooltipTextColor;

  /// এরর ও ভ্যালিডেশন ব্যর্থতার লাল কালার।
  final Color? errorColor;

  /// এরর অ্যালার্ট বক্সের ব্যাকগ্রাউন্ড কালার।
  final Color? errorBackgroundColor;

  /// সতর্কতা বা পেন্ডিং অবস্থার ওয়ার্নিং কালার।
  final Color? warningColor;

  /// ওয়ার্নিং অ্যালার্ট বক্সের ব্যাকগ্রাউন্ড কালার।
  final Color? warningBackgroundColor;

  /// সফল বা ভেরিফাইড অবস্থার সাকসেস কালার।
  final Color? successColor;

  /// সাকসেস ব্যানারের ব্যাকগ্রাউন্ড কালার।
  final Color? successBackgroundColor;

  /// তথ্য বা টিপস ব্যানারের ইনফো কালার।
  final Color? infoColor;

  /// ইনফো ব্যানারের ব্যাকগ্রাউন্ড কালার।
  final Color? infoBackgroundColor;

  /// লোডিং স্কেলেটনের মূল শিমার বেস কালার।
  final Color? shimmerBaseColor;

  /// লোডিং স্কেলেটনের উজ্জ্বল শিমার হাইলাইট কালার।
  final Color? shimmerHighlightColor;

  /// ডায়ালগ ও শিটের পেছনের ওভারলে স্ক্রিম কালার।
  final Color? overlayColor;

  /// কার্ড ও ফ্লোটিং বক্সের শ্যাডো কালার।
  final Color? shadowColor;

  /// প্রদত্ত [brightness] ও [seedColor] মিলিয়ে পূর্ণাঙ্গ ৫৫টি [OmniColors] তৈরি করে।
  OmniColors toColors({
    required Brightness brightness,
    Color seedColor = const Color(0xFF2563EB),
    Color? secondaryColor,
  }) => OmniColors.fromSeed(
    primaryColor: primaryColor ?? seedColor,
    brightness: brightness,
    secondaryColor: this.secondaryColor ?? secondaryColor,
    surfaceColor: surfaceColor,
    secondaryBackgroundColor: secondaryBackgroundColor,
    cardColor: cardColor,
    appBarColor: appBarColor,
    appBarTextColor: appBarTextColor,
    navBarColor: navBarColor,
    navSelectedColor: navSelectedColor,
    navUnselectedColor: navUnselectedColor,
    statusBarColor: statusBarColor,
    systemNavigationBarColor: systemNavigationBarColor,
    buttonColor: buttonColor,
    buttonTextColor: buttonTextColor,
    secondaryButtonColor: secondaryButtonColor,
    secondaryButtonTextColor: secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor,
    dangerButtonTextColor: dangerButtonTextColor,
    linkColor: linkColor,
    inputFillColor: inputFillColor,
    borderColor: borderColor,
    focusedBorderColor: focusedBorderColor,
    dividerColor: dividerColor,
    textColor: textColor,
    secondaryTextColor: secondaryTextColor,
    hintTextColor: hintTextColor,
    iconColor: iconColor,
    chipColor: chipColor,
    chipTextColor: chipTextColor,
    badgeColor: badgeColor,
    badgeTextColor: badgeTextColor,
    selectedItemColor: selectedItemColor,
    hoverColor: hoverColor,
    rippleColor: rippleColor,
    disabledColor: disabledColor,
    disabledTextColor: disabledTextColor,
    disabledBorderColor: disabledBorderColor,
    switchActiveColor: switchActiveColor,
    switchInactiveColor: switchInactiveColor,
    snackbarColor: snackbarColor,
    snackbarTextColor: snackbarTextColor,
    tooltipColor: tooltipColor,
    tooltipTextColor: tooltipTextColor,
    errorColor: errorColor,
    errorBackgroundColor: errorBackgroundColor,
    warningColor: warningColor,
    warningBackgroundColor: warningBackgroundColor,
    successColor: successColor,
    successBackgroundColor: successBackgroundColor,
    infoColor: infoColor,
    infoBackgroundColor: infoBackgroundColor,
    shimmerBaseColor: shimmerBaseColor,
    shimmerHighlightColor: shimmerHighlightColor,
    overlayColor: overlayColor,
    shadowColor: shadowColor,
  );

  /// নির্দিষ্ট রঙ বদলে নতুন [OmniColorPalette] কপি দেয়।
  OmniColorPalette copyWith({
    Color? primaryColor,
    Color? secondaryColor,
    Color? surfaceColor,
    Color? secondaryBackgroundColor,
    Color? cardColor,
    Color? appBarColor,
    Color? appBarTextColor,
    Color? navBarColor,
    Color? navSelectedColor,
    Color? navUnselectedColor,
    Color? statusBarColor,
    Color? systemNavigationBarColor,
    Color? buttonColor,
    Color? buttonTextColor,
    Color? secondaryButtonColor,
    Color? secondaryButtonTextColor,
    Color? dangerButtonColor,
    Color? dangerButtonTextColor,
    Color? linkColor,
    Color? inputFillColor,
    Color? borderColor,
    Color? focusedBorderColor,
    Color? dividerColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? hintTextColor,
    Color? iconColor,
    Color? chipColor,
    Color? chipTextColor,
    Color? badgeColor,
    Color? badgeTextColor,
    Color? selectedItemColor,
    Color? hoverColor,
    Color? rippleColor,
    Color? disabledColor,
    Color? disabledTextColor,
    Color? disabledBorderColor,
    Color? switchActiveColor,
    Color? switchInactiveColor,
    Color? snackbarColor,
    Color? snackbarTextColor,
    Color? tooltipColor,
    Color? tooltipTextColor,
    Color? errorColor,
    Color? errorBackgroundColor,
    Color? warningColor,
    Color? warningBackgroundColor,
    Color? successColor,
    Color? successBackgroundColor,
    Color? infoColor,
    Color? infoBackgroundColor,
    Color? shimmerBaseColor,
    Color? shimmerHighlightColor,
    Color? overlayColor,
    Color? shadowColor,
  }) => OmniColorPalette(
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    surfaceColor: surfaceColor ?? this.surfaceColor,
    secondaryBackgroundColor:
        secondaryBackgroundColor ?? this.secondaryBackgroundColor,
    cardColor: cardColor ?? this.cardColor,
    appBarColor: appBarColor ?? this.appBarColor,
    appBarTextColor: appBarTextColor ?? this.appBarTextColor,
    navBarColor: navBarColor ?? this.navBarColor,
    navSelectedColor: navSelectedColor ?? this.navSelectedColor,
    navUnselectedColor: navUnselectedColor ?? this.navUnselectedColor,
    statusBarColor: statusBarColor ?? this.statusBarColor,
    systemNavigationBarColor:
        systemNavigationBarColor ?? this.systemNavigationBarColor,
    buttonColor: buttonColor ?? this.buttonColor,
    buttonTextColor: buttonTextColor ?? this.buttonTextColor,
    secondaryButtonColor: secondaryButtonColor ?? this.secondaryButtonColor,
    secondaryButtonTextColor:
        secondaryButtonTextColor ?? this.secondaryButtonTextColor,
    dangerButtonColor: dangerButtonColor ?? this.dangerButtonColor,
    dangerButtonTextColor: dangerButtonTextColor ?? this.dangerButtonTextColor,
    linkColor: linkColor ?? this.linkColor,
    inputFillColor: inputFillColor ?? this.inputFillColor,
    borderColor: borderColor ?? this.borderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    dividerColor: dividerColor ?? this.dividerColor,
    textColor: textColor ?? this.textColor,
    secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
    hintTextColor: hintTextColor ?? this.hintTextColor,
    iconColor: iconColor ?? this.iconColor,
    chipColor: chipColor ?? this.chipColor,
    chipTextColor: chipTextColor ?? this.chipTextColor,
    badgeColor: badgeColor ?? this.badgeColor,
    badgeTextColor: badgeTextColor ?? this.badgeTextColor,
    selectedItemColor: selectedItemColor ?? this.selectedItemColor,
    hoverColor: hoverColor ?? this.hoverColor,
    rippleColor: rippleColor ?? this.rippleColor,
    disabledColor: disabledColor ?? this.disabledColor,
    disabledTextColor: disabledTextColor ?? this.disabledTextColor,
    disabledBorderColor: disabledBorderColor ?? this.disabledBorderColor,
    switchActiveColor: switchActiveColor ?? this.switchActiveColor,
    switchInactiveColor: switchInactiveColor ?? this.switchInactiveColor,
    snackbarColor: snackbarColor ?? this.snackbarColor,
    snackbarTextColor: snackbarTextColor ?? this.snackbarTextColor,
    tooltipColor: tooltipColor ?? this.tooltipColor,
    tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
    errorColor: errorColor ?? this.errorColor,
    errorBackgroundColor: errorBackgroundColor ?? this.errorBackgroundColor,
    warningColor: warningColor ?? this.warningColor,
    warningBackgroundColor:
        warningBackgroundColor ?? this.warningBackgroundColor,
    successColor: successColor ?? this.successColor,
    successBackgroundColor:
        successBackgroundColor ?? this.successBackgroundColor,
    infoColor: infoColor ?? this.infoColor,
    infoBackgroundColor: infoBackgroundColor ?? this.infoBackgroundColor,
    shimmerBaseColor: shimmerBaseColor ?? this.shimmerBaseColor,
    shimmerHighlightColor: shimmerHighlightColor ?? this.shimmerHighlightColor,
    overlayColor: overlayColor ?? this.overlayColor,
    shadowColor: shadowColor ?? this.shadowColor,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniColorPalette &&
          primaryColor == other.primaryColor &&
          secondaryColor == other.secondaryColor &&
          surfaceColor == other.surfaceColor &&
          secondaryBackgroundColor == other.secondaryBackgroundColor &&
          cardColor == other.cardColor &&
          appBarColor == other.appBarColor &&
          appBarTextColor == other.appBarTextColor &&
          navBarColor == other.navBarColor &&
          navSelectedColor == other.navSelectedColor &&
          navUnselectedColor == other.navUnselectedColor &&
          statusBarColor == other.statusBarColor &&
          systemNavigationBarColor == other.systemNavigationBarColor &&
          buttonColor == other.buttonColor &&
          buttonTextColor == other.buttonTextColor &&
          secondaryButtonColor == other.secondaryButtonColor &&
          secondaryButtonTextColor == other.secondaryButtonTextColor &&
          dangerButtonColor == other.dangerButtonColor &&
          dangerButtonTextColor == other.dangerButtonTextColor &&
          linkColor == other.linkColor &&
          inputFillColor == other.inputFillColor &&
          borderColor == other.borderColor &&
          focusedBorderColor == other.focusedBorderColor &&
          dividerColor == other.dividerColor &&
          textColor == other.textColor &&
          secondaryTextColor == other.secondaryTextColor &&
          hintTextColor == other.hintTextColor &&
          iconColor == other.iconColor &&
          chipColor == other.chipColor &&
          chipTextColor == other.chipTextColor &&
          badgeColor == other.badgeColor &&
          badgeTextColor == other.badgeTextColor &&
          selectedItemColor == other.selectedItemColor &&
          hoverColor == other.hoverColor &&
          rippleColor == other.rippleColor &&
          disabledColor == other.disabledColor &&
          disabledTextColor == other.disabledTextColor &&
          disabledBorderColor == other.disabledBorderColor &&
          switchActiveColor == other.switchActiveColor &&
          switchInactiveColor == other.switchInactiveColor &&
          snackbarColor == other.snackbarColor &&
          snackbarTextColor == other.snackbarTextColor &&
          tooltipColor == other.tooltipColor &&
          tooltipTextColor == other.tooltipTextColor &&
          errorColor == other.errorColor &&
          errorBackgroundColor == other.errorBackgroundColor &&
          warningColor == other.warningColor &&
          warningBackgroundColor == other.warningBackgroundColor &&
          successColor == other.successColor &&
          successBackgroundColor == other.successBackgroundColor &&
          infoColor == other.infoColor &&
          infoBackgroundColor == other.infoBackgroundColor &&
          shimmerBaseColor == other.shimmerBaseColor &&
          shimmerHighlightColor == other.shimmerHighlightColor &&
          overlayColor == other.overlayColor &&
          shadowColor == other.shadowColor;

  @override
  int get hashCode => Object.hashAll([
    primaryColor,
    secondaryColor,
    surfaceColor,
    secondaryBackgroundColor,
    cardColor,
    appBarColor,
    appBarTextColor,
    navBarColor,
    navSelectedColor,
    navUnselectedColor,
    statusBarColor,
    systemNavigationBarColor,
    buttonColor,
    buttonTextColor,
    secondaryButtonColor,
    secondaryButtonTextColor,
    dangerButtonColor,
    dangerButtonTextColor,
    linkColor,
    inputFillColor,
    borderColor,
    focusedBorderColor,
    dividerColor,
    textColor,
    secondaryTextColor,
    hintTextColor,
    iconColor,
    chipColor,
    chipTextColor,
    badgeColor,
    badgeTextColor,
    selectedItemColor,
    hoverColor,
    rippleColor,
    disabledColor,
    disabledTextColor,
    disabledBorderColor,
    switchActiveColor,
    switchInactiveColor,
    snackbarColor,
    snackbarTextColor,
    tooltipColor,
    tooltipTextColor,
    errorColor,
    errorBackgroundColor,
    warningColor,
    warningBackgroundColor,
    successColor,
    successBackgroundColor,
    infoColor,
    infoBackgroundColor,
    shimmerBaseColor,
    shimmerHighlightColor,
    overlayColor,
    shadowColor,
  ]);
}

/// যেকোনো `BuildContext` থেকে সহজে সেমান্টিক রঙ পড়ার শর্টকাট (`context.colors`)।
extension OmniColorsContext on BuildContext {
  /// সক্রিয় থিম ও ডার্ক/লাইট মোড অনুযায়ী সরাসরি [OmniColors] রিটার্ন করে।
  OmniColors get colors {
    final theme = Theme.of(this);
    final ext = theme.extension<OmniColors>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark
        ? OmniColors.darkDefault
        : OmniColors.lightDefault;
  }
}

/// White or near-black, whichever reads better on [background] (higher WCAG
/// contrast ratio).
Color _readableOn(Color background) {
  const dark = Color(0xFF0F172A);
  final bg = background.computeLuminance();
  final onWhite = (1.0 + 0.05) / (bg + 0.05);
  final onDark = (bg + 0.05) / (dark.computeLuminance() + 0.05);
  return onWhite >= onDark ? Colors.white : dark;
}
