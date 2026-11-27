import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'omni_debug_report.dart';
import 'omni_preferences.dart';

/// বিশ্বের প্রধান দেশসমূহের টাইপ-সেইফ ISO-3166 কান্ট্রি কোড ইনাম (`OmniCountryCode`)।
///
/// প্রতিটি দেশে ISO কোড ([isoCode]), ফোনের ডায়াল কোড ([dialCode]), ফ্ল্যাগ ইমোজি
/// ([flag]), ইংরেজি/স্থানীয় নাম ([name], [nativeName]) এবং ডিফল্ট ভাষা
/// ([defaultLanguage]) যুক্ত আছে — যাতে যেকোনো জায়গায় টাইপ-সেইফভাবে দেশ বা ভাষা
/// কন্ট্রোল করা যায়।
enum OmniCountryCode {
  /// Bangladesh (`BD`, `+880`)
  bd('BD', 'Bangladesh', 'বাংলাদেশ', '🇧🇩', '+880', 'bn'),

  /// India (`IN`, `+91`)
  ind('IN', 'India', 'भारत', '🇮🇳', '+91', 'hi'),

  /// Pakistan (`PK`, `+92`)
  pk('PK', 'Pakistan', 'پاکستان', '🇵🇰', '+92', 'ur'),

  /// Nepal (`NP`, `+977`)
  np('NP', 'Nepal', 'नेपाल', '🇳🇵', '+977', 'ne'),

  /// Sri Lanka (`LK`, `+94`)
  lk('LK', 'Sri Lanka', 'ශ්‍රී ලංකාව', '🇱🇰', '+94', 'si'),

  /// Myanmar (`MM`, `+95`)
  mm('MM', 'Myanmar', 'မြန်မာ', '🇲🇲', '+95', 'my'),

  /// Afghanistan (`AF`, `+93`)
  af('AF', 'Afghanistan', 'افغانستان', '🇦🇫', '+93', 'ps'),

  /// United States (`US`, `+1`)
  us('US', 'United States', 'United States', '🇺🇸', '+1', 'en'),

  /// United Kingdom (`GB`, `+44`)
  gb('GB', 'United Kingdom', 'United Kingdom', '🇬🇧', '+44', 'en'),

  /// Canada (`CA`, `+1`)
  ca('CA', 'Canada', 'Canada', '🇨🇦', '+1', 'en'),

  /// Australia (`AU`, `+61`)
  au('AU', 'Australia', 'Australia', '🇦🇺', '+61', 'en'),

  /// New Zealand (`NZ`, `+64`)
  nz('NZ', 'New Zealand', 'New Zealand', '🇳🇿', '+64', 'en'),

  /// Ireland (`IE`, `+353`)
  ie('IE', 'Ireland', 'Éire', '🇮🇪', '+353', 'en'),

  /// Saudi Arabia (`SA`, `+966`)
  sa('SA', 'Saudi Arabia', 'السعودية', '🇸🇦', '+966', 'ar'),

  /// United Arab Emirates (`AE`, `+971`)
  ae('AE', 'UAE', 'الإمارات', '🇦🇪', '+971', 'ar'),

  /// Qatar (`QA`, `+974`)
  qa('QA', 'Qatar', 'قطر', '🇶🇦', '+974', 'ar'),

  /// Kuwait (`KW`, `+965`)
  kw('KW', 'Kuwait', 'الكويت', '🇰🇼', '+965', 'ar'),

  /// Oman (`OM`, `+968`)
  om('OM', 'Oman', 'عُمان', '🇴🇲', '+968', 'ar'),

  /// Bahrain (`BH`, `+973`)
  bh('BH', 'Bahrain', 'البحرين', '🇧🇭', '+973', 'ar'),

  /// Egypt (`EG`, `+20`)
  eg('EG', 'Egypt', 'مصر', '🇪🇬', '+20', 'ar'),

  /// Iraq (`IQ`, `+964`)
  iq('IQ', 'Iraq', 'العراق', '🇮🇶', '+964', 'ar'),

  /// Jordan (`JO`, `+962`)
  jo('JO', 'Jordan', 'الأردن', '🇯🇴', '+962', 'ar'),

  /// Lebanon (`LB`, `+961`)
  lb('LB', 'Lebanon', 'لبنان', '🇱🇧', '+961', 'ar'),

  /// Morocco (`MA`, `+212`)
  ma('MA', 'Morocco', 'المغرب', '🇲🇦', '+212', 'ar'),

  /// Algeria (`DZ`, `+213`)
  dz('DZ', 'Algeria', 'الجزائر', '🇩🇿', '+213', 'ar'),

  /// Tunisia (`TN`, `+216`)
  tn('TN', 'Tunisia', 'تونس', '🇹🇳', '+216', 'ar'),

  /// Iran (`IR`, `+98`)
  ir('IR', 'Iran', 'ایران', '🇮🇷', '+98', 'fa'),

  /// Turkey (`TR`, `+90`)
  tr('TR', 'Turkey', 'Türkiye', '🇹🇷', '+90', 'tr'),

  /// Israel (`IL`, `+972`)
  il('IL', 'Israel', 'ישראל', '🇮🇱', '+972', 'he'),

  /// Malaysia (`MY`, `+60`)
  my('MY', 'Malaysia', 'Malaysia', '🇲🇾', '+60', 'ms'),

  /// Singapore (`SG`, `+65`)
  sg('SG', 'Singapore', 'Singapore', '🇸🇬', '+65', 'en'),

  /// Indonesia (`ID`, `+62`)
  id('ID', 'Indonesia', 'Indonesia', '🇮🇩', '+62', 'id'),

  /// Thailand (`TH`, `+66`)
  th('TH', 'Thailand', 'ประเทศไทย', '🇹🇭', '+66', 'th'),

  /// Vietnam (`VN`, `+84`)
  vn('VN', 'Vietnam', 'Việt Nam', '🇻🇳', '+84', 'vi'),

  /// Philippines (`PH`, `+63`)
  ph('PH', 'Philippines', 'Pilipinas', '🇵🇭', '+63', 'fil'),

  /// China (`CN`, `+86`)
  cn('CN', 'China', '中国', '🇨🇳', '+86', 'zh'),

  /// Taiwan (`TW`, `+886`)
  tw('TW', 'Taiwan', '台灣', '🇹🇼', '+886', 'zh'),

  /// Hong Kong (`HK`, `+852`)
  hk('HK', 'Hong Kong', '香港', '🇭🇰', '+852', 'zh'),

  /// Japan (`JP`, `+81`)
  jp('JP', 'Japan', '日本', '🇯🇵', '+81', 'ja'),

  /// South Korea (`KR`, `+82`)
  kr('KR', 'South Korea', '대한민국', '🇰🇷', '+82', 'ko'),

  /// Germany (`DE`, `+49`)
  de('DE', 'Germany', 'Deutschland', '🇩🇪', '+49', 'de'),

  /// France (`FR`, `+33`)
  fr('FR', 'France', 'France', '🇫🇷', '+33', 'fr'),

  /// Spain (`ES`, `+34`)
  es('ES', 'Spain', 'España', '🇪🇸', '+34', 'es'),

  /// Italy (`IT`, `+39`)
  it('IT', 'Italy', 'Italia', '🇮🇹', '+39', 'it'),

  /// Portugal (`PT`, `+351`)
  pt('PT', 'Portugal', 'Portugal', '🇵🇹', '+351', 'pt'),

  /// Netherlands (`NL`, `+31`)
  nl('NL', 'Netherlands', 'Nederland', '🇳🇱', '+31', 'nl'),

  /// Belgium (`BE`, `+32`)
  be('BE', 'Belgium', 'België', '🇧🇪', '+32', 'nl'),

  /// Switzerland (`CH`, `+41`)
  ch('CH', 'Switzerland', 'Schweiz', '🇨🇭', '+41', 'de'),

  /// Austria (`AT`, `+43`)
  at('AT', 'Austria', 'Österreich', '🇦🇹', '+43', 'de'),

  /// Sweden (`SE`, `+46`)
  se('SE', 'Sweden', 'Sverige', '🇸🇪', '+46', 'sv'),

  /// Norway (`NO`, `+47`)
  no('NO', 'Norway', 'Norge', '🇳🇴', '+47', 'nb'),

  /// Denmark (`DK`, `+45`)
  dk('DK', 'Denmark', 'Danmark', '🇩🇰', '+45', 'da'),

  /// Finland (`FI`, `+358`)
  fi('FI', 'Finland', 'Suomi', '🇫🇮', '+358', 'fi'),

  /// Iceland (`IS`, `+354`)
  isl('IS', 'Iceland', 'Ísland', '🇮🇸', '+354', 'is'),

  /// Poland (`PL`, `+48`)
  pl('PL', 'Poland', 'Polska', '🇵🇱', '+48', 'pl'),

  /// Czechia (`CZ`, `+420`)
  cz('CZ', 'Czechia', 'Česko', '🇨🇿', '+420', 'cs'),

  /// Romania (`RO`, `+40`)
  ro('RO', 'Romania', 'România', '🇷🇴', '+40', 'ro'),

  /// Hungary (`HU`, `+36`)
  hu('HU', 'Hungary', 'Magyarország', '🇭🇺', '+36', 'hu'),

  /// Greece (`GR`, `+30`)
  gr('GR', 'Greece', 'Ελλάδα', '🇬🇷', '+30', 'el'),

  /// Ukraine (`UA`, `+380`)
  ua('UA', 'Ukraine', 'Україна', '🇺🇦', '+380', 'uk'),

  /// Russia (`RU`, `+7`)
  ru('RU', 'Russia', 'Россия', '🇷🇺', '+7', 'ru'),

  /// Mexico (`MX`, `+52`)
  mx('MX', 'Mexico', 'México', '🇲🇽', '+52', 'es'),

  /// Brazil (`BR`, `+55`)
  br('BR', 'Brazil', 'Brasil', '🇧🇷', '+55', 'pt'),

  /// Argentina (`AR`, `+54`)
  arg('AR', 'Argentina', 'Argentina', '🇦🇷', '+54', 'es'),

  /// Chile (`CL`, `+56`)
  cl('CL', 'Chile', 'Chile', '🇨🇱', '+56', 'es'),

  /// Colombia (`CO`, `+57`)
  co('CO', 'Colombia', 'Colombia', '🇨🇴', '+57', 'es'),

  /// South Africa (`ZA`, `+27`)
  za('ZA', 'South Africa', 'South Africa', '🇿🇦', '+27', 'en'),

  /// Nigeria (`NG`, `+234`)
  ng('NG', 'Nigeria', 'Nigeria', '🇳🇬', '+234', 'en'),

  /// Kenya (`KE`, `+254`)
  ke('KE', 'Kenya', 'Kenya', '🇰🇪', '+254', 'sw'),

  /// Ethiopia (`ET`, `+251`)
  et('ET', 'Ethiopia', 'ኢትዮጵያ', '🇪🇹', '+251', 'am');

  const OmniCountryCode(
    this.isoCode,
    this.name,
    this.nativeName,
    this.flag,
    this.dialCode,
    this.defaultLanguageCode,
  );

  /// ২-অক্ষরের ISO-3166 কান্ট্রি কোড (`'BD'`, `'US'`, `'SA'`, `'IN'`, ...)।
  final String isoCode;

  /// দেশের ইংরেজি নাম।
  final String name;

  /// দেশের স্থানীয় নাম।
  final String nativeName;

  /// দেশের পতাকা ইমোজি।
  final String flag;

  /// আন্তর্জাতিক ফোন ডায়াল কোড (`'+880'`, `'+1'`, ...)।
  final String dialCode;

  /// দেশটির ডিফল্ট ISO ভাষা কোড (`'bn'`, `'en'`, `'ar'`, ...)।
  final String defaultLanguageCode;

  /// দেশটির জন্য টাইপ-সেইফ ডিফল্ট [OmniLanguage]।
  OmniLanguage get defaultLanguage => switch (this) {
    OmniCountryCode.bd => OmniLanguage.bn,
    OmniCountryCode.us => OmniLanguage.en,
    OmniCountryCode.gb => OmniLanguage.enGB,
    OmniCountryCode.ca => OmniLanguage.enCA,
    OmniCountryCode.au => OmniLanguage.enAU,
    OmniCountryCode.sa => OmniLanguage.ar,
    OmniCountryCode.ae => OmniLanguage.arAE,
    OmniCountryCode.eg => OmniLanguage.arEG,
    OmniCountryCode.ma => OmniLanguage.arMA,
    OmniCountryCode.br => OmniLanguage.ptBR,
    OmniCountryCode.cn => OmniLanguage.zh,
    OmniCountryCode.tw => OmniLanguage.zhTW,
    OmniCountryCode.hk => OmniLanguage.zhHK,
    OmniCountryCode.mx => OmniLanguage.esMX,
    OmniCountryCode.arg => OmniLanguage.esAR,
    _ => OmniLanguage.tryParse(defaultLanguageCode) ?? OmniLanguage.en,
  };

  /// দেশ ও ঐচ্ছিক ভাষা মিলিয়ে [Locale] তৈরি করে।
  Locale toLocale([OmniLanguage? language]) =>
      Locale((language ?? defaultLanguage).languageCode, isoCode);

  /// স্ট্রিং ISO কোড (যেমন `'BD'`, `'bd'`, `'US'`) থেকে [OmniCountryCode] বের করে।
  static OmniCountryCode? tryFromCode(String? iso) {
    if (iso == null) return null;
    final norm = iso.trim().toUpperCase();
    if (norm.isEmpty) return null;
    for (final c in values) {
      if (c.isoCode == norm) return c;
    }
    return null;
  }

  /// ডায়াল কোড (`'+880'`, `'+1'`) থেকে [OmniCountryCode] বের করে।
  static OmniCountryCode? tryFromDialCode(String? dialCode) {
    if (dialCode == null) return null;
    final norm = dialCode.trim();
    for (final c in values) {
      if (c.dialCode == norm) return c;
    }
    return null;
  }

  /// ফ্লাটার [Locale] থেকে মিল থাকা [OmniCountryCode] বের করে।
  static OmniCountryCode? tryFromLocale(Locale? locale) {
    if (locale == null) return null;
    final fromCountry = tryFromCode(locale.countryCode);
    if (fromCountry != null) return fromCountry;
    return OmniLanguage.tryParse(locale.languageCode)?.country;
  }
}

/// বিশ্বের প্রধান ভাষা ও আঞ্চলিক ভ্যারিয়েন্টসমূহের টাইপ-সেইফ ইনাম (`OmniLanguage`)।
///
/// প্রতিটি ভ্যালুতে ভাষা কোড ([languageCode]), দেশের ইনাম ([country]),
/// ISO কান্ট্রি কোড ([countryCode]), [Locale] ([locale]), স্থানীয় ও ইংরেজি নাম,
/// পতাকা ([flag]) এবং RTL নির্দেশক ([isRtl]) আগে থেকেই সংযুক্ত আছে।
enum OmniLanguage {
  /// English (Global / US)
  en('en', OmniCountryCode.us, 'English', 'English'),

  /// English (United States)
  enUS('en', OmniCountryCode.us, 'English (US)', 'English (US)'),

  /// English (United Kingdom)
  enGB('en', OmniCountryCode.gb, 'English (UK)', 'English (UK)'),

  /// English (Australia)
  enAU('en', OmniCountryCode.au, 'English (AU)', 'English (AU)'),

  /// English (Canada)
  enCA('en', OmniCountryCode.ca, 'English (CA)', 'English (CA)'),

  /// English (India)
  enIN('en', OmniCountryCode.ind, 'English (India)', 'English (India)'),

  /// Bengali / বাংলা (Bangladesh)
  bn('bn', OmniCountryCode.bd, 'Bengali', 'বাংলা'),

  /// Bengali (Bangladesh)
  bnBD('bn', OmniCountryCode.bd, 'Bengali (Bangladesh)', 'বাংলা (বাংলাদেশ)'),

  /// Bengali (India)
  bnIN('bn', OmniCountryCode.ind, 'Bengali (India)', 'বাংলা (ভারত)'),

  /// Arabic / العربية
  ar('ar', OmniCountryCode.sa, 'Arabic', 'العربية', isRtl: true),

  /// Arabic (Saudi Arabia)
  arSA(
    'ar',
    OmniCountryCode.sa,
    'Arabic (Saudi)',
    'العربية (السعودية)',
    isRtl: true,
  ),

  /// Arabic (UAE)
  arAE(
    'ar',
    OmniCountryCode.ae,
    'Arabic (UAE)',
    'العربية (الإمارات)',
    isRtl: true,
  ),

  /// Arabic (Egypt)
  arEG(
    'ar',
    OmniCountryCode.eg,
    'Arabic (Egypt)',
    'العربية (مصر)',
    isRtl: true,
  ),

  /// Arabic (Morocco)
  arMA(
    'ar',
    OmniCountryCode.ma,
    'Arabic (Morocco)',
    'العربية (المغرب)',
    isRtl: true,
  ),

  /// Hindi / हिन्दी
  hi('hi', OmniCountryCode.ind, 'Hindi', 'हिन्दी'),

  /// Urdu / اردو
  ur('ur', OmniCountryCode.pk, 'Urdu', 'اردو', isRtl: true),

  /// Punjabi / ਪੰਜਾਬੀ
  pa('pa', OmniCountryCode.ind, 'Punjabi', 'ਪੰਜਾਬੀ'),

  /// Tamil / தமிழ்
  ta('ta', OmniCountryCode.ind, 'Tamil', 'தமிழ்'),

  /// Telugu / తెలుగు
  te('te', OmniCountryCode.ind, 'Telugu', 'తెలుగు'),

  /// Marathi / मराठी
  mr('mr', OmniCountryCode.ind, 'Marathi', 'मराठी'),

  /// Gujarati / ગુજરાતી
  gu('gu', OmniCountryCode.ind, 'Gujarati', 'ગુજરાતી'),

  /// Kannada / ಕನ್ನಡ
  kn('kn', OmniCountryCode.ind, 'Kannada', 'ಕನ್ನಡ'),

  /// Malayalam / മലയാളം
  ml('ml', OmniCountryCode.ind, 'Malayalam', 'മലയാളം'),

  /// Nepali / नेपाली
  ne('ne', OmniCountryCode.np, 'Nepali', 'नेपाली'),

  /// Sinhala / සිංහල
  si('si', OmniCountryCode.lk, 'Sinhala', 'සිංහල'),

  /// Burmese / မြန်မာ
  my('my', OmniCountryCode.mm, 'Burmese', 'မြန်မာ'),

  /// Chinese / 中文
  zh('zh', OmniCountryCode.cn, 'Chinese', '中文'),

  /// Chinese Simplified / 简体中文
  zhCN('zh', OmniCountryCode.cn, 'Chinese (Simplified)', '简体中文'),

  /// Chinese Traditional / 繁體中文
  zhTW('zh', OmniCountryCode.tw, 'Chinese (Traditional)', '繁體中文'),

  /// Chinese Hong Kong / 粵語
  zhHK('zh', OmniCountryCode.hk, 'Chinese (Hong Kong)', '香港繁體'),

  /// Japanese / 日本語
  ja('ja', OmniCountryCode.jp, 'Japanese', '日本語'),

  /// Korean / 한국어
  ko('ko', OmniCountryCode.kr, 'Korean', '한국어'),

  /// Indonesian / Bahasa Indonesia
  id('id', OmniCountryCode.id, 'Indonesian', 'Bahasa Indonesia'),

  /// Malay / Bahasa Melayu
  ms('ms', OmniCountryCode.my, 'Malay', 'Bahasa Melayu'),

  /// Thai / ไทย
  th('th', OmniCountryCode.th, 'Thai', 'ไทย'),

  /// Vietnamese / Tiếng Việt
  vi('vi', OmniCountryCode.vn, 'Vietnamese', 'Tiếng Việt'),

  /// Filipino / Tagalog
  fil('fil', OmniCountryCode.ph, 'Filipino', 'Filipino'),

  /// Turkish / Türkçe
  tr('tr', OmniCountryCode.tr, 'Turkish', 'Türkçe'),

  /// Persian / فارسی
  fa('fa', OmniCountryCode.ir, 'Persian', 'فارسی', isRtl: true),

  /// Pashto / پښتو
  ps('ps', OmniCountryCode.af, 'Pashto', 'پښتو', isRtl: true),

  /// Hebrew / עברית
  he('he', OmniCountryCode.il, 'Hebrew', 'עברית', isRtl: true),

  /// Spanish / Español
  es('es', OmniCountryCode.es, 'Spanish', 'Español'),

  /// Spanish (Mexico)
  esMX('es', OmniCountryCode.mx, 'Spanish (Mexico)', 'Español (México)'),

  /// Spanish (Argentina)
  esAR('es', OmniCountryCode.arg, 'Spanish (Argentina)', 'Español (Argentina)'),

  /// French / Français
  fr('fr', OmniCountryCode.fr, 'French', 'Français'),

  /// French (Canada)
  frCA('fr', OmniCountryCode.ca, 'French (Canada)', 'Français (Canada)'),

  /// German / Deutsch
  de('de', OmniCountryCode.de, 'German', 'Deutsch'),

  /// Italian / Italiano
  it('it', OmniCountryCode.it, 'Italian', 'Italiano'),

  /// Portuguese / Português
  pt('pt', OmniCountryCode.pt, 'Portuguese', 'Português'),

  /// Portuguese (Brazil)
  ptBR('pt', OmniCountryCode.br, 'Portuguese (Brazil)', 'Português (Brasil)'),

  /// Russian / Русский
  ru('ru', OmniCountryCode.ru, 'Russian', 'Русский'),

  /// Ukrainian / Українська
  uk('uk', OmniCountryCode.ua, 'Ukrainian', 'Українська'),

  /// Dutch / Nederlands
  nl('nl', OmniCountryCode.nl, 'Dutch', 'Nederlands'),

  /// Polish / Polski
  pl('pl', OmniCountryCode.pl, 'Polish', 'Polski'),

  /// Swedish / Svenska
  sv('sv', OmniCountryCode.se, 'Swedish', 'Svenska'),

  /// Norwegian / Norsk
  nb('nb', OmniCountryCode.no, 'Norwegian', 'Norsk'),

  /// Danish / Dansk
  da('da', OmniCountryCode.dk, 'Danish', 'Dansk'),

  /// Finnish / Suomi
  fi('fi', OmniCountryCode.fi, 'Finnish', 'Suomi'),

  /// Icelandic / Íslenska
  isl('is', OmniCountryCode.isl, 'Icelandic', 'Íslenska'),

  /// Greek / Ελληνικά
  el('el', OmniCountryCode.gr, 'Greek', 'Ελληνικά'),

  /// Czech / Čeština
  cs('cs', OmniCountryCode.cz, 'Czech', 'Čeština'),

  /// Romanian / Română
  ro('ro', OmniCountryCode.ro, 'Romanian', 'Română'),

  /// Hungarian / Magyar
  hu('hu', OmniCountryCode.hu, 'Hungarian', 'Magyar'),

  /// Swahili / Kiswahili
  sw('sw', OmniCountryCode.ke, 'Swahili', 'Kiswahili'),

  /// Amharic / አማርኛ
  am('am', OmniCountryCode.et, 'Amharic', 'አማርኛ'),

  /// Afrikaans
  af('af', OmniCountryCode.za, 'Afrikaans', 'Afrikaans');

  const OmniLanguage(
    this.languageCode,
    this.country,
    this.englishName,
    this.nativeName, {
    this.isRtl = false,
  });

  /// জনপ্রিয় ডিফল্ট ভাষার তালিকা (ল্যাঙ্গুয়েজ পিকারের ডিফল্ট সাজেস্টেড আইটেম)।
  static const List<OmniLanguage> popular = [
    OmniLanguage.en,
    OmniLanguage.bn,
    OmniLanguage.ar,
    OmniLanguage.hi,
    OmniLanguage.ur,
    OmniLanguage.es,
    OmniLanguage.fr,
    OmniLanguage.de,
    OmniLanguage.pt,
    OmniLanguage.ja,
    OmniLanguage.ko,
    OmniLanguage.zh,
  ];

  /// ISO-639 ভাষা কোড (`'en'`, `'bn'`, `'ar'`, ...)।
  final String languageCode;

  /// এই ভাষার ডিফল্ট দেশ ([OmniCountryCode])।
  final OmniCountryCode country;

  /// ভাষার ইংরেজি নাম।
  final String englishName;

  /// ভাষার নিজস্ব/স্থানীয় নাম (`'বাংলা'`, `'English'`, `'العربية'`)।
  final String nativeName;

  /// ভাষাটি ডান-থেকে-বামে (RTL) লেখা হয় কি না (`ar`, `ur`, `fa`, `ps`, `he`)।
  final bool isRtl;

  /// ২-অক্ষরের কান্ট্রি কোড (`'BD'`, `'US'`, ...)।
  String get countryCode => country.isoCode;

  /// দেশের পতাকা ইমোজি।
  String get flag => country.flag;

  /// পূর্ণ `lang_COUNTRY` ট্যাগ (যেমন `'bn_BD'`, `'en_US'`)।
  String get tag => '${languageCode}_$countryCode';

  /// ২/৩-অক্ষরের বড় হাতের শর্ট কোড (যেমন `'BN'`, `'EN'`)।
  String get shortCode => languageCode.toUpperCase();

  /// সমতুল্য Flutter [Locale] অবজেক্ট।
  Locale get locale => Locale(languageCode, countryCode);

  /// আঞ্চলিক ভ্যারিয়েন্ট হলে এর মূল ভাষা (যেমন `enGB` → `en`, `bnBD` → `bn`)।
  OmniLanguage get baseLanguage => switch (languageCode) {
    'en' => OmniLanguage.en,
    'bn' => OmniLanguage.bn,
    'ar' => OmniLanguage.ar,
    'zh' => OmniLanguage.zh,
    'es' => OmniLanguage.es,
    'fr' => OmniLanguage.fr,
    'pt' => OmniLanguage.pt,
    _ => this,
  };

  /// Flutter [Locale] থেকে মিল থাকা [OmniLanguage] খুঁজে আনে।
  static OmniLanguage fromLocale(
    Locale? locale, {
    OmniLanguage fallback = OmniLanguage.en,
  }) {
    if (locale == null) return fallback;
    final lang = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      for (final item in values) {
        if (item.languageCode == lang && item.countryCode == country) {
          return item;
        }
      }
    }
    for (final item in values) {
      if (item.languageCode == lang) return item;
    }
    return fallback;
  }

  /// `'bn'`, `'bn_BD'`, `'bn-BD'`, `'zhTW'` ইত্যাদি স্ট্রিং থেকে [OmniLanguage] বের করে।
  static OmniLanguage? tryParse(String? rawTag) {
    if (rawTag == null) return null;
    final cleaned = rawTag.trim();
    if (cleaned.isEmpty) return null;
    final parts = cleaned.split(_localeTagSeparator);
    if (parts.length >= 2) {
      return fromLocale(Locale(parts[0].toLowerCase(), parts[1].toUpperCase()));
    }
    final lower = cleaned.toLowerCase();
    for (final item in values) {
      if (item.name.toLowerCase() == lower || item.languageCode == lower) {
        return item;
      }
    }
    return null;
  }
}

/// পুরো অ্যাপের সক্রিয় ভাষা, কান্ট্রি কোড, RTL ও লোকাল ডিজিট স্টেটের স্ন্যাপশট।
@immutable
class OmniLocaleState {
  /// [language], [country] এবং ঐচ্ছিক ফ্ল্যাগসহ লোকেল স্ন্যাপশট তৈরি করে।
  const OmniLocaleState({
    required this.language,
    required this.country,
    this.selectedLocale,
    this.systemLocale = const Locale('en', 'US'),
    this.fallbackLanguage = OmniLanguage.en,
    this.useLocaleDigits = false,
    this.revision = 0,
  });

  /// বর্তমানে সক্রিয় ভাষা।
  final OmniLanguage language;

  /// বর্তমানে সক্রিয় দেশ ([OmniCountryCode])।
  final OmniCountryCode country;

  /// ইউজারের হাতে বা কোড থেকে নির্বাচিত নির্দিষ্ট [Locale] (`null` হলে সিস্টেম ফলো)।
  final Locale? selectedLocale;

  /// ডিভাইসের বর্তমান সিস্টেম লোকেল।
  final Locale systemLocale;

  /// কোনো ভাষায় নির্দিষ্ট টেক্সট না থাকলে ডিফল্ট ফলব্যাক ভাষা।
  final OmniLanguage fallbackLanguage;

  /// সংখ্যাগুলো (`0-9`) স্থানীয় ভাষার অঙ্কে (`০-৯`, `٠-٩`) রূপান্তর করবে কি না।
  final bool useLocaleDigits;

  /// রানটাইম ডিকশনারি বা ভাষা আপডেট সংস্করণ কাউন্টার।
  final int revision;

  /// ডিভাইসের সিস্টেম ভাষা ফলো করছে কি না।
  bool get followSystem => selectedLocale == null;

  /// অ্যাপ ও `MaterialApp`-এ প্রয়োগের জন্য কার্যকর [Locale]।
  Locale get effectiveLocale =>
      selectedLocale ?? Locale(language.languageCode, country.isoCode);

  /// সক্রিয় ভাষা ডান-থেকে-বামে (RTL) কি না।
  bool get isRtl => language.isRtl;

  /// সক্রিয় [TextDirection] (`rtl` বা `ltr`)।
  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// ক্ষেত্র পরিবর্তন করে নতুন কপি তৈরি করে।
  OmniLocaleState copyWith({
    OmniLanguage? language,
    OmniCountryCode? country,
    Locale? selectedLocale,
    bool clearSelectedLocale = false,
    Locale? systemLocale,
    OmniLanguage? fallbackLanguage,
    bool? useLocaleDigits,
    int? revision,
  }) => OmniLocaleState(
    language: language ?? this.language,
    country: country ?? this.country,
    selectedLocale: clearSelectedLocale
        ? null
        : (selectedLocale ?? this.selectedLocale),
    systemLocale: systemLocale ?? this.systemLocale,
    fallbackLanguage: fallbackLanguage ?? this.fallbackLanguage,
    useLocaleDigits: useLocaleDigits ?? this.useLocaleDigits,
    revision: revision ?? this.revision,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OmniLocaleState &&
          language == other.language &&
          country == other.country &&
          selectedLocale == other.selectedLocale &&
          systemLocale == other.systemLocale &&
          fallbackLanguage == other.fallbackLanguage &&
          useLocaleDigits == other.useLocaleDigits &&
          revision == other.revision;

  @override
  int get hashCode => Object.hash(
    language,
    country,
    selectedLocale,
    systemLocale,
    fallbackLanguage,
    useLocaleDigits,
    revision,
  );
}

/// `SharedPreferences`-মুক্ত ও শূন্য-লিক গ্লোবাল লিসেনেবল চ্যানেল — `OmniText` এবং
/// `OmniApp` কোনো ম্যানুয়াল `dispose()` ছাড়াই সব স্ক্রিনে রি-বিল্ড সিঙ্ক করে।
final class _OmniLocaleChannel implements ValueListenable<OmniLocaleState> {
  OmniLocaleState _value = const OmniLocaleState(
    language: OmniLanguage.en,
    country: OmniCountryCode.us,
    selectedLocale: Locale('en', 'US'),
  );

  final Set<VoidCallback> _listeners = <VoidCallback>{};

  @override
  OmniLocaleState get value => _value;

  void setValue(OmniLocaleState next) {
    if (_value == next) return;
    _value = next;
    if (_listeners.isEmpty) return;
    final snapshot = List<VoidCallback>.of(_listeners);
    for (final listener in snapshot) {
      if (_listeners.contains(listener)) {
        listener();
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// প্রোগ্রাম্যাটিক কন্ট্রোলার (ঐচ্ছিক — চাইলে গ্লোবাল `OmniText.setLanguage(...)`-এর
/// পাশাপাশি আলাদা [storageKey] বা আইসোলেটেড অ্যাপ-ট্রি চালাতে ব্যবহার করা যায়)।
class OmniLocaleController extends ValueNotifier<OmniLocaleState> {
  /// প্রদত্ত প্রাথমিক ভাষা ও দেশ দিয়ে লোকেল কন্ট্রোলার তৈরি করে।
  OmniLocaleController({
    OmniLanguage initialLanguage = OmniLanguage.en,
    OmniCountryCode? initialCountry,
    OmniLanguage fallbackLanguage = OmniLanguage.en,
    bool followSystem = false,
    bool useLocaleDigits = false,
    this.persist = true,
    this.storageKey = 'default',
  }) : super(
         OmniLocaleState(
           language: initialLanguage,
           country: initialCountry ?? initialLanguage.country,
           selectedLocale: followSystem
               ? null
               : Locale(
                   initialLanguage.languageCode,
                   (initialCountry ?? initialLanguage.country).isoCode,
                 ),
           systemLocale: PlatformDispatcher.instance.locale,
           fallbackLanguage: fallbackLanguage,
           useLocaleDigits: useLocaleDigits,
         ),
       );

  /// `SharedPreferences`-এ ভাষা ও দেশ পছন্দ সংরক্ষণ করবে কি না।
  final bool persist;

  /// একাধিক প্রোফাইল/অ্যাপের ডেটা আলাদা রাখার স্টোরেজ কী।
  final String storageKey;

  bool _disposed = false;
  bool _hydrated = false;

  /// Counts user choices; a choice made while [hydrate] reads storage wins
  /// over the (older) stored state.
  int _userEdits = 0;

  /// [language] এবং ঐচ্ছিক [country] সেট করে অটো সব স্ক্রিন আপডেট ও সেভ করে।
  void setLanguage(OmniLanguage language, {OmniCountryCode? country}) {
    if (_disposed) return;
    final resolvedCountry = country ?? language.country;
    final nextLocale = Locale(language.languageCode, resolvedCountry.isoCode);
    value = value.copyWith(
      language: language,
      country: resolvedCountry,
      selectedLocale: nextLocale,
      revision: value.revision + 1,
    );
    _userEdits++;
    if (persist) {
      unawaited(_savePrefs(storageKey, value));
    }
  }

  /// টাইপ-সেইফ [OmniCountryCode] দিয়ে দেশ ও ভাষা পরিবর্তন করে।
  void setCountry(OmniCountryCode country, {OmniLanguage? language}) {
    setLanguage(language ?? country.defaultLanguage, country: country);
  }

  /// নির্দিষ্ট Flutter [Locale] সেট করে।
  void setLocale(Locale locale) {
    final lang = OmniLanguage.fromLocale(
      locale,
      fallback: value.fallbackLanguage,
    );
    final country = OmniCountryCode.tryFromLocale(locale) ?? lang.country;
    setLanguage(lang, country: country);
  }

  /// ডিভাইসের সিস্টেম ভাষা ফলো মোড চালু করে।
  void useSystem() {
    if (_disposed) return;
    final sys = PlatformDispatcher.instance.locale;
    final lang = OmniLanguage.fromLocale(sys, fallback: value.fallbackLanguage);
    final country = OmniCountryCode.tryFromLocale(sys) ?? lang.country;
    value = value.copyWith(
      language: lang,
      country: country,
      clearSelectedLocale: true,
      systemLocale: sys,
      revision: value.revision + 1,
    );
    _userEdits++;
    if (persist) {
      unawaited(_savePrefs(storageKey, value));
    }
  }

  /// ডিভাইসের সিস্টেম লোকেল পরিবর্তন হলে সিঙ্ক করে।
  void syncSystemLocale(Locale sysLocale) {
    if (_disposed) return;
    if (!value.followSystem) {
      if (value.systemLocale != sysLocale) {
        value = value.copyWith(systemLocale: sysLocale);
      }
      return;
    }
    final lang = OmniLanguage.fromLocale(
      sysLocale,
      fallback: value.fallbackLanguage,
    );
    final country = OmniCountryCode.tryFromLocale(sysLocale) ?? lang.country;
    value = value.copyWith(
      language: lang,
      country: country,
      clearSelectedLocale: true,
      systemLocale: sysLocale,
      revision: value.revision + 1,
    );
  }

  /// স্থানীয় ডিজিট (`০১২৩`) চালু বা বন্ধ করে।
  void setUseLocaleDigits(bool enabled) {
    if (_disposed || value.useLocaleDigits == enabled) return;
    value = value.copyWith(
      useLocaleDigits: enabled,
      revision: value.revision + 1,
    );
    _userEdits++;
    if (persist) {
      unawaited(_savePrefs(storageKey, value));
    }
  }

  /// স্টার্টআপে নন-ব্লকিংভাবে সেভ করা ভাষা ও দেশ লোড করে।
  Future<void> hydrate() async {
    if (!persist || _hydrated || _disposed) return;
    _hydrated = true;
    final editsBefore = _userEdits;
    final restored = OmniPreferences.cached != null
        ? _restoreFromPrefs(OmniPreferences.cached!, storageKey, value)
        : await _loadPrefs(storageKey, value);
    if (!_disposed &&
        _userEdits == editsBefore &&
        restored != null &&
        restored != value) {
      value = restored;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<void> _savePrefs(String storageKey, OmniLocaleState state) async {
  try {
    final prefs = await OmniPreferences.load();
    await prefs.setBool(
      'omni_route.l10n.$storageKey.followSystem',
      state.followSystem,
    );
    if (!state.followSystem) {
      await prefs.setString(
        'omni_route.l10n.$storageKey.language',
        state.language.name,
      );
      await prefs.setString(
        'omni_route.l10n.$storageKey.country',
        state.country.isoCode,
      );
    }
    await prefs.setBool(
      'omni_route.l10n.$storageKey.digits',
      state.useLocaleDigits,
    );
  } catch (e, st) {
    omniReportRecovered('l10n.save', e, st);
    // হেডলেস টেস্টে নিরাপদ ইগনোর।
  }
}

Future<OmniLocaleState?> _loadPrefs(
  String storageKey,
  OmniLocaleState base,
) async {
  try {
    return _restoreFromPrefs(await OmniPreferences.load(), storageKey, base);
  } catch (e, st) {
    omniReportRecovered('l10n.load', e, st);
    return null;
  }
}

/// Reads the saved language synchronously from already-loaded [prefs].
OmniLocaleState? _restoreFromPrefs(
  SharedPreferences prefs,
  String storageKey,
  OmniLocaleState base,
) {
  {
    final follow = prefs.getBool('omni_route.l10n.$storageKey.followSystem');
    final rawLang = prefs.getString('omni_route.l10n.$storageKey.language');
    final rawCountry = prefs.getString('omni_route.l10n.$storageKey.country');
    final digits = prefs.getBool('omni_route.l10n.$storageKey.digits');

    if (follow == true) {
      final sys = PlatformDispatcher.instance.locale;
      final lang = OmniLanguage.fromLocale(
        sys,
        fallback: base.fallbackLanguage,
      );
      final country = OmniCountryCode.tryFromLocale(sys) ?? lang.country;
      return base.copyWith(
        language: lang,
        country: country,
        clearSelectedLocale: true,
        systemLocale: sys,
        useLocaleDigits: digits ?? base.useLocaleDigits,
      );
    }
    if (rawLang == null && rawCountry == null && digits == null) return null;
    final lang = OmniLanguage.tryParse(rawLang) ?? base.language;
    final country = OmniCountryCode.tryFromCode(rawCountry) ?? lang.country;
    return base.copyWith(
      language: lang,
      country: country,
      selectedLocale: Locale(lang.languageCode, country.isoCode),
      useLocaleDigits: digits ?? base.useLocaleDigits,
    );
  }
}

/// `OmniApp`-এর জন্য ঐচ্ছিক লোকালাইজেশন কনফিগারেশন (কিন্তু শূন্য কনফিগ ছাড়াও
/// `OmniText` পুরোপুরি অটোমেটিক কাজ করে!)।
@immutable
class OmniLocalization {
  /// লোকালাইজেশন ও ভাষা-সুইচিং আচরণ কনফিগার করে।
  const OmniLocalization({
    this.initialLanguage,
    this.initialCountry,
    this.supportedLanguages = OmniLanguage.popular,
    this.fallbackLanguage = OmniLanguage.en,
    this.followSystemOnFirstLaunch = false,
    this.persist = true,
    this.storageKey = 'default',
    this.useLocaleDigits = false,
    this.animateTransition = true,
    this.localeFonts = const <String, String>{},
    this.languageTextScale = const <String, double>{},
  });

  /// শুরুর ভাষা (না দিলে পূর্বের সেভ করা বা ইংরেজি)।
  final OmniLanguage? initialLanguage;

  /// শুরুর দেশ।
  final OmniCountryCode? initialCountry;

  /// অ্যাপে সমর্থিত ভাষার তালিকা ([OmniLanguagePicker] পিকারে দেখাতে ব্যবহৃত হয়)।
  final List<OmniLanguage> supportedLanguages;

  /// অনূদিত টেক্সট না মিললে ডিফল্ট ফলব্যাক ভাষা।
  final OmniLanguage fallbackLanguage;

  /// প্রথমবার চালু হলে ডিভাইসের ভাষা ফলো করবে কি না।
  final bool followSystemOnFirstLaunch;

  /// `SharedPreferences`-এ নির্বাচিত ভাষা সেভ রাখবে কি না।
  final bool persist;

  /// পারসিস্টেন্সের আলাদা কী।
  final String storageKey;

  /// বাংলা/আরবি মোডে সংখ্যা (`0-9`) অটো স্থানীয় অঙ্কে (`০-৯`) রূপান্তর করবে কি না।
  final bool useLocaleDigits;

  /// ভাষা বদলালে স্ক্রিনে হালকা অ্যানিমেশন চলবে কি না।
  final bool animateTransition;

  /// ভাষা কোড অনুযায়ী ঐচ্ছিক কাস্টম ফন্ট (`{'bn': 'HindSiliguri', 'ar': 'Cairo'}`)।
  final Map<String, String> localeFonts;

  /// Extra text scale per language code, combined with the user's text size
  /// and the OS accessibility setting (e.g. `{'bn': 1.06}` because Bengali
  /// glyphs look smaller than Latin ones at the same font size).
  final Map<String, double> languageTextScale;

  /// The font configured for [language] in [localeFonts], or `null`.
  String? fontFor(OmniLanguage language) {
    final font = localeFonts[language.languageCode];
    return (font == null || font.isEmpty) ? null : font;
  }

  /// The [languageTextScale] factor for [language] (`1.0` when unset).
  double textScaleFor(OmniLanguage language) {
    final f = languageTextScale[language.languageCode];
    return (f == null || f <= 0) ? 1.0 : f;
  }
}

/// উইজেট ট্রির যেকোনো জায়গায় বর্তমান [OmniLocaleState]-এ সাবস্ক্রিপশন দেয়।
class OmniL10nScope
    extends InheritedNotifier<ValueListenable<OmniLocaleState>> {
  /// [listenable] সহ স্কোপ তৈরি করে।
  const OmniL10nScope({
    super.key,
    required ValueListenable<OmniLocaleState> listenable,
    this.config = const OmniLocalization(),
    this.controller,
    required super.child,
  }) : super(notifier: listenable);

  /// সক্রিয় কনফিগারেশন।
  final OmniLocalization config;

  /// ঐচ্ছিক নিজস্ব কন্ট্রোলার (`null` হলে গ্লোবাল `OmniText` চ্যানেল)।
  final OmniLocaleController? controller;

  /// সবচেয়ে কাছের [OmniL10nScope] রিটার্ন করে (এবং লিসেনার হিসেবে রেজিস্টার করে)।
  static OmniL10nScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniL10nScope>();

  /// বর্তমান [OmniLocaleState] ওয়াচ করে যাতে ভাষা বদলালেই উইজেট অটো রি-বিল্ড হয়।
  static OmniLocaleState watch(BuildContext context) =>
      maybeOf(context)?.notifier?.value ?? OmniText.state;

  @override
  bool updateShouldNotify(covariant OmniL10nScope oldWidget) =>
      oldWidget.notifier != notifier ||
      oldWidget.config != config ||
      oldWidget.notifier?.value != notifier?.value;
}

/// `OmniApp` বা রুট অ্যাপে লোকালাইজেশন অটো-সিঙ্ক, OS লোকেল অবজারভার ও স্টার্টআপ হাইড্রেশন
/// প্রদান করে (শূন্য কনফিগ ছাড়াও সব `OmniText` স্বয়ংক্রিয়ভাবে কাজ করে)।
class OmniLocalizationHost extends StatefulWidget {
  /// [child] অ্যাপ ট্রিকে লোকালাইজেশন স্কোপে মোড়ায়।
  const OmniLocalizationHost({
    super.key,
    this.config = const OmniLocalization(),
    this.controller,
    required this.child,
  });

  /// ঐচ্ছিক লোকালাইজেশন কনফিগারেশন।
  final OmniLocalization config;

  /// ঐচ্ছিক কাস্টম কন্ট্রোলার (`null` হলে শূন্য-সেটআপ গ্লোবাল `OmniText`)।
  final OmniLocaleController? controller;

  /// অ্যাপ রুট চাইল্ড।
  final Widget child;

  @override
  State<OmniLocalizationHost> createState() => _OmniLocalizationHostState();
}

class _OmniLocalizationHostState extends State<OmniLocalizationHost>
    with WidgetsBindingObserver {
  ValueListenable<OmniLocaleState> get _activeListenable =>
      widget.controller ?? OmniText.listenable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyConfig();
  }

  void _applyConfig() {
    if (widget.controller != null) {
      unawaited(widget.controller!.hydrate());
      return;
    }
    OmniText._attachHostConfig(widget.config);
    unawaited(OmniText._hydrateGlobalOnce(widget.config));
  }

  @override
  void didUpdateWidget(covariant OmniLocalizationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.config != oldWidget.config) {
      _applyConfig();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final sys = (locales != null && locales.isNotEmpty)
        ? locales.first
        : PlatformDispatcher.instance.locale;
    if (widget.controller != null) {
      widget.controller!.syncSystemLocale(sys);
    } else {
      OmniText._syncSystemLocale(sys);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _activeListenable,
      builder: (context, _) {
        final state = _activeListenable.value;
        final font = widget.config.fontFor(state.language);
        return OmniL10nScope(
          listenable: _activeListenable,
          config: widget.config,
          controller: widget.controller,
          // Always present (even without a font) so switching between a
          // language with a font and one without never changes the tree
          // shape, which would remount the whole app. Material screens get
          // the font through the theme (see OmniUiHost).
          child: DefaultTextStyle.merge(
            style: TextStyle(fontFamily: font),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// বহুভাষিক টেক্সটের **একক ও সর্বময় নিয়ন্ত্রক উইজেট এবং এপিআই (`OmniText`)**।
///
/// ১) **সরাসরি Widget হিসেবে ব্যবহার করুন (শূন্য অতিরিক্ত সেটআপ!)**:
/// ```dart
/// const OmniText(en: 'Welcome', bn: 'স্বাগতম', ar: 'مرحباً')
/// ```
///
/// ২) **অন্য ফাইলে কনস্ট্যান্ট বা ফাংশনে রেখে `.tr(context)` অথবা `context` ছাড়াই `.value` পড়ুন**:
/// ```dart
/// const greeting = OmniText(en: 'Hello, {name}', bn: 'হ্যালো, {name}');
/// greeting.tr(context, args: {'name': 'Juwel'});
/// ```
///
/// ৩) **পুরো অ্যাপের সব স্ক্রিনে মুহূর্তেই ভাষা বা দেশ পাল্টান (কোনো রিলোড ছাড়াই!)**:
/// ```dart
/// OmniText.setLanguage(OmniLanguage.bn);
/// OmniText.setCountry(OmniCountryCode.bd);
/// OmniText.change(OmniLanguage.ar);
/// ```
class OmniText extends StatelessWidget {
  /// যেকোনো ভাষার সরাসরি ইনলাইন বা টাইপ-সেইফ [byLanguage] / [byCountry] ম্যাপসহ [OmniText] তৈরি করে।
  const OmniText({
    super.key,
    this.textKey,
    this.en,
    this.bn,
    this.ar,
    this.hi,
    this.ur,
    this.es,
    this.fr,
    this.de,
    this.pt,
    this.it,
    this.ja,
    this.ko,
    this.zh,
    this.trText,
    this.id,
    this.ms,
    this.ru,
    this.th,
    this.vi,
    this.ne,
    this.ta,
    this.fa,
    this.he,
    this.nl,
    this.pl,
    this.uk,
    this.sv,
    this.fil,
    this.sw,
    this.byLanguage,
    this.byCountry,
    this.other,
    this.fallback,
    this.args,
    this.localizeDigits,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
  });

  /// ঐচ্ছিক কী — নিবন্ধিত JSON বা সার্ভার ওভাররাইড ম্যাপ থেকে টেক্সট বদলাতে।
  final String? textKey;

  /// English text (`en`).
  final String? en;

  /// Bengali text (`bn`).
  final String? bn;

  /// Arabic text (`ar`).
  final String? ar;

  /// Hindi text (`hi`).
  final String? hi;

  /// Urdu text (`ur`).
  final String? ur;

  /// Spanish text (`es`).
  final String? es;

  /// French text (`fr`).
  final String? fr;

  /// German text (`de`).
  final String? de;

  /// Portuguese text (`pt`).
  final String? pt;

  /// Italian text (`it`).
  final String? it;

  /// Japanese text (`ja`).
  final String? ja;

  /// Korean text (`ko`).
  final String? ko;

  /// Chinese text (`zh`).
  final String? zh;

  /// Turkish text (`tr`).
  final String? trText;

  /// Indonesian text (`id`).
  final String? id;

  /// Malay text (`ms`).
  final String? ms;

  /// Russian text (`ru`).
  final String? ru;

  /// Thai text (`th`).
  final String? th;

  /// Vietnamese text (`vi`).
  final String? vi;

  /// Nepali text (`ne`).
  final String? ne;

  /// Tamil text (`ta`).
  final String? ta;

  /// Persian / Farsi text (`fa`).
  final String? fa;

  /// Hebrew text (`he`).
  final String? he;

  /// Dutch text (`nl`).
  final String? nl;

  /// Polish text (`pl`).
  final String? pl;

  /// Ukrainian text (`uk`).
  final String? uk;

  /// Swedish text (`sv`).
  final String? sv;

  /// Filipino / Tagalog text (`fil`).
  final String? fil;

  /// Swahili text (`sw`).
  final String? sw;

  /// টাইপ-সেইফ [OmniLanguage] ইনাম অনুযায়ী যেকোনো ভাষা বা আঞ্চলিক অনুবাদ ম্যাপ।
  final Map<OmniLanguage, String>? byLanguage;

  /// টাইপ-সেইফ [OmniCountryCode] ইনাম অনুযায়ী নির্দিষ্ট দেশের অনুবাদ ম্যাপ।
  final Map<OmniCountryCode, String>? byCountry;

  /// যেকোনো কাস্টম ISO ভাষা/রিজিওন ট্যাগের (`'el'`, `'pt_BR'`, ...) ম্যাপ।
  final Map<String, String>? other;

  /// কোনো ভাষাতেই টেক্সট না থাকলে শেষ ফলব্যাক।
  final String? fallback;

  /// `{key}` প্লেসহোল্ডার প্রতিস্থাপনের ডায়নামিক আর্গুমেন্ট।
  final Map<String, Object?>? args;

  /// সংখ্যাগুলো (`0-9`) স্থানীয় অঙ্কে রূপান্তর করবে কি না (`null` হলে গ্লোবাল সেটিং)।
  final bool? localizeDigits;

  /// সরাসরি `Widget` হিসেবে ব্যবহার করলে টেক্সট স্টাইল।
  final TextStyle? style;

  /// সরাসরি `Widget` হিসেবে স্ট্রাট স্টাইল।
  final StrutStyle? strutStyle;

  /// টেক্সট অ্যালাইনমেন্ট।
  final TextAlign? textAlign;

  /// টেক্সট ডিরেকশন (`null` হলে সক্রিয় ভাষা অনুযায়ী অটো RTL/LTR)।
  final TextDirection? textDirection;

  /// অটো লাইন র‍্যাপ।
  final bool? softWrap;

  /// ওভারফ্লো আচরণ।
  final TextOverflow? overflow;

  /// টেক্সট স্কেলার।
  final TextScaler? textScaler;

  /// সর্বোচ্চ লাইন সংখ্যা।
  final int? maxLines;

  /// অ্যাক্সেসিবিলিটি লেবেল।
  final String? semanticsLabel;

  // ── গ্লোবাল স্টেট ও লাইফসাইকেল ─────────────────────────────────────────────

  static final _OmniLocaleChannel _channel = _OmniLocaleChannel();
  static final Map<String, Map<String, String>> _registeredTags = {};
  static final Map<OmniCountryCode, Map<String, String>> _registeredCountries =
      {};
  static List<OmniLanguage> _supportedLanguages = OmniLanguage.popular;
  static bool _explicitlyChanged = false;
  static bool _globalHydrated = false;
  static String _globalStorageKey = 'default';
  static bool _globalPersist = true;

  /// পুরো অ্যাপে সাবস্ক্রাইব করার জন্য রিঅ্যাকটিভ [ValueListenable]।
  static ValueListenable<OmniLocaleState> get listenable => _channel;

  /// বর্তমান গ্লোবাল লোকেল স্টেট।
  static OmniLocaleState get state => _channel.value;

  /// বর্তমানে সক্রিয় ভাষা ([OmniLanguage])।
  static OmniLanguage get currentLanguage => _channel.value.language;

  /// বর্তমানে সক্রিয় দেশ ([OmniCountryCode])।
  static OmniCountryCode get currentCountry => _channel.value.country;

  /// বর্তমানে সক্রিয় Flutter [Locale]।
  static Locale get currentLocale => _channel.value.effectiveLocale;

  /// বর্তমানে ডান-থেকে-বাম (RTL) লেআউট সক্রিয় কি না।
  static bool get isRtl => _channel.value.isRtl;

  /// ডিভাইসের সিস্টেম ভাষা ফলো করছে কি না।
  static bool get followSystem => _channel.value.followSystem;

  /// স্থানীয় ডিজিট রূপান্তর (`০-৯`, `٠-٩`) চালু আছে কি না।
  static bool get useLocaleDigits => _channel.value.useLocaleDigits;

  /// অ্যাপে সমর্থিত ভাষার তালিকা।
  static List<OmniLanguage> get supportedLanguages =>
      List<OmniLanguage>.unmodifiable(_supportedLanguages);

  /// সমর্থিত ভাষার তালিকা সেট করে (যেমন `OmniLanguagePicker`-এ দেখাতে)।
  static void configureSupportedLanguages(List<OmniLanguage> languages) {
    if (languages.isEmpty) return;
    _supportedLanguages = List<OmniLanguage>.of(languages);
  }

  /// **১ কল-এ পুরো অ্যাপের ভাষা পরিবর্তন করে** — কোনো রিলোড বা বাড়তি সেটআপ ছাড়াই
  /// সব স্ক্রিন, ফিল্ড, টাইটেল, বাটন ও RTL মুহূর্তেই আপডেট হয়ে যায়।
  static void setLanguage(
    OmniLanguage language, {
    OmniCountryCode? country,
    bool persist = true,
  }) {
    _explicitlyChanged = true;
    final resolvedCountry = country ?? language.country;
    final next = _channel.value.copyWith(
      language: language,
      country: resolvedCountry,
      selectedLocale: Locale(language.languageCode, resolvedCountry.isoCode),
      revision: _channel.value.revision + 1,
    );
    _channel.setValue(next);
    if (persist && _globalPersist) {
      unawaited(_savePrefs(_globalStorageKey, next));
    }
  }

  /// [setLanguage]-এর সংক্ষিপ্ত শর্টকাট (`OmniText.change(OmniLanguage.bn)`)।
  static void change(
    OmniLanguage language, {
    OmniCountryCode? country,
    bool persist = true,
  }) => setLanguage(language, country: country, persist: persist);

  /// **টাইপ-সেইফ কান্ট্রি কোড (`OmniCountryCode`) দিয়ে পুরো অ্যাপের দেশ ও ভাষা পরিবর্তন করে**।
  static void setCountry(
    OmniCountryCode country, {
    OmniLanguage? language,
    bool persist = true,
  }) => setLanguage(
    language ?? country.defaultLanguage,
    country: country,
    persist: persist,
  );

  /// Flutter [Locale] (`Locale('bn', 'BD')`) দিয়ে ভাষা ও দেশ পরিবর্তন করে।
  static void setLocale(Locale locale, {bool persist = true}) {
    final lang = OmniLanguage.fromLocale(
      locale,
      fallback: _channel.value.fallbackLanguage,
    );
    final country = OmniCountryCode.tryFromLocale(locale) ?? lang.country;
    setLanguage(lang, country: country, persist: persist);
  }

  /// তালিকাভুক্ত পরবর্তী ভাষায় ১ ক্লিকে সুইচ করে।
  static OmniLanguage nextLanguage({List<OmniLanguage>? among}) {
    final list = (among != null && among.isNotEmpty)
        ? among
        : _supportedLanguages;
    final idx = list.indexWhere(
      (l) =>
          l == currentLanguage ||
          l.languageCode == currentLanguage.languageCode,
    );
    final next = idx < 0 ? list.first : list[(idx + 1) % list.length];
    setLanguage(next);
    return next;
  }

  /// ডিভাইসের সিস্টেম ভাষা ফলো মোড চালু করে।
  static void useSystem({bool persist = true}) {
    _explicitlyChanged = true;
    final sys = PlatformDispatcher.instance.locale;
    final lang = OmniLanguage.fromLocale(
      sys,
      fallback: _channel.value.fallbackLanguage,
    );
    final country = OmniCountryCode.tryFromLocale(sys) ?? lang.country;
    final next = _channel.value.copyWith(
      language: lang,
      country: country,
      clearSelectedLocale: true,
      systemLocale: sys,
      revision: _channel.value.revision + 1,
    );
    _channel.setValue(next);
    if (persist && _globalPersist) {
      unawaited(_savePrefs(_globalStorageKey, next));
    }
  }

  /// সংখ্যা (`0-9`) স্বয়ংক্রিয়ভাবে স্থানীয় অঙ্কে রূপান্তর (`০-৯`, `٠-٩`) চালু/বন্ধ করে।
  static void setUseLocaleDigits(bool enabled, {bool persist = true}) {
    if (_channel.value.useLocaleDigits == enabled) return;
    final next = _channel.value.copyWith(
      useLocaleDigits: enabled,
      revision: _channel.value.revision + 1,
    );
    _channel.setValue(next);
    if (persist && _globalPersist) {
      unawaited(_savePrefs(_globalStorageKey, next));
    }
  }

  /// অনূদিত মান না পেলে কোন ভাষায় ফলব্যাক করবে তা সেট করে (ডিফল্ট `OmniLanguage.en`)।
  static void setFallbackLanguage(OmniLanguage language) {
    if (_channel.value.fallbackLanguage == language) return;
    _channel.setValue(
      _channel.value.copyWith(
        fallbackLanguage: language,
        revision: _channel.value.revision + 1,
      ),
    );
  }

  /// ঐচ্ছিক কী-ভিত্তিক JSON/API অনুবাদ রানটাইমে যোগ বা ওভাররাইড করে।
  static void registerTranslations(
    OmniLanguage language,
    Map<String, String> entries,
  ) {
    if (entries.isEmpty) return;
    (_registeredTags[language.tag] ??= <String, String>{}).addAll(entries);
    (_registeredTags[language.languageCode] ??= <String, String>{}).addAll(
      entries,
    );
    _channel.setValue(
      _channel.value.copyWith(revision: _channel.value.revision + 1),
    );
  }

  /// নির্দিষ্ট দেশের জন্য কী-ভিত্তিক ওভাররাইড অনুবাদ নিবন্ধন করে।
  static void registerCountryTranslations(
    OmniCountryCode country,
    Map<String, String> entries,
  ) {
    if (entries.isEmpty) return;
    (_registeredCountries[country] ??= <String, String>{}).addAll(entries);
    _channel.setValue(
      _channel.value.copyWith(revision: _channel.value.revision + 1),
    );
  }

  /// স্ট্রিং-ট্যাগ বা নেস্টেড JSON থেকে অনুবাদ যোগ করে।
  static void registerJson(String localeTag, Map<String, Object?> json) {
    final flat = <String, String>{};
    void flatten(String prefix, Map<String, Object?> map) {
      for (final entry in map.entries) {
        final k = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        final v = entry.value;
        if (v is Map) {
          flatten(k, v.cast<String, Object?>());
        } else if (v != null) {
          flat[k] = v.toString();
        }
      }
    }

    flatten('', json);
    if (flat.isEmpty) return;
    final norm = localeTag.trim().replaceAll('-', '_');
    (_registeredTags[norm] ??= <String, String>{}).addAll(flat);
    final base = norm.split('_').first.toLowerCase();
    (_registeredTags[base] ??= <String, String>{}).addAll(flat);
    _channel.setValue(
      _channel.value.copyWith(revision: _channel.value.revision + 1),
    );
  }

  /// টেস্ট বা সেশন রিসেটের জন্য গ্লোবাল স্টেট ইংরেজিতে ফিরিয়ে নেয়।
  static void reset({
    OmniLanguage language = OmniLanguage.en,
    bool clearRegistered = false,
  }) {
    if (clearRegistered) {
      _registeredTags.clear();
      _registeredCountries.clear();
    }
    _supportedLanguages = OmniLanguage.popular;
    _explicitlyChanged = false;
    _globalHydrated = false;
    _globalStorageKey = 'default';
    _globalPersist = true;
    _channel.setValue(
      OmniLocaleState(
        language: language,
        country: language.country,
        selectedLocale: language.locale,
      ),
    );
  }

  static void _attachHostConfig(OmniLocalization config) {
    _supportedLanguages = config.supportedLanguages;
    _globalStorageKey = config.storageKey;
    _globalPersist = config.persist;
    if (_explicitlyChanged) return;

    if (config.initialLanguage != null || config.initialCountry != null) {
      final lang =
          config.initialLanguage ?? config.initialCountry!.defaultLanguage;
      final country = config.initialCountry ?? lang.country;
      _channel.setValue(
        OmniLocaleState(
          language: lang,
          country: country,
          selectedLocale: Locale(lang.languageCode, country.isoCode),
          systemLocale: PlatformDispatcher.instance.locale,
          fallbackLanguage: config.fallbackLanguage,
          useLocaleDigits: config.useLocaleDigits,
          revision: _channel.value.revision,
        ),
      );
    } else if (config.followSystemOnFirstLaunch) {
      final sys = PlatformDispatcher.instance.locale;
      final lang = OmniLanguage.fromLocale(
        sys,
        fallback: config.fallbackLanguage,
      );
      final country = OmniCountryCode.tryFromLocale(sys) ?? lang.country;
      _channel.setValue(
        OmniLocaleState(
          language: lang,
          country: country,
          selectedLocale: null,
          systemLocale: sys,
          fallbackLanguage: config.fallbackLanguage,
          useLocaleDigits: config.useLocaleDigits,
          revision: _channel.value.revision,
        ),
      );
    }
  }

  static Future<void> _hydrateGlobalOnce(OmniLocalization config) async {
    if (!config.persist || _globalHydrated || _explicitlyChanged) return;
    _globalHydrated = true;
    final restored = OmniPreferences.cached != null
        ? _restoreFromPrefs(
            OmniPreferences.cached!,
            config.storageKey,
            _channel.value,
          )
        : await _loadPrefs(config.storageKey, _channel.value);
    if (restored != null && !_explicitlyChanged && restored != _channel.value) {
      _channel.setValue(
        restored.copyWith(revision: _channel.value.revision + 1),
      );
    }
  }

  static void _syncSystemLocale(Locale sysLocale) {
    if (!_channel.value.followSystem) {
      if (_channel.value.systemLocale != sysLocale) {
        _channel.setValue(_channel.value.copyWith(systemLocale: sysLocale));
      }
      return;
    }
    final lang = OmniLanguage.fromLocale(
      sysLocale,
      fallback: _channel.value.fallbackLanguage,
    );
    final country = OmniCountryCode.tryFromLocale(sysLocale) ?? lang.country;
    _channel.setValue(
      _channel.value.copyWith(
        language: lang,
        country: country,
        clearSelectedLocale: true,
        systemLocale: sysLocale,
        revision: _channel.value.revision + 1,
      ),
    );
  }

  /// ইংরেজি ASCII অঙ্ক (`0-9`) সক্রিয় বা নির্দিষ্ট [language]-এর স্থানীয় অঙ্কে রূপান্তর করে।
  static String formatDigits(String input, {OmniLanguage? language}) {
    final code = (language ?? currentLanguage).languageCode;
    final zeroPoint = switch (code) {
      'bn' => 0x09E6, // ০-৯
      'ar' => 0x0660, // ٠-٩
      'fa' || 'ur' || 'ps' => 0x06F0, // ۰-۹
      'hi' || 'mr' || 'ne' => 0x0966, // ०-९
      'pa' => 0x0A66, // ੦-੯
      'gu' => 0x0AE6, // ૦-૯
      'kn' => 0x0CE6, // ೦-೯
      'ml' => 0x0D66, // ൦-൯
      'te' => 0x0C66, // ౦-౯
      'th' => 0x0E50, // ๐-๙
      'my' => 0x1040, // ၀-၉
      _ => null,
    };
    if (zeroPoint == null) return input;
    final buf = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buf.writeCharCode(zeroPoint + (rune - 0x30));
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  /// সব ইনপুট উৎস থেকে প্রদত্ত [state]-এর জন্য সঠিক অনুবাদ নির্ণয় করে।
  static String resolveTextFor(
    OmniLocaleState state, {
    String? textKey,
    String? en,
    String? bn,
    String? ar,
    String? hi,
    String? ur,
    String? es,
    String? fr,
    String? de,
    String? pt,
    String? it,
    String? ja,
    String? ko,
    String? zh,
    String? trText,
    String? id,
    String? ms,
    String? ru,
    String? th,
    String? vi,
    String? ne,
    String? ta,
    String? fa,
    String? he,
    String? nl,
    String? pl,
    String? uk,
    String? sv,
    String? fil,
    String? sw,
    Map<OmniLanguage, String>? byLanguage,
    Map<OmniCountryCode, String>? byCountry,
    Map<String, String>? other,
    String? fallback,
    Map<String, Object?>? args,
    bool? localizeDigits,
  }) {
    String? shortcutForCode(String code) => switch (code) {
      'en' => en,
      'bn' => bn,
      'ar' => ar,
      'hi' => hi,
      'ur' => ur,
      'es' => es,
      'fr' => fr,
      'de' => de,
      'pt' => pt,
      'it' => it,
      'ja' => ja,
      'ko' => ko,
      'zh' => zh,
      'tr' => trText,
      'id' => id,
      'ms' => ms,
      'ru' => ru,
      'th' => th,
      'vi' => vi,
      'ne' => ne,
      'ta' => ta,
      'fa' => fa,
      'he' => he,
      'nl' => nl,
      'pl' => pl,
      'uk' => uk,
      'sv' => sv,
      'fil' => fil,
      'sw' => sw,
      _ => null,
    };

    String? lookupOther(String tag) {
      if (other == null || other.isEmpty) return null;
      final norm = tag.toLowerCase().replaceAll('-', '_');
      for (final entry in other.entries) {
        if (entry.key.toLowerCase().replaceAll('-', '_') == norm) {
          return entry.value;
        }
      }
      return null;
    }

    String? resolved;

    // ১. নিবন্ধিত কী-ভিত্তিক JSON/API ওভাররাইড (দেশ -> ভাষা_দেশ -> ভাষা):
    if (textKey != null && textKey.isNotEmpty) {
      resolved =
          _registeredCountries[state.country]?[textKey] ??
          _registeredTags['${state.language.languageCode}_${state.country.isoCode}']?[textKey] ??
          _registeredTags[state.language.tag]?[textKey] ??
          _registeredTags[state.language.languageCode]?[textKey];
    }

    // ২. নির্দিষ্ট দেশ অনুযায়ী টাইপ-সেইফ ওভাররাইড:
    resolved ??= byCountry?[state.country];

    // ৩. সঠিক ভাষা + আঞ্চলিক ইনাম:
    resolved ??= byLanguage?[state.language];
    resolved ??= byLanguage?[state.language.baseLanguage];

    // ৪. সরাসরি নেমড প্যারামিটার (`en`, `bn`, `ar`, ...):
    resolved ??= shortcutForCode(state.language.languageCode);

    // ৫. কাস্টম `other` ম্যাপ (`bn_BD`, `bn`, `pt_BR`, ...):
    resolved ??= lookupOther(
      '${state.language.languageCode}_${state.country.isoCode}',
    );
    resolved ??= lookupOther(state.language.languageCode);

    // ৬. ফলব্যাক ভাষা (`en` বা সেট করা ফলব্যাক):
    if (resolved == null) {
      final fb = state.fallbackLanguage;
      resolved =
          byLanguage?[fb] ??
          byLanguage?[fb.baseLanguage] ??
          shortcutForCode(fb.languageCode) ??
          lookupOther(fb.tag) ??
          lookupOther(fb.languageCode);
    }

    // ৭. কোনোটিই না থাকলে দেওয়া fallback বা প্রথম প্রদত্ত টেক্সট:
    resolved ??=
        fallback ??
        en ??
        bn ??
        ar ??
        hi ??
        ur ??
        es ??
        fr ??
        de ??
        pt ??
        it ??
        ja ??
        ko ??
        zh ??
        trText ??
        id ??
        ms ??
        ru ??
        th ??
        vi ??
        ne ??
        ta ??
        fa ??
        he ??
        nl ??
        pl ??
        uk ??
        sv ??
        fil ??
        sw ??
        byLanguage?.values.firstOrNull ??
        byCountry?.values.firstOrNull ??
        other?.values.firstOrNull ??
        textKey ??
        '';

    if (args != null && args.isNotEmpty) {
      for (final entry in args.entries) {
        resolved = resolved!.replaceAll(
          '{${entry.key}}',
          '${entry.value ?? ''}',
        );
      }
    }

    final shouldLocalizeDigits = localizeDigits ?? state.useLocaleDigits;
    if (shouldLocalizeDigits && resolved!.isNotEmpty) {
      resolved = formatDigits(resolved, language: state.language);
    }

    return resolved!;
  }

  /// প্রদত্ত [state] অনুযায়ী অনূদিত স্ট্রিং রিটার্ন করে।
  String resolve(OmniLocaleState state, {Map<String, Object?>? argsOverride}) =>
      resolveTextFor(
        state,
        textKey: textKey,
        en: en,
        bn: bn,
        ar: ar,
        hi: hi,
        ur: ur,
        es: es,
        fr: fr,
        de: de,
        pt: pt,
        it: it,
        ja: ja,
        ko: ko,
        zh: zh,
        trText: trText,
        id: id,
        ms: ms,
        ru: ru,
        th: th,
        vi: vi,
        ne: ne,
        ta: ta,
        fa: fa,
        he: he,
        nl: nl,
        pl: pl,
        uk: uk,
        sv: sv,
        fil: fil,
        sw: sw,
        byLanguage: byLanguage,
        byCountry: byCountry,
        other: other,
        fallback: fallback,
        args: argsOverride ?? args,
        localizeDigits: localizeDigits,
      );

  /// উইজেট বিল্ড-এ বর্তমান ভাষা অনুযায়ী স্ট্রিং নেয় ও স্কোপে সাবস্ক্রাইব করে।
  String tr(BuildContext context, {Map<String, Object?>? args}) =>
      resolve(OmniL10nScope.watch(context), argsOverride: args);

  /// `BuildContext` ছাড়াই (Bloc, Guard, Validator-এ) বর্তমান ভাষার স্ট্রিং রিটার্ন করে।
  String get value => resolve(_channel.value);

  @override
  Widget build(BuildContext context) {
    final scope = OmniL10nScope.maybeOf(context);
    if (scope != null && scope.notifier != null) {
      final state = scope.notifier!.value;
      return Text(
        resolve(state),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      );
    }
    // OmniApp ছাড়া সাধারণ MaterialApp-এও যেন OmniText অটো আপডেট হয়:
    return ListenableBuilder(
      listenable: _channel,
      builder: (_, _) => Text(
        resolve(_channel.value),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection ?? _channel.value.textDirection,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// একাধিক ভাষার বড় অ্যাপে আলাদা ফাইলে পরিচ্ছন্নভাবে অনুবাদ সাজানোর অতি সহজ বেস ক্লাস।
///
/// কোনো `abstract` ইন্টারফেস বা প্রতিটি ভাষার আলাদা ক্লাস বানাতে হয় না — শুধু
/// একটি সাধারণ ক্লাস লিখুন, পাশেই সব ভাষা পরিষ্কার থাকবে:
/// ```dart
/// class AppLang extends OmniLang {
///   const AppLang([super.context]);
///   String get title => pick(en: 'OmniStore', bn: 'অমনি-স্টোর', ar: 'أومني ستور');
///   String hello(String name) => pick(en: 'Hello, $name!', bn: 'হ্যালো, $name!');
/// }
/// ```
abstract class OmniLang {
  /// ঐচ্ছিক [context] সহ ল্যাংগুয়েজ টেবিল তৈরি করে (`context` না দিলে গ্লোবাল স্টেট)।
  const OmniLang([this.context]);

  /// উইজেট সাবস্ক্রিপশনের কনটেক্সট।
  final BuildContext? context;

  /// বর্তমান কার্যকর লোকেল স্টেট।
  @protected
  OmniLocaleState get localeState =>
      context != null ? OmniL10nScope.watch(context!) : OmniText.state;

  /// বর্তমান ভাষা ও কান্ট্রি কোড অনুযায়ী অনুবাদ নির্বাচন করে।
  @protected
  String pick({
    String? key,
    String? en,
    String? bn,
    String? ar,
    String? hi,
    String? ur,
    String? es,
    String? fr,
    String? de,
    String? pt,
    String? it,
    String? ja,
    String? ko,
    String? zh,
    String? tr,
    String? id,
    String? ms,
    String? ru,
    String? th,
    String? vi,
    String? ne,
    String? ta,
    String? fa,
    String? he,
    String? nl,
    String? pl,
    String? uk,
    String? sv,
    String? fil,
    String? sw,
    Map<OmniLanguage, String>? byLanguage,
    Map<OmniCountryCode, String>? byCountry,
    Map<String, String>? other,
    String? fallback,
    Map<String, Object?>? args,
    bool? localizeDigits,
  }) => OmniText.resolveTextFor(
    localeState,
    textKey: key,
    en: en,
    bn: bn,
    ar: ar,
    hi: hi,
    ur: ur,
    es: es,
    fr: fr,
    de: de,
    pt: pt,
    it: it,
    ja: ja,
    ko: ko,
    zh: zh,
    trText: tr,
    id: id,
    ms: ms,
    ru: ru,
    th: th,
    vi: vi,
    ne: ne,
    ta: ta,
    fa: fa,
    he: he,
    nl: nl,
    pl: pl,
    uk: uk,
    sv: sv,
    fil: fil,
    sw: sw,
    byLanguage: byLanguage,
    byCountry: byCountry,
    other: other,
    fallback: fallback,
    args: args,
    localizeDigits: localizeDigits,
  );
}

/// যেকোনো `BuildContext` থেকেই ১ লাইনে অনুবাদ ও ভাষা/দেশ নিয়ন্ত্রণের শর্টকাট।
extension OmniTextContext on BuildContext {
  /// বর্তমান সক্রিয় ভাষা ([OmniLanguage]) — পরিবর্তন হলে উইজেট অটো রি-বিল্ড হবে।
  OmniLanguage get currentLanguage => OmniL10nScope.watch(this).language;

  /// বর্তমান সক্রিয় দেশ ([OmniCountryCode])।
  OmniCountryCode get currentCountry => OmniL10nScope.watch(this).country;

  /// বর্তমান Flutter [Locale]।
  Locale get currentLocale => OmniL10nScope.watch(this).effectiveLocale;

  /// বর্তমান ভাষা RTL (যেমন আরবি/উর্দু/ফার্সি) কি না।
  bool get isRtl => OmniL10nScope.watch(this).isRtl;

  /// কোনো এক্সট্রা ফাইল ছাড়াই সরাসরি স্ক্রিনেই বহুভাষিক টেক্সট রিটার্ন করে
  /// (ভাষা বা দেশ বদলালেই পুরো স্ক্রিনে অটো আপডেট হয়)।
  String l10n({
    String? key,
    String? en,
    String? bn,
    String? ar,
    String? hi,
    String? ur,
    String? es,
    String? fr,
    String? de,
    String? pt,
    String? it,
    String? ja,
    String? ko,
    String? zh,
    String? tr,
    String? id,
    String? ms,
    String? ru,
    String? th,
    String? vi,
    String? ne,
    String? ta,
    String? fa,
    String? he,
    String? nl,
    String? pl,
    String? uk,
    String? sv,
    String? fil,
    String? sw,
    Map<OmniLanguage, String>? byLanguage,
    Map<OmniCountryCode, String>? byCountry,
    Map<String, String>? other,
    String? fallback,
    Map<String, Object?>? args,
    bool? localizeDigits,
  }) => OmniText.resolveTextFor(
    OmniL10nScope.watch(this),
    textKey: key,
    en: en,
    bn: bn,
    ar: ar,
    hi: hi,
    ur: ur,
    es: es,
    fr: fr,
    de: de,
    pt: pt,
    it: it,
    ja: ja,
    ko: ko,
    zh: zh,
    trText: tr,
    id: id,
    ms: ms,
    ru: ru,
    th: th,
    vi: vi,
    ne: ne,
    ta: ta,
    fa: fa,
    he: he,
    nl: nl,
    pl: pl,
    uk: uk,
    sv: sv,
    fil: fil,
    sw: sw,
    byLanguage: byLanguage,
    byCountry: byCountry,
    other: other,
    fallback: fallback,
    args: args,
    localizeDigits: localizeDigits,
  );

  /// আগে তৈরি করা [OmniText] কনস্ট্যান্টকে বর্তমান ভাষায় রি-অ্যাকটিভভাবে রিজলভ করে।
  String tr(OmniText value, {Map<String, Object?>? args}) =>
      value.tr(this, args: args);

  /// সক্রিয় ভাষার সংখ্যা রূপে টেক্সট (`০-৯`, `٠-٩`) ফরম্যাট করে।
  String trDigits(String raw) =>
      OmniText.formatDigits(raw, language: currentLanguage);

  OmniLocaleController? get _scopedController =>
      OmniL10nScope.maybeOf(this)?.controller;

  /// ১ লাইনে পুরো অ্যাপের ভাষা পরিবর্তন করে (কোনো রিলোড ছাড়াই সব স্ক্রিন আপডেট!)।
  void setLanguage(OmniLanguage language, {OmniCountryCode? country}) {
    final c = _scopedController;
    if (c != null) {
      c.setLanguage(language, country: country);
    } else {
      OmniText.setLanguage(language, country: country);
    }
  }

  /// ১ লাইনে টাইপ-সেইফ [OmniCountryCode] দিয়ে দেশ ও ভাষা পরিবর্তন করে।
  void setCountry(OmniCountryCode country, {OmniLanguage? language}) {
    final c = _scopedController;
    if (c != null) {
      c.setCountry(country, language: language);
    } else {
      OmniText.setCountry(country, language: language);
    }
  }

  /// Flutter [Locale] অনুযায়ী ভাষা পরিবর্তন করে।
  void setLocale(Locale locale) {
    final c = _scopedController;
    if (c != null) {
      c.setLocale(locale);
    } else {
      OmniText.setLocale(locale);
    }
  }

  /// পরবর্তী সমর্থিত ভাষায় চলে যায়।
  void nextLanguage({List<OmniLanguage>? among}) {
    final list =
        among ?? OmniL10nScope.maybeOf(this)?.config.supportedLanguages;
    final c = _scopedController;
    if (c != null) {
      final choices = (list != null && list.isNotEmpty)
          ? list
          : OmniText.supportedLanguages;
      final cur = c.value.language;
      final idx = choices.indexWhere(
        (l) => l == cur || l.languageCode == cur.languageCode,
      );
      final next = idx < 0
          ? choices.first
          : choices[(idx + 1) % choices.length];
      c.setLanguage(next);
    } else {
      OmniText.nextLanguage(among: list);
    }
  }

  /// ডিভাইসের সিস্টেম ভাষা ফলো চালু করে।
  void useSystemLanguage() {
    final c = _scopedController;
    if (c != null) {
      c.useSystem();
    } else {
      OmniText.useSystem();
    }
  }

  /// রেডিমেড ভাষা ও দেশ বাছাইয়ের বটম শিট খোলে।
  Future<void> openLanguageSettings({
    List<OmniLanguage>? languages,
    bool showDigitsToggle = true,
  }) => showOmniLanguageSheet(
    this,
    languages: languages,
    showDigitsToggle: showDigitsToggle,
  );
}

// =============================================================================
// রেডিমেড UI ভাষা ও কান্ট্রি পিকার উইজেটসমূহ
// =============================================================================

/// [OmniLanguagePicker]-এর লেআউট ধরন।
enum OmniLanguagePickerLayout {
  /// ক্লিকেবল চিপস (ডিফল্ট)।
  chips,

  /// কমপ্যাক্ট কার্ড।
  cards,

  /// ড্রপডাউন মেনু।
  dropdown,
}

/// পুরো অ্যাপের ভাষা ও দেশ বাছাইয়ের রেডিমেড UI পিকার।
class OmniLanguagePicker extends StatelessWidget {
  /// [languages] বা অ্যাপের ডিফল্ট তালিকা থেকে ভাষা পিকার তৈরি করে।
  const OmniLanguagePicker({
    super.key,
    this.languages,
    this.layout = OmniLanguagePickerLayout.chips,
    this.showFlags = true,
    this.showCountryCode = true,
    this.showEnglishName = false,
    this.showSystemOption = true,
    this.onChanged,
  });

  /// প্রদর্শনের জন্য ভাষা তালিকা (`null` হলে অ্যাপ বা [OmniLanguage.popular])।
  final List<OmniLanguage>? languages;

  /// UI লেআউট স্টাইল।
  final OmniLanguagePickerLayout layout;

  /// দেশের পতাকা দেখাবে কি না।
  final bool showFlags;

  /// কান্ট্রি কোড (`BD`, `US`, `SA`) দেখাবে কি না।
  final bool showCountryCode;

  /// স্থানীয় নামের পাশে ইংরেজি নাম দেখাবে কি না।
  final bool showEnglishName;

  /// `System` (অটো ডিভাইস ভাষা) চিপ দেখাবে কি না।
  final bool showSystemOption;

  /// ভাষা পরিবর্তনে অতিরিক্ত কলব্যাক।
  final ValueChanged<OmniLanguage>? onChanged;

  List<OmniLanguage> _items(BuildContext context) {
    if (languages != null && languages!.isNotEmpty) return languages!;
    final scoped = OmniL10nScope.maybeOf(context)?.config.supportedLanguages;
    if (scoped != null && scoped.isNotEmpty) return scoped;
    return OmniText.supportedLanguages;
  }

  String _labelFor(OmniLanguage l) {
    final prefix = showFlags ? '${l.flag} ' : '';
    final cc = showCountryCode ? ' (${l.countryCode})' : '';
    final enSuffix = showEnglishName && l.nativeName != l.englishName
        ? ' • ${l.englishName}'
        : '';
    return '$prefix${l.nativeName}$cc$enSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final state = OmniL10nScope.watch(context);
    final list = _items(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (layout == OmniLanguagePickerLayout.dropdown) {
      final active = list.contains(state.language)
          ? state.language
          : list.firstWhere(
              (e) => e.languageCode == state.language.languageCode,
              orElse: () => list.first,
            );
      return DropdownButtonFormField<OmniLanguage>(
        initialValue: active,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final l in list)
            DropdownMenuItem(value: l, child: Text(_labelFor(l))),
        ],
        onChanged: (v) {
          if (v != null) {
            context.setLanguage(v);
            onChanged?.call(v);
          }
        },
      );
    }

    if (layout == OmniLanguagePickerLayout.cards) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in list)
            Builder(
              builder: (_) {
                final selected =
                    !state.followSystem &&
                    (state.language == l ||
                        (state.language.languageCode == l.languageCode &&
                            state.country == l.country));
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.setLanguage(l);
                    onChanged?.call(l);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? cs.primary
                            : theme.dividerColor.withValues(alpha: 0.4),
                        width: selected ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showFlags) ...[
                          Text(l.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.nativeName,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? cs.onPrimaryContainer : null,
                              ),
                            ),
                            if (showCountryCode || showEnglishName)
                              Text(
                                '${l.countryCode} • ${l.englishName}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: selected
                                      ? cs.onPrimaryContainer.withValues(
                                          alpha: 0.8,
                                        )
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showSystemOption)
          ChoiceChip(
            label: Text(
              context.l10n(
                en: 'System',
                bn: 'সিস্টেম',
                ar: 'النظام',
                hi: 'सिस्टम',
              ),
            ),
            selected: state.followSystem,
            onSelected: (_) => context.useSystemLanguage(),
          ),
        for (final l in list)
          ChoiceChip(
            label: Text(_labelFor(l)),
            selected:
                !state.followSystem &&
                (state.language == l ||
                    (state.language.languageCode == l.languageCode &&
                        state.country == l.country)),
            onSelected: (_) {
              context.setLanguage(l);
              onChanged?.call(l);
            },
          ),
      ],
    );
  }
}

/// হেডার বা AppBar-এ ব্যবহারের জন্য ১-ট্যাপ কমপ্যাক্ট ভাষা বাটন (`🇧🇩 বাংলা`)।
class OmniLanguageButton extends StatelessWidget {
  /// ট্যাপ করলে পরবর্তী ভাষায় সুইচ করে অথবা [openSheetOnTap] হলে বটম শিট খোলে।
  const OmniLanguageButton({
    super.key,
    this.languages,
    this.openSheetOnTap = true,
    this.showFlag = true,
    this.showCodeOnly = false,
  });

  /// বাটনে প্রদর্শিত ভাষা তালিকা।
  final List<OmniLanguage>? languages;

  /// ট্যাপে ভাষা বাছাই শিট খুলবে (`true`) নাকি সরাসরি পরের ভাষায় যাবে (`false`)।
  final bool openSheetOnTap;

  /// পতাকা ইমোজি দেখাবে কি না।
  final bool showFlag;

  /// পুরো নামের বদলে ছোট কোড (`BN`, `EN`) দেখাবে কি না।
  final bool showCodeOnly;

  @override
  Widget build(BuildContext context) {
    final lang = context.currentLanguage;
    final label = showCodeOnly ? lang.shortCode : lang.nativeName;
    return TextButton.icon(
      onPressed: () {
        if (openSheetOnTap) {
          context.openLanguageSettings(languages: languages);
        } else {
          context.nextLanguage(among: languages);
        }
      },
      icon: Text(showFlag ? lang.flag : '🌐'),
      label: Text(label),
    );
  }
}

/// Settings স্ক্রিনে সরাসরি বসানোর জন্য রেডিমেড ভাষা ও কান্ট্রি টাইল।
class OmniLanguageTile extends StatelessWidget {
  /// ট্যাপ করলে ভাষা বাছাইয়ের বটম শিট খোলে।
  const OmniLanguageTile({
    super.key,
    this.title,
    this.languages,
    this.showDigitsToggle = true,
  });

  /// কাস্টম টাইটেল (না দিলে অটো বাংলা/ইংরেজি)।
  final String? title;

  /// অনুমোদিত ভাষার তালিকা।
  final List<OmniLanguage>? languages;

  /// শিটের ভেতরে স্থানীয় অঙ্ক সুইচ দেখাবে কি না।
  final bool showDigitsToggle;

  @override
  Widget build(BuildContext context) {
    final state = OmniL10nScope.watch(context);
    final lang = state.language;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(lang.flag, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(
        title ??
            context.l10n(
              en: 'App Language & Region',
              bn: 'অ্যাপের ভাষা ও দেশ',
              ar: 'لغة التطبيق والمنطقة',
              hi: 'ऐप की भाषा और क्षेत्र',
            ),
      ),
      subtitle: Text(
        '${lang.nativeName} (${state.country.isoCode})'
        '${state.followSystem ? ' • Auto' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showOmniLanguageSheet(
        context,
        languages: languages,
        showDigitsToggle: showDigitsToggle,
      ),
    );
  }
}

/// ১ লাইনে সুন্দর ভাষা, কান্ট্রি কোড ও লোকাল ডিজিট বাছাই শিট খোলে।
Future<void> showOmniLanguageSheet(
  BuildContext context, {
  List<OmniLanguage>? languages,
  bool showDigitsToggle = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetCtx.l10n(
                    en: 'Select Language & Country',
                    bn: 'ভাষা ও দেশ নির্বাচন করুন',
                    ar: 'اختر اللغة والبلد',
                    hi: 'भाषा और देश चुनें',
                  ),
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                OmniLanguagePicker(
                  languages: languages,
                  layout: OmniLanguagePickerLayout.cards,
                  showCountryCode: true,
                  showEnglishName: true,
                  onChanged: (_) => Navigator.of(sheetCtx).maybePop(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.settings_suggest_rounded,
                        size: 18,
                      ),
                      label: Text(
                        sheetCtx.l10n(
                          en: 'Use Device Language',
                          bn: 'ফোনের সিস্টেম ভাষা',
                          ar: 'لغة الجهاز',
                          hi: 'डिवाइस की भाषा',
                        ),
                      ),
                      onPressed: () {
                        sheetCtx.useSystemLanguage();
                        Navigator.of(sheetCtx).maybePop();
                      },
                    ),
                  ],
                ),
                if (showDigitsToggle) ...[
                  const Divider(height: 20),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: OmniL10nScope.watch(sheetCtx).useLocaleDigits,
                    title: Text(
                      sheetCtx.l10n(
                        en: 'Localized Numerals',
                        bn: 'বাংলা সংখ্যা ব্যবহার করুন (০১২৩)',
                        ar: 'الأرقام المحلية (٠١٢٣)',
                        hi: 'स्थानीय अंक उपयोग करें (०१२३)',
                      ),
                    ),
                    onChanged: (v) => OmniText.setUseLocaleDigits(v),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

// =============================================================================
// শূন্য-ওয়ার্নিং ফলব্যাক Material ও Cupertino ডেলিগেটসমূহ
// =============================================================================

/// `flutter_localizations` প্যাকেজ ছাড়াও যেকোনো [Locale] (`bn`, `ar`, `hi`, ...)
/// ব্যবহার করলে যেন MaterialApp কোনো ওয়ার্নিং বা ক্র্যাশ না দেয় তার নিরাপদ ডেলিগেট।
class OmniFallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  /// ডিফল্ট কন্সট্রাক্টর।
  const OmniFallbackMaterialLocalizationsDelegate();

  /// শেয়ার্ড ইনস্ট্যান্স।
  static const instance = OmniFallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(covariant OmniFallbackMaterialLocalizationsDelegate old) =>
      false;
}

class _OmniRtlWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _OmniRtlWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

/// `WidgetsLocalizations` ফলব্যাক ডেলিগেট — `ar`, `ur`, `fa`, `ps`, `he` হলে
/// কোনো এক্সট্রা প্যাকেজ ছাড়াই অটো RTL (`TextDirection.rtl`) প্রয়োগ করে।
class OmniFallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  /// ডিফল্ট কন্সট্রাক্টর।
  const OmniFallbackWidgetsLocalizationsDelegate();

  /// শেয়ার্ড ইনস্ট্যান্স।
  static const instance = OmniFallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    final isRtl = OmniLanguage.fromLocale(locale).isRtl;
    return SynchronousFuture<WidgetsLocalizations>(
      isRtl
          ? const _OmniRtlWidgetsLocalizations()
          : const DefaultWidgetsLocalizations(),
    );
  }

  @override
  bool shouldReload(covariant OmniFallbackWidgetsLocalizationsDelegate old) =>
      false;
}

/// `CupertinoApp`-এর যেকোনো [Locale]-এ নিরাপদ ফলব্যাক ডেলিগেট।
class OmniFallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  /// ডিফল্ট কন্সট্রাক্টর।
  const OmniFallbackCupertinoLocalizationsDelegate();

  /// শেয়ার্ড ইনস্ট্যান্স।
  static const instance = OmniFallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(covariant OmniFallbackCupertinoLocalizationsDelegate old) =>
      false;
}

final RegExp _localeTagSeparator = RegExp(r'[-_]');
