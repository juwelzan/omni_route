import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class _TestAuthLang extends OmniLang {
  const _TestAuthLang([super.context]);

  String get signIn => pick(
    en: 'Sign In',
    bn: 'সাইন ইন',
    ar: 'تسجيل الدخول',
    hi: 'साइन इन',
    byLanguage: const {OmniLanguage.ja: 'サインイン'},
    byCountry: const {OmniCountryCode.gb: 'Log On'},
  );

  String greet(String name) =>
      pick(en: 'Hello, $name!', bn: 'হ্যালো, $name!', ar: 'مرحباً يا $name!');
}

void main() {
  group('OmniText & type-safe OmniLanguage / OmniCountryCode localization', () {
    setUp(() {
      OmniText.reset(clearRegistered: true);
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    tearDown(() {
      OmniText.reset(clearRegistered: true);
    });

    test(
      'OmniCountryCode & OmniLanguage enums resolve metadata, defaults & RTL accurately',
      () {
        expect(OmniCountryCode.bd.isoCode, 'BD');
        expect(OmniCountryCode.bd.dialCode, '+880');
        expect(OmniCountryCode.bd.defaultLanguage, OmniLanguage.bn);
        expect(OmniCountryCode.tryFromCode('us'), OmniCountryCode.us);
        expect(OmniCountryCode.tryFromDialCode('+966'), OmniCountryCode.sa);

        expect(OmniLanguage.bn.languageCode, 'bn');
        expect(OmniLanguage.bn.country, OmniCountryCode.bd);
        expect(OmniLanguage.ar.isRtl, isTrue);
        expect(OmniLanguage.ur.isRtl, isTrue);
        expect(OmniLanguage.bn.isRtl, isFalse);
        expect(
          OmniLanguage.fromLocale(const Locale('pt', 'BR')),
          OmniLanguage.ptBR,
        );
        expect(OmniLanguage.tryParse('bn_BD'), OmniLanguage.bn);
        expect(OmniLanguage.tryParse('en_GB'), OmniLanguage.enGB);
      },
    );

    test(
      'OmniText resolves inline, enum maps, country overrides, fallback & digits cleanly',
      () {
        const label = OmniText(
          en: 'Color',
          bn: 'রঙ',
          ar: 'لون',
          hi: 'रंग',
          byLanguage: {OmniLanguage.ja: '色'},
          byCountry: {OmniCountryCode.gb: 'Colour'},
        );

        expect(label.value, 'Color');
        OmniText.setLanguage(OmniLanguage.bn);
        expect(label.value, 'রঙ');

        OmniText.setCountry(OmniCountryCode.gb);
        expect(label.value, 'Colour');

        OmniText.change(OmniLanguage.ja);
        expect(label.value, '色');

        // Untranslated language falls back cleanly to English default:
        OmniText.setLanguage(OmniLanguage.sw);
        expect(label.value, 'Color');

        // Localized digit formatting:
        expect(
          OmniText.formatDigits('01712-345678', language: OmniLanguage.bn),
          '০১৭১২-৩৪৫৬৭৮',
        );
        expect(
          OmniText.formatDigits('1234', language: OmniLanguage.ar),
          '١٢٣٤',
        );
      },
    );

    test(
      'OmniValidators automatically localize validation messages with active language',
      () {
        expect(OmniValidators.email(''), 'Please enter an email address');
        OmniText.setLanguage(OmniLanguage.bn);
        expect(OmniValidators.email(''), 'অনুগ্রহ করে ইমেইল ঠিকানা দিন');
        expect(
          OmniValidators.otp('12', length: 6),
          '6-ডিজিটের ভেরিফিকেশন কোড দিন',
        );
        OmniText.setLanguage(OmniLanguage.ar);
        expect(OmniValidators.password(''), 'الرجاء إدخال كلمة المرور');
      },
    );

    testWidgets(
      'Zero-setup instant language switch updates ALL screens, MaterialApp locale, RTL & OmniFields live',
      (t) async {
        const reusableText = OmniText(
          en: 'Reusable Label',
          bn: 'পুনর্ব্যবহারযোগ্য লেবেল',
          ar: 'تسمية قابلة لإعادة الاستخدام',
        );

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Builder(
                  builder: (ctx) => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        ctx.l10n(
                          en: 'Home Screen',
                          bn: 'হোম স্ক্রিন',
                          ar: 'الرئيسية',
                        ),
                      ),
                    ),
                    body: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const OmniText(
                          en: 'Direct Widget Text',
                          bn: 'সরাসরি উইজেট টেক্সট',
                          ar: 'نص مباشر',
                        ),
                        Text(reusableText.tr(ctx)),
                        Text(_TestAuthLang(ctx).signIn),
                        Text(_TestAuthLang(ctx).greet('Juwel')),
                        const OmniPhoneField(
                          initialValue: '01712345678',
                          onVerifyPressed: _noop,
                        ),
                        const OmniLanguagePicker(
                          languages: [
                            OmniLanguage.en,
                            OmniLanguage.bn,
                            OmniLanguage.ar,
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => ctx.push('/second'),
                          child: const Text('Go Second'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OmniPage(
                '/second',
                (_) => Builder(
                  builder: (ctx) => Scaffold(
                    appBar: AppBar(title: Text(_TestAuthLang(ctx).signIn)),
                    body: Center(
                      child: Text(
                        ctx.l10n(
                          en: 'Second Page',
                          bn: 'দ্বিতীয় পেজ',
                          ar: 'الصفحة الثانية',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
        expect(find.text('Direct Widget Text'), findsOneWidget);
        expect(find.text('Reusable Label'), findsOneWidget);
        expect(find.text('Hello, Juwel!'), findsOneWidget);
        expect(find.text('Mobile Number'), findsOneWidget);
        expect(find.text('Verify'), findsOneWidget);

        // Navigate onto stacked second screen, then switch language globally:
        await t.tap(find.text('Go Second'));
        await t.pumpAndSettle();
        expect(find.text('Second Page'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);

        // 1 call changes ALL screens (both pushed route and underlying route) with ZERO reload:
        OmniText.setLanguage(OmniLanguage.bn);
        await t.pumpAndSettle();

        expect(find.text('দ্বিতীয় পেজ'), findsOneWidget);
        expect(find.text('সাইন ইন'), findsOneWidget);

        OmniRoute.pop();
        await t.pumpAndSettle();

        expect(find.text('হোম স্ক্রিন'), findsOneWidget);
        expect(find.text('সরাসরি উইজেট টেক্সট'), findsOneWidget);
        expect(find.text('পুনর্ব্যবহারযোগ্য লেবেল'), findsOneWidget);
        expect(find.text('হ্যালো, Juwel!'), findsOneWidget);
        expect(find.text('মোবাইল নাম্বার'), findsOneWidget);
        expect(find.text('যাচাই করুন'), findsOneWidget);

        // Country enum switch to UK English verifies byCountry override:
        OmniText.setCountry(OmniCountryCode.gb);
        await t.pumpAndSettle();
        expect(find.text('Log On'), findsOneWidget);

        // Arabic auto-flips Directionality to RTL across app with ZERO extra setup:
        OmniText.setCountry(OmniCountryCode.sa);
        await t.pumpAndSettle();
        expect(find.text('الرئيسية'), findsOneWidget);
        expect(find.text('رقم الجوال'), findsOneWidget);
        expect(
          Directionality.of(t.element(find.text('الرئيسية'))),
          TextDirection.rtl,
        );

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Standalone OmniText widget works even inside a plain MaterialApp without OmniApp',
      (t) async {
        await t.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: OmniText(en: 'Plain App Text', bn: 'সাধারণ অ্যাপ টেক্সট'),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Plain App Text'), findsOneWidget);

        OmniText.change(OmniLanguage.bn);
        await t.pumpAndSettle();
        expect(find.text('সাধারণ অ্যাপ টেক্সট'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
      },
    );
  });
}

void _noop() {}
