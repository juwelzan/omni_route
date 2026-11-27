import '../omni_localization.dart';

/// Translations of every built-in field label, hint and message, keyed by
/// the English text.
const Map<String, OmniText> omniFieldBuiltInTexts = <String, OmniText>{
  'Email': OmniText(
    en: 'Email',
    bn: 'ইমেইল',
    ar: 'البريد الإلكتروني',
    hi: 'ईमेल',
  ),
  'Gmail': OmniText(en: 'Gmail', bn: 'জিমেইল', ar: 'جيميل', hi: 'जीमेल'),
  'Password': OmniText(
    en: 'Password',
    bn: 'পাসওয়ার্ড',
    ar: 'كلمة المرور',
    hi: 'पासवर्ड',
  ),
  'New Password': OmniText(
    en: 'New Password',
    bn: 'নতুন পাসওয়ার্ড',
    ar: 'كلمة مرور جديدة',
    hi: 'नया पासवर्ड',
  ),
  'Confirm Password': OmniText(
    en: 'Confirm Password',
    bn: 'পাসওয়ার্ড নিশ্চিত করুন',
    ar: 'تأكيد كلمة المرور',
    hi: 'पासवर्ड की पुष्टि करें',
  ),
  'Full Name': OmniText(
    en: 'Full Name',
    bn: 'পূর্ণ নাম',
    ar: 'الاسم الكامل',
    hi: 'पूरा नाम',
  ),
  'First Name': OmniText(
    en: 'First Name',
    bn: 'নামের প্রথম অংশ',
    ar: 'الاسم الأول',
    hi: 'पहला नाम',
  ),
  'Last Name': OmniText(
    en: 'Last Name',
    bn: 'নামের শেষ অংশ',
    ar: 'اسم العائلة',
    hi: 'अंतिम नाम',
  ),
  'Username': OmniText(
    en: 'Username',
    bn: 'ইউজারনেম',
    ar: 'اسم المستخدم',
    hi: 'यूज़रनेम',
  ),
  'Mobile Number': OmniText(
    en: 'Mobile Number',
    bn: 'মোবাইল নাম্বার',
    ar: 'رقم الجوال',
    hi: 'मोबाइल नंबर',
  ),
  'Phone Number': OmniText(
    en: 'Phone Number',
    bn: 'ফোন নাম্বার',
    ar: 'رقم الهاتف',
    hi: 'फ़ोन नंबर',
  ),
  'Number': OmniText(en: 'Number', bn: 'সংখ্যা', ar: 'رقم', hi: 'संख्या'),
  'Quantity': OmniText(
    en: 'Quantity',
    bn: 'পরিমাণ',
    ar: 'الكمية',
    hi: 'मात्रा',
  ),
  'Decimal Value': OmniText(
    en: 'Decimal Value',
    bn: 'দশমিক মান',
    ar: 'قيمة عشرية',
    hi: 'दशमलव मान',
  ),
  'Amount': OmniText(
    en: 'Amount',
    bn: 'টাকার পরিমাণ',
    ar: 'المبلغ',
    hi: 'राशि',
  ),
  'Verification Code': OmniText(
    en: 'Verification Code',
    bn: 'ভেরিফিকেশন কোড',
    ar: 'رمز التحقق',
    hi: 'सत्यापन कोड',
  ),
  'Search': OmniText(en: 'Search', bn: 'খুঁজুন', ar: 'بحث', hi: 'खोजें'),
  'Notes': OmniText(en: 'Notes', bn: 'নোটস', ar: 'ملاحظات', hi: 'नोट्स'),
  'Website URL': OmniText(
    en: 'Website URL',
    bn: 'ওয়েবসাইট লিংক',
    ar: 'رابط الموقع',
    hi: 'वेबसाइट लिंक',
  ),
  'Text': OmniText(en: 'Text', bn: 'টেক্সট', ar: 'نص', hi: 'टेक्स्ट'),
  'Enter password': OmniText(
    en: 'Enter password',
    bn: 'পাসওয়ার্ড দিন',
    ar: 'أدخل كلمة المرور',
    hi: 'पासवर्ड दर्ज करें',
  ),
  'Create a strong password': OmniText(
    en: 'Create a strong password',
    bn: 'শক্তিশালী পাসওয়ার্ড তৈরি করুন',
    ar: 'أنشئ كلمة مرور قوية',
    hi: 'मजबूत पासवर्ड बनाएं',
  ),
  'Re-enter password': OmniText(
    en: 'Re-enter password',
    bn: 'পুনরায় পাসওয়ার্ড দিন',
    ar: 'أعد إدخال كلمة المرور',
    hi: 'पासवर्ड दोबारा दर्ज करें',
  ),
  'Enter your name': OmniText(
    en: 'Enter your name',
    bn: 'আপনার নাম লিখুন',
    ar: 'أدخل اسمك',
    hi: 'अपना नाम दर्ज करें',
  ),
  'Enter text': OmniText(
    en: 'Enter text',
    bn: 'টেক্সট লিখুন',
    ar: 'أدخل النص',
    hi: 'टेक्स्ट दर्ज करें',
  ),
  'Search...': OmniText(
    en: 'Search...',
    bn: 'খুঁজুন...',
    ar: 'ابحث...',
    hi: 'खोजें...',
  ),
  'Write here...': OmniText(
    en: 'Write here...',
    bn: 'এখানে লিখুন...',
    ar: 'اكتب هنا...',
    hi: 'यहाँ लिखें...',
  ),
  'Verify': OmniText(
    en: 'Verify',
    bn: 'যাচাই করুন',
    ar: 'تحقق',
    hi: 'सत्यापित करें',
  ),
  'Verified': OmniText(
    en: 'Verified',
    bn: 'যাচাইকৃত',
    ar: 'تم التحقق',
    hi: 'सत्यापित',
  ),
  'OTP Verified': OmniText(
    en: 'OTP Verified',
    bn: 'OTP যাচাই সম্পন্ন',
    ar: 'تم التحقق من الرمز',
    hi: 'OTP सत्यापित',
  ),
  'Verifying...': OmniText(
    en: 'Verifying...',
    bn: 'যাচাই হচ্ছে...',
    ar: 'جاري التحقق...',
    hi: 'सत्यापन हो रहा है...',
  ),
  'Resend Code': OmniText(
    en: 'Resend Code',
    bn: 'পুনরায় কোড পাঠান',
    ar: 'إعادة إرسال الرمز',
    hi: 'कोड पुनः भेजें',
  ),
  'Select Country Code': OmniText(
    en: 'Select Country Code',
    bn: 'দেশের কোড বাছাই করুন',
    ar: 'اختر رمز الدولة',
    hi: 'देश कोड चुनें',
  ),
  'Weak': OmniText(en: 'Weak', bn: 'দুর্বল', ar: 'ضعيف', hi: 'कमज़ोर'),
  'Fair': OmniText(en: 'Fair', bn: 'মোটামুটি', ar: 'مقبول', hi: 'ठीक'),
  'Good': OmniText(en: 'Good', bn: 'ভালো', ar: 'جيد', hi: 'अच्छा'),
  'Strong': OmniText(en: 'Strong', bn: 'শক্তিশালী', ar: 'قوي', hi: 'मज़बूत'),
  'This field is required': OmniText(
    en: 'This field is required',
    bn: 'এই ঘরটি পূরণ করা আবশ্যক',
    ar: 'هذا الحقل مطلوب',
    hi: 'यह फ़ील्ड आवश्यक है',
  ),
  'Please enter an email address': OmniText(
    en: 'Please enter an email address',
    bn: 'অনুগ্রহ করে ইমেইল ঠিকানা দিন',
    ar: 'الرجاء إدخال البريد الإلكتروني',
    hi: 'कृपया ईमेल पता दर्ज करें',
  ),
  'Please enter a valid email address': OmniText(
    en: 'Please enter a valid email address',
    bn: 'সঠিক ইমেইল ঠিকানা দিন',
    ar: 'الرجاء إدخال بريد إلكتروني صحيح',
    hi: 'कृपया सही ईमेल पता दर्ज करें',
  ),
  'Please enter a valid Gmail address (@gmail.com)': OmniText(
    en: 'Please enter a valid Gmail address (@gmail.com)',
    bn: 'সঠিক জিমেইল ঠিকানা (@gmail.com) দিন',
    ar: 'الرجاء إدخال عنوان Gmail صحيح',
    hi: 'कृपया सही Gmail पता (@gmail.com) दर्ज करें',
  ),
  'Please enter your Gmail address': OmniText(
    en: 'Please enter your Gmail address',
    bn: 'আপনার জিমেইল ঠিকানা দিন',
    ar: 'الرجاء إدخال بريدك على Gmail',
    hi: 'कृपया अपना Gmail पता दर्ज करें',
  ),
  'Please enter a valid @gmail.com address': OmniText(
    en: 'Please enter a valid @gmail.com address',
    bn: 'সঠিক @gmail.com ঠিকানা দিন',
    ar: 'الرجاء إدخال عنوان @gmail.com صحيح',
    hi: 'कृपया सही @gmail.com पता दर्ज करें',
  ),
  'Please enter a password': OmniText(
    en: 'Please enter a password',
    bn: 'অনুগ্রহ করে পাসওয়ার্ড দিন',
    ar: 'الرجاء إدخال كلمة المرور',
    hi: 'कृपया पासवर्ड दर्ज करें',
  ),
  'Please confirm your password': OmniText(
    en: 'Please confirm your password',
    bn: 'পাসওয়ার্ডটি পুনরায় নিশ্চিত করুন',
    ar: 'يرجى تأكيد كلمة المرور',
    hi: 'कृपया पासवर्ड की पुष्टि करें',
  ),
  'Passwords do not match': OmniText(
    en: 'Passwords do not match',
    bn: 'পাসওয়ার্ড দুটি মেলেনি',
    ar: 'كلمتا المرور غير متطابقتين',
    hi: 'पासवर्ड मेल नहीं खाते',
  ),
  'Include at least 1 uppercase letter': OmniText(
    en: 'Include at least 1 uppercase letter',
    bn: 'কমপক্ষে ১টি বড় হাতের অক্ষর (A-Z) দিন',
    ar: 'أضف حرفاً كبيراً واحداً على الأقل',
    hi: 'कम से कम 1 बड़ा अक्षर शामिल करें',
  ),
  'Include at least 1 lowercase letter': OmniText(
    en: 'Include at least 1 lowercase letter',
    bn: 'কমপক্ষে ১টি ছোট হাতের অক্ষর (a-z) দিন',
    ar: 'أضف حرفاً صغيراً واحداً على الأقل',
    hi: 'कम से कम 1 छोटा अक्षर शामिल करें',
  ),
  'Include at least 1 number': OmniText(
    en: 'Include at least 1 number',
    bn: 'কমপক্ষে ১টি সংখ্যা (0-9) দিন',
    ar: 'أضف رقماً واحداً على الأقل',
    hi: 'कम से कम 1 संख्या शामिल करें',
  ),
  'Include at least 1 special character': OmniText(
    en: 'Include at least 1 special character',
    bn: 'কমপক্ষে ১টি বিশেষ চিহ্ন (!@#) দিন',
    ar: 'أضف رمزاً خاصاً واحداً على الأقل',
    hi: 'कम से कम 1 विशेष चिह्न शामिल करें',
  ),
  'Please enter a name': OmniText(
    en: 'Please enter a name',
    bn: 'অনুগ্রহ করে নাম লিখুন',
    ar: 'الرجاء إدخال الاسم',
    hi: 'कृपया नाम दर्ज करें',
  ),
  'Spaces are not allowed': OmniText(
    en: 'Spaces are not allowed',
    bn: 'স্পেস ব্যবহার করা যাবে না',
    ar: 'غير مسموح بالمسافات',
    hi: 'स्पेस की अनुमति नहीं है',
  ),
  'Numbers are not allowed in name': OmniText(
    en: 'Numbers are not allowed in name',
    bn: 'নামে কোনো সংখ্যা দেওয়া যাবে না',
    ar: 'الأرقام غير مسموح بها في الاسم',
    hi: 'नाम में संख्या की अनुमति नहीं है',
  ),
  'Please enter a phone number': OmniText(
    en: 'Please enter a phone number',
    bn: 'মোবাইল নাম্বার দিন',
    ar: 'الرجاء إدخال رقم الهاتف',
    hi: 'कृपया फ़ोन नंबर दर्ज करें',
  ),
  'Enter a valid Bangladesh number (e.g. 01712-345678)': OmniText(
    en: 'Enter a valid Bangladesh number (e.g. 01712-345678)',
    bn: 'সঠিক বাংলাদেশি নাম্বার দিন (যেমন ০১৭১২-৩৪৫৬৭৮)',
    ar: 'أدخل رقم بنغلاديش صحيحاً',
    hi: 'सही बांग्लादेश नंबर दर्ज करें',
  ),
  'Verification code must contain only digits': OmniText(
    en: 'Verification code must contain only digits',
    bn: 'কোডে শুধুমাত্র সংখ্যা (0-9) থাকতে হবে',
    ar: 'يجب أن يحتوي الرمز على أرقام فقط',
    hi: 'सत्यापन कोड में केवल अंक होने चाहिए',
  ),
  'Please enter a number': OmniText(
    en: 'Please enter a number',
    bn: 'একটি সংখ্যা দিন',
    ar: 'الرجاء إدخال رقم',
    hi: 'कृपया संख्या दर्ज करें',
  ),
  'Please enter a valid number': OmniText(
    en: 'Please enter a valid number',
    bn: 'সঠিক সংখ্যা দিন',
    ar: 'الرجاء إدخال رقم صحيح',
    hi: 'कृपया सही संख्या दर्ज करें',
  ),
  'Negative values are not allowed': OmniText(
    en: 'Negative values are not allowed',
    bn: 'ঋণাত্মক সংখ্যা নেওয়া যাবে না',
    ar: 'القيم السالبة غير مسموح بها',
    hi: 'ऋणात्मक मान अनुमत नहीं हैं',
  ),
  'Please enter a URL': OmniText(
    en: 'Please enter a URL',
    bn: 'ওয়েবসাইট লিংক দিন',
    ar: 'الرجاء إدخال الرابط',
    hi: 'कृपया URL दर्ज करें',
  ),
  'Please enter a valid URL (e.g. https://site.com)': OmniText(
    en: 'Please enter a valid URL (e.g. https://site.com)',
    bn: 'সঠিক URL লিংক দিন (যেমন https://site.com)',
    ar: 'الرجاء إدخال رابط صحيح',
    hi: 'कृपया सही URL दर्ज करें',
  ),
};

/// Translates a built-in English [raw] string for the current (or given)
/// language; unknown strings only get locale digits when enabled.
String trField(String raw, [OmniLocaleState? state]) {
  final effectiveState = state ?? OmniText.state;
  if (effectiveState.language.languageCode == 'en' &&
      !effectiveState.useLocaleDigits) {
    return raw;
  }
  final entry = omniFieldBuiltInTexts[raw];
  if (entry != null) return entry.resolve(effectiveState);
  return effectiveState.useLocaleDigits
      ? OmniText.formatDigits(raw, language: effectiveState.language)
      : raw;
}

/// Picks the text for the current language from inline translations.
String trDynamic({
  required String en,
  required String bn,
  String? ar,
  String? hi,
}) => OmniText.resolveTextFor(OmniText.state, en: en, bn: bn, ar: ar, hi: hi);
