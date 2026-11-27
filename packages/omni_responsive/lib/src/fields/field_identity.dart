import 'package:flutter/material.dart';

import 'field_theme.dart';

/// প্রতিটি প্রি-ডিফাইনড ইনপুট ফিল্ডের নিজস্ব আইডেন্টিটি (`OmniFieldIdentity`)।
///
/// সব ফিল্ড একই [OmniFieldTheme] ও [OmniTheme] শেয়ার করলেও, প্রতিটি আইডেন্টিটি
/// নিজস্ব আইকন, কিবোর্ড, অটো-ফিল, ভ্যালিডেশন ও পার-আইডেন্টিটি স্টাইল বজায় রাখে।
enum OmniFieldIdentity {
  /// ইমেইল ও জিমেইল ভেরিফিকেশন ইনপুট।
  email,

  /// পাসওয়ার্ড (শো/হাইড, স্ট্রেংথ ও কনফার্ম) ইনপুট।
  password,

  /// পূর্ণ নাম / ফার্স্ট-লাস্ট নেম / ইউজারনেম ইনপুট।
  name,

  /// মোবাইল নাম্বার, কান্ট্রি কোড ও ভেরিফিকেশন ইনপুট।
  phone,

  /// পূর্ণসংখ্যা, দশমিক বা কারেন্সি নাম্বার ইনপুট।
  number,

  /// মাল্টি-বক্স OTP / পিন ভেরিফিকেশন ইনপুট।
  otp,

  /// ডিবাউন্সড সার্চ ও ফিল্টার ইনপুট।
  search,

  /// মাল্টিলাইন বায়ো, ঠিকানা বা নোটস ইনপুট।
  multiline,

  /// ওয়েবসাইট / URL লিংক ইনপুট।
  url,

  /// সাধারণ কাস্টম টেক্সট ইনপুট।
  text;

  /// এই আইডেন্টিটির ডিফল্ট লেবেল।
  String get defaultLabel => switch (this) {
    OmniFieldIdentity.email => 'Email',
    OmniFieldIdentity.password => 'Password',
    OmniFieldIdentity.name => 'Full Name',
    OmniFieldIdentity.phone => 'Phone Number',
    OmniFieldIdentity.number => 'Number',
    OmniFieldIdentity.otp => 'Verification Code',
    OmniFieldIdentity.search => 'Search',
    OmniFieldIdentity.multiline => 'Notes',
    OmniFieldIdentity.url => 'Website URL',
    OmniFieldIdentity.text => 'Text',
  };

  /// এই আইডেন্টিটির ডিফল্ট প্লেসহোল্ডার।
  String get defaultHint => switch (this) {
    OmniFieldIdentity.email => 'name@gmail.com',
    OmniFieldIdentity.password => 'Enter password',
    OmniFieldIdentity.name => 'Enter your name',
    OmniFieldIdentity.phone => '01712-345678',
    OmniFieldIdentity.number => '0',
    OmniFieldIdentity.otp => '••••••',
    OmniFieldIdentity.search => 'Search...',
    OmniFieldIdentity.multiline => 'Write here...',
    OmniFieldIdentity.url => 'https://example.com',
    OmniFieldIdentity.text => 'Enter text',
  };

  /// এই আইডেন্টিটির ডিফল্ট প্রিফিক্স আইকন।
  IconData get defaultIcon => switch (this) {
    OmniFieldIdentity.email => Icons.mail_outline_rounded,
    OmniFieldIdentity.password => Icons.lock_outline_rounded,
    OmniFieldIdentity.name => Icons.person_outline_rounded,
    OmniFieldIdentity.phone => Icons.phone_android_rounded,
    OmniFieldIdentity.number => Icons.numbers_rounded,
    OmniFieldIdentity.otp => Icons.verified_user_outlined,
    OmniFieldIdentity.search => Icons.search_rounded,
    OmniFieldIdentity.multiline => Icons.notes_rounded,
    OmniFieldIdentity.url => Icons.link_rounded,
    OmniFieldIdentity.text => Icons.text_fields_rounded,
  };
}

/// প্রি-ডিফাইনড ফিল্ডগুলোর লেবেল কীভাবে দেখানো হবে।
enum OmniFieldLabelMode {
  /// ফিল্ডের ভেতরে/বর্ডারে Material ফ্লোটিং লেবেল দেখায়।
  floating,

  /// ইনপুট বক্সের ওপরে আলাদা লেবেল টাইটেল দেখায়।
  above,

  /// কোনো লেবেল টেক্সট না দেখিয়ে শুধু হিন্ট ব্যবহার করে।
  none,
}
