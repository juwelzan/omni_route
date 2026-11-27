import 'field_patterns.dart';
import 'field_texts.dart';

/// প্রি-ডিফাইনড ফিল্ডগুলোর কমন স্ট্যান্ড-অ্যালোন ভ্যালিডেশন ও পার্সিং ইউটিলিটি।
abstract final class OmniValidators {
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static final RegExp _gmailDomainRegex = RegExp(
    r'@(gmail|googlemail)\.com$',
    caseSensitive: false,
  );

  static final RegExp _bdPhoneRegex = RegExp(r'^(?:\+?880|0)?(1[3-9]\d{8})$');
  static final RegExp _urlRegex = RegExp(
    r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(\/.*)?$',
    caseSensitive: false,
  );

  /// সাধারণ ইমেইল অথবা কেবল Gmail (`gmailOnly: true`) যাচাই করে।
  static String? email(
    String? value, {
    bool required = true,
    bool gmailOnly = false,
    List<String>? allowedDomains,
    String requiredMessage = 'Please enter an email address',
    String invalidEmailMessage = 'Please enter a valid email address',
    String invalidGmailMessage =
        'Please enter a valid Gmail address (@gmail.com)',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? trField(requiredMessage) : null;
    if (!_emailRegex.hasMatch(trimmed)) return trField(invalidEmailMessage);

    if (gmailOnly && !_gmailDomainRegex.hasMatch(trimmed)) {
      return trField(invalidGmailMessage);
    }
    if (allowedDomains != null && allowedDomains.isNotEmpty) {
      final atIdx = trimmed.lastIndexOf('@');
      final domain = atIdx >= 0
          ? trimmed.substring(atIdx + 1).toLowerCase()
          : '';
      final matched = allowedDomains.any(
        (d) => d.trim().toLowerCase().replaceFirst('@', '') == domain,
      );
      if (!matched) {
        final joined = allowedDomains.join(', ');
        return trDynamic(
          en: 'Allowed email domain: $joined',
          bn: 'অনুমোদিত ইমেইল ডোমেইন: $joined',
          ar: 'النطاقات المسموح بها: $joined',
          hi: 'अनुमत ईमेल डोमेन: $joined',
        );
      }
    }
    return null;
  }

  /// সাধারণ বা কেবল `@gmail.com` ঠিকানা যাচাইয়ের সংক্ষিপ্ত হেল্পার।
  static String? gmail(
    String? value, {
    bool required = true,
    String requiredMessage = 'Please enter your Gmail address',
    String invalidGmailMessage = 'Please enter a valid @gmail.com address',
  }) => email(
    value,
    required: required,
    gmailOnly: true,
    requiredMessage: requiredMessage,
    invalidEmailMessage: invalidGmailMessage,
    invalidGmailMessage: invalidGmailMessage,
  );

  /// পাসওয়ার্ডের দৈর্ঘ্য, ক্যারেক্টার নিয়ম ও স্ট্রেংথ যাচাই করে।
  static String? password(
    String? value, {
    bool required = true,
    int minLength = 6,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireDigit = false,
    bool requireSpecialChar = false,
    String requiredMessage = 'Please enter a password',
  }) {
    final raw = value ?? '';
    if (raw.isEmpty) return required ? trField(requiredMessage) : null;
    if (raw.length < minLength) {
      return trDynamic(
        en: 'Password must be at least $minLength characters',
        bn: 'পাসওয়ার্ড কমপক্ষে $minLength অক্ষরের হতে হবে',
        ar: 'يجب أن تتكون كلمة المرور من $minLength أحرف على الأقل',
        hi: 'पासवर्ड कम से कम $minLength अक्षरों का होना चाहिए',
      );
    }
    if (requireUppercase && !fieldReUpper.hasMatch(raw)) {
      return trField('Include at least 1 uppercase letter');
    }
    if (requireLowercase && !fieldReLower.hasMatch(raw)) {
      return trField('Include at least 1 lowercase letter');
    }
    if (requireDigit && !fieldReDigit.hasMatch(raw)) {
      return trField('Include at least 1 number');
    }
    if (requireSpecialChar && !fieldReSpecial.hasMatch(raw)) {
      return trField('Include at least 1 special character');
    }
    return null;
  }

  /// পাসওয়ার্ড স্ট্রেংথ (`0` দুর্বল থেকে `4` খুব শক্তিশালী) হিসাব করে।
  static int passwordStrengthScore(String password, {int minLength = 8}) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= minLength) score++;
    if (fieldReLower.hasMatch(password) && fieldReUpper.hasMatch(password)) {
      score++;
    }
    if (fieldReDigit.hasMatch(password)) score++;
    if (fieldReSpecial.hasMatch(password)) score++;
    return score.clamp(1, 4);
  }

  /// নাম বা ইউজারনেম যাচাই করে।
  static String? name(
    String? value, {
    bool required = true,
    int minLength = 2,
    int? maxLength,
    bool allowDigits = false,
    bool allowSpaces = true,
    String requiredMessage = 'Please enter a name',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? trField(requiredMessage) : null;
    if (!allowSpaces && trimmed.contains(' ')) {
      return trField('Spaces are not allowed');
    }
    if (trimmed.length < minLength) {
      return trDynamic(
        en: 'Must be at least $minLength characters',
        bn: 'কমপক্ষে $minLength অক্ষর হতে হবে',
        ar: 'يجب أن يكون $minLength أحرف على الأقل',
        hi: 'कम से कम $minLength अक्षर होने चाहिए',
      );
    }
    if (maxLength != null && trimmed.length > maxLength) {
      return trDynamic(
        en: 'Must be at most $maxLength characters',
        bn: 'সর্বোচ্চ $maxLength অক্ষর দেওয়া যাবে',
        ar: 'يجب ألا يتجاوز $maxLength حرفاً',
        hi: 'अधिकतम $maxLength अक्षर अनुमत हैं',
      );
    }
    if (!allowDigits && fieldReDigit.hasMatch(trimmed)) {
      return trField('Numbers are not allowed in name');
    }
    return null;
  }

  /// মোবাইল নাম্বার (বাংলাদেশ `+880` এবং আন্তর্জাতিক E.164 ফরম্যাটসহ) যাচাই করে।
  static String? phone(
    String? value, {
    String countryCode = '+880',
    String countryName = '',
    bool required = true,
    bool validateBangladeshOperators = true,
    int? minDigits,
    int? maxDigits,
    String requiredMessage = 'Please enter a phone number',
    String? invalidMessage,
  }) {
    final digitsOnly = (value ?? '').replaceAll(fieldReNonDigit, '');
    if (digitsOnly.isEmpty) return required ? trField(requiredMessage) : null;

    if (countryCode == '+880') {
      final cleanRaw = (value ?? '').replaceAll(fieldReNonDialChar, '');
      if (validateBangladeshOperators) {
        if (!_bdPhoneRegex.hasMatch(cleanRaw)) {
          return invalidMessage ??
              trField('Enter a valid Bangladesh number (e.g. 01712-345678)');
        }
      } else {
        final expected = digitsOnly.startsWith('0') ? 11 : 10;
        if (digitsOnly.length != expected) {
          return invalidMessage ??
              trDynamic(
                en: 'Enter $expected digits for Bangladesh (+880)',
                bn: 'বাংলাদেশের (+880) জন্য ঠিক $expectedটি ডিজিট দিন',
                ar: 'أدخل $expected أرقام لبنغلاديش (+880)',
                hi: 'बांग्लादेश (+880) के लिए $expected अंक दर्ज करें',
              );
        }
      }
      return null;
    }

    final effMin = minDigits ?? 7;
    final effMax = maxDigits ?? 15;
    if (digitsOnly.length < effMin || digitsOnly.length > effMax) {
      if (invalidMessage != null) return invalidMessage;
      final label = countryName.isNotEmpty ? '$countryName ' : '';
      return effMin == effMax
          ? trDynamic(
              en: 'Enter exact $effMin digits for $label($countryCode)',
              bn: '$label($countryCode)-এর জন্য ঠিক $effMinটি ডিজিট দিন',
              ar: 'أدخل $effMin أرقام بالضبط لـ $label($countryCode)',
              hi: '$label($countryCode) के लिए ठीक $effMin अंक दर्ज करें',
            )
          : trDynamic(
              en: 'Enter $effMin-$effMax digits for $label($countryCode)',
              bn: '$label($countryCode)-এর জন্য $effMin-$effMaxটি ডিজিট দিন',
              ar: 'أدخل $effMin-$effMax أرقام لـ $label($countryCode)',
              hi: '$label($countryCode) के लिए $effMin-$effMax अंक दर्ज करें',
            );
    }
    return null;
  }

  /// কান্ট্রি কোডসহ E.164 ফরম্যাট (`+8801712345678`) তৈরি করে।
  static String normalizePhone(String rawInput, {String countryCode = '+880'}) {
    final digits = rawInput.replaceAll(fieldReNonDigit, '');
    if (digits.isEmpty) return '';
    if (countryCode == '+880') {
      final m = _bdPhoneRegex.firstMatch(digits);
      if (m != null) return '+880${m.group(1)}';
      if (digits.startsWith('880')) return '+$digits';
      if (digits.startsWith('0')) return '+880${digits.substring(1)}';
      return '+880$digits';
    }
    return '$countryCode$digits';
  }

  /// ওটিপি কোডের দৈর্ঘ্য যাচাই করে।
  static String? otp(
    String? value, {
    int length = 6,
    bool digitsOnly = true,
    String? incompleteMessage,
  }) {
    final clean = (value ?? '').trim();
    if (clean.length < length) {
      return incompleteMessage ??
          trDynamic(
            en: 'Enter the $length-digit verification code',
            bn: '$length-ডিজিটের ভেরিফিকেশন কোড দিন',
            ar: 'أدخل رمز التحقق المكون من $length أرقام',
            hi: '$length-अंकों का सत्यापन कोड दर्ज करें',
          );
    }
    if (digitsOnly && !fieldReAllDigits.hasMatch(clean)) {
      return trField('Verification code must contain only digits');
    }
    return null;
  }

  /// সংখ্যা ও `min` / `max` সীমা যাচাই করে।
  static String? number(
    String? value, {
    bool required = true,
    bool allowDecimal = false,
    bool allowNegative = false,
    num? min,
    num? max,
    String requiredMessage = 'Please enter a number',
    String invalidMessage = 'Please enter a valid number',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? trField(requiredMessage) : null;
    final parsed = allowDecimal
        ? double.tryParse(trimmed)
        : int.tryParse(trimmed);
    if (parsed == null) return trField(invalidMessage);
    if (!allowNegative && parsed < 0) {
      return trField('Negative values are not allowed');
    }
    if (min != null && parsed < min) {
      return trDynamic(
        en: 'Minimum value is $min',
        bn: 'সর্বনিম্ন মান হলো $min',
        ar: 'الحد الأدنى للقيمة هو $min',
        hi: 'न्यूनतम मान $min है',
      );
    }
    if (max != null && parsed > max) {
      return trDynamic(
        en: 'Maximum value is $max',
        bn: 'সর্বোচ্চ মান হলো $max',
        ar: 'الحد الأقصى للقيمة هو $max',
        hi: 'अधिकतम मान $max है',
      );
    }
    return null;
  }

  /// ওয়েবসাইট URL ফরম্যাট যাচাই করে।
  static String? url(
    String? value, {
    bool required = true,
    String requiredMessage = 'Please enter a URL',
    String invalidMessage = 'Please enter a valid URL (e.g. https://site.com)',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? trField(requiredMessage) : null;
    if (!_urlRegex.hasMatch(trimmed)) return trField(invalidMessage);
    return null;
  }
}
