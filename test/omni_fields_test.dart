import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

void main() {
  group('OmniValidators unit checks', () {
    test('email & gmail validators reject invalid domains and accept valid ones', () {
      expect(OmniValidators.email(''), isNotNull);
      expect(OmniValidators.email('invalid-email'), isNotNull);
      expect(OmniValidators.email('user@yahoo.com'), isNull);
      expect(OmniValidators.gmail('user@yahoo.com'), isNotNull);
      expect(OmniValidators.gmail('user@gmail.com'), isNull);
      expect(OmniValidators.gmail('USER@GOOGLEMAIL.COM'), isNull);
      expect(
        OmniValidators.email(
          'dev@company.com',
          allowedDomains: const ['company.com'],
        ),
        isNull,
      );
      expect(
        OmniValidators.email(
          'dev@gmail.com',
          allowedDomains: const ['company.com'],
        ),
        isNotNull,
      );
    });

    test('password, strength score, name, phone, number, otp & url validators work', () {
      expect(OmniValidators.password('123'), isNotNull);
      expect(OmniValidators.password('123456'), isNull);
      expect(
        OmniValidators.password('abcdef', requireUppercase: true),
        isNotNull,
      );
      expect(OmniValidators.passwordStrengthScore('abc'), 1);
      expect(OmniValidators.passwordStrengthScore('Abcdef12!'), 4);

      expect(OmniValidators.name('A'), isNotNull);
      expect(OmniValidators.name('Juwel123'), isNotNull);
      expect(OmniValidators.name('Juwel Mia'), isNull);
      expect(OmniValidators.name('dev 1', allowSpaces: false, allowDigits: true), isNotNull);
      expect(OmniValidators.name('juwel_99', allowSpaces: false, allowDigits: true), isNull);

      expect(OmniValidators.phone('01712345678', countryCode: '+880'), isNull);
      expect(OmniValidators.phone('1712345678', countryCode: '+880'), isNull);
      expect(OmniValidators.phone('01212345678', countryCode: '+880'), isNotNull);
      expect(
        OmniValidators.normalizePhone('01712345678', countryCode: '+880'),
        '+8801712345678',
      );
      expect(OmniValidators.phone('2025550147', countryCode: '+1'), isNull);
      expect(OmniValidators.phone('12345', countryCode: '+1'), isNotNull);

      expect(OmniValidators.number('42', min: 10, max: 50), isNull);
      expect(OmniValidators.number('5', min: 10), isNotNull);
      expect(OmniValidators.number('12.5', allowDecimal: false), isNotNull);
      expect(OmniValidators.number('12.5', allowDecimal: true), isNull);

      expect(OmniValidators.otp('123', length: 6), isNotNull);
      expect(OmniValidators.otp('123456', length: 6), isNull);

      expect(OmniValidators.url('not a url'), isNotNull);
      expect(OmniValidators.url('https://omniroute.dev/docs'), isNull);
    });
  });

  group('Shared OmniFieldTheme + distinct field identities & features', () {
    testWidgets(
      'One OmniFieldTheme applies to all predefined fields while keeping per-identity overrides & Dark/Light reactivity',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});

        const sharedTheme = OmniFieldTheme(
          variant: OmniInputVariant.outlined,
          labelMode: OmniFieldLabelMode.above,
          borderRadius: 18,
          fillColor: Color(0xFFF0F9FF),
          darkFillColor: Color(0xFF0F172A),
          identityStyles: {
            OmniFieldIdentity.email: OmniFieldStyle(
              accentColor: Color(0xFF0284C7),
            ),
            OmniFieldIdentity.password: OmniFieldStyle(
              accentColor: Color(0xFF7C3AED),
            ),
          },
        );

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(
              seedColor: Color(0xFF2563EB),
              mode: ThemeMode.light,
              fieldTheme: sharedTheme,
            ),
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  appBar: AppBar(actions: const [OmniThemeModeButton()]),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      OmniEmailField(),
                      SizedBox(height: 12),
                      OmniPasswordField(),
                      SizedBox(height: 12),
                      OmniNameField(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // Above labels rendered by shared labelMode:
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Full Name'), findsOneWidget);

        // Distinct identity cursor/accent colors preserved even under ONE shared theme:
        final tfWidgets = t.widgetList<TextField>(find.byType(TextField)).toList();
        expect(tfWidgets.length, 3);
        expect(tfWidgets[0].cursorColor, const Color(0xFF0284C7)); // email identity
        expect(tfWidgets[1].cursorColor, const Color(0xFF7C3AED)); // password identity
        expect(tfWidgets[2].cursorColor, isNot(const Color(0xFF0284C7))); // name default accent

        // Toggle Dark Mode -> all fields react automatically without changing field widget code:
        await t.tap(find.byType(OmniThemeModeButton));
        await t.pumpAndSettle();
        final darkEmail = t.widgetList<TextField>(find.byType(TextField)).first;
        expect(darkEmail.decoration?.fillColor, const Color(0xFF0F172A));

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'OmniEmailField, OmniPasswordField, OmniNameField, OmniPhoneField, OmniNumberField & OmniOtpField interactive features',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final formKey = GlobalKey<FormState>();
        final passwordCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final otpCtrl = TextEditingController();
        addTearDown(() {
          passwordCtrl.dispose();
          phoneCtrl.dispose();
          otpCtrl.dispose();
        });

        String? latestFullPhone;
        String? completedOtp;
        num? latestPrice;
        bool phoneVerifyClicked = false;
        bool resendClicked = false;

        await t.pumpWidget(
          OmniApp.material(
            omniTheme: const OmniTheme(mode: ThemeMode.light),
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          const OmniEmailField.gmail(key: Key('gmail_field')),
                          const SizedBox(height: 12),
                          OmniPasswordField.newPassword(
                            key: const Key('new_pw_field'),
                            controller: passwordCtrl,
                          ),
                          const SizedBox(height: 12),
                          OmniPasswordField.confirm(
                            key: const Key('confirm_pw_field'),
                            matchController: passwordCtrl,
                          ),
                          const SizedBox(height: 12),
                          const OmniNameField.username(key: Key('username_field')),
                          const SizedBox(height: 12),
                          OmniPhoneField(
                            key: const Key('phone_field'),
                            controller: phoneCtrl,
                            onFullNumberChanged: (v) => latestFullPhone = v,
                            onVerifyPressed: () => phoneVerifyClicked = true,
                          ),
                          const SizedBox(height: 12),
                          OmniNumberField.integer(
                            key: const Key('qty_field'),
                            initialValue: '5',
                            min: 1,
                            max: 10,
                            step: 2,
                            onNumberChanged: (v) => latestPrice = v,
                          ),
                          const SizedBox(height: 12),
                          OmniOtpField(
                            key: const Key('otp_field'),
                            length: 4,
                            controller: otpCtrl,
                            resendDuration: const Duration(seconds: 2),
                            onResend: () => resendClicked = true,
                            onCompleted: (c) => completedOtp = c,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // 1. Gmail quick-fill + Gmail-only validation:
        await t.enterText(find.byKey(const Key('gmail_field')), 'juwel');
        await t.pump();
        expect(find.text('@gmail.com'), findsOneWidget);
        await t.tap(find.text('@gmail.com'));
        await t.pump();
        expect(find.text('juwel@gmail.com'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        // Reject non-gmail address in Gmail field:
        await t.enterText(find.byKey(const Key('gmail_field')), 'juwel@yahoo.com');
        await t.pump();
        expect(find.text('Please enter a valid @gmail.com address'), findsOneWidget);

        // Restore valid Gmail:
        await t.enterText(find.byKey(const Key('gmail_field')), 'juwel@gmail.com');
        await t.pump();

        // 2. Password show/hide + strength meter + confirm match:
        await t.enterText(find.byKey(const Key('new_pw_field')), 'Abcdef1!');
        await t.pump();
        expect(find.text('Strong'), findsOneWidget);

        final pwEditable = find.descendant(
          of: find.byKey(const Key('new_pw_field')),
          matching: find.byType(EditableText),
        );
        expect(t.widget<EditableText>(pwEditable).obscureText, isTrue);
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('new_pw_field')),
            matching: find.byIcon(Icons.visibility_outlined),
          ),
        );
        await t.pump();
        expect(t.widget<EditableText>(pwEditable).obscureText, isFalse);

        // Confirm password mismatch -> error -> fix -> valid match icon:
        await t.ensureVisible(find.byKey(const Key('confirm_pw_field')));
        await t.enterText(find.byKey(const Key('confirm_pw_field')), 'wrong');
        await t.pump();
        expect(find.text('Passwords do not match'), findsOneWidget);
        await t.enterText(find.byKey(const Key('confirm_pw_field')), 'Abcdef1!');
        await t.pump();
        expect(find.text('Passwords do not match'), findsNothing);

        // 3. Username filters spaces & validates:
        await t.ensureVisible(find.byKey(const Key('username_field')));
        await t.enterText(find.byKey(const Key('username_field')), 'ab');
        await t.pump();
        expect(find.text('Must be at least 3 characters'), findsOneWidget);
        await t.enterText(find.byKey(const Key('username_field')), 'juwel_dev');
        await t.pump();

        // 4. Phone field BD normalization + verify button:
        await t.ensureVisible(find.byKey(const Key('phone_field')));
        await t.enterText(find.byKey(const Key('phone_field')), '01712345678');
        await t.pump();
        expect(latestFullPhone, '+8801712345678');
        await t.tap(find.text('Verify'));
        await t.pump();
        expect(phoneVerifyClicked, isTrue);

        // 5. Number stepper buttons:
        await t.ensureVisible(find.byKey(const Key('qty_field')));
        await t.tap(
          find.descendant(
            of: find.byKey(const Key('qty_field')),
            matching: find.byIcon(Icons.add_rounded),
          ),
        );
        await t.pump();
        expect(latestPrice, 7);

        // 6. OTP multi-digit paste extraction + completion + resend countdown:
        await t.ensureVisible(find.byKey(const Key('otp_field')));
        final firstOtpBox = find
            .descendant(
              of: find.byKey(const Key('otp_field')),
              matching: find.byType(TextField),
            )
            .first;
        await t.enterText(firstOtpBox, 'Code is 4829');
        await t.pump();
        expect(otpCtrl.text, '4829');
        expect(completedOtp, '4829');

        expect(formKey.currentState!.validate(), isTrue);

        // Wait 2.1s for resend countdown to finish and click Resend Code:
        await t.pump(const Duration(seconds: 2));
        await t.pump(const Duration(milliseconds: 200));
        await t.ensureVisible(find.text('Resend Code'));
        await t.tap(find.text('Resend Code'));
        await t.pump();
        expect(resendClicked, isTrue);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'OmniSearchField debounced callback, OmniMultilineField & OmniUrlField work cleanly',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        String? debouncedQuery;

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: Column(
                    children: [
                      OmniSearchField(
                        key: const Key('search_field'),
                        debounceDuration: const Duration(milliseconds: 120),
                        onSearchChanged: (v) => debouncedQuery = v,
                      ),
                      const OmniMultilineField(key: Key('bio_field'), maxLength: 100),
                      const OmniUrlField(key: Key('url_field')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        await t.enterText(find.byKey(const Key('search_field')), 'flutter');
        await t.pump(const Duration(milliseconds: 50));
        expect(debouncedQuery, isNull); // not yet debounced
        await t.pump(const Duration(milliseconds: 100));
        expect(debouncedQuery, 'flutter');

        await t.enterText(find.byKey(const Key('url_field')), 'not valid');
        await t.pump();
        expect(find.textContaining('valid URL'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'OmniFieldThemeScope, OmniPhoneField country picker dialog & OmniOtpField incomplete validation work',
      (t) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final otpFormKey = GlobalKey<FormState>();
        String? selectedDialCode;

        await t.pumpWidget(
          OmniApp.material(
            routes: [
              OmniPage(
                '/',
                (_) => Scaffold(
                  body: OmniFieldThemeScope(
                    theme: const OmniFieldTheme(
                      variant: OmniInputVariant.filled,
                      labelMode: OmniFieldLabelMode.above,
                      otpBoxStyle: OmniOtpBoxStyle.filled,
                      fillColor: Color(0xFFECFDF5),
                    ),
                    child: Form(
                      key: otpFormKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          OmniPhoneField(
                            key: const Key('scoped_phone'),
                            onCountryChanged: (c) =>
                                selectedDialCode = c.dialCode,
                          ),
                          const SizedBox(height: 12),
                          OmniOtpField(
                            key: const Key('scoped_otp'),
                            length: 4,
                            boxStyle: OmniOtpBoxStyle.underlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        await t.pumpAndSettle();

        // Scope fill color applied cleanly:
        final phoneTf = t.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('scoped_phone')),
            matching: find.byType(TextField),
          ),
        );
        expect(phoneTf.decoration?.fillColor, const Color(0xFFECFDF5));

        // Open country picker dialog & switch from +880 to +1 (US):
        await t.tap(find.text('+880'));
        await t.pumpAndSettle();
        await t.tap(find.text('United States (US)'));
        await t.pumpAndSettle();
        expect(selectedDialCode, '+1');
        expect(find.text('+1'), findsOneWidget);

        // Incomplete OTP triggers Form validation message:
        final firstOtp = find
            .descendant(
              of: find.byKey(const Key('scoped_otp')),
              matching: find.byType(TextField),
            )
            .first;
        await t.enterText(firstOtp, '42');
        await t.pump();
        expect(otpFormKey.currentState!.validate(), isFalse);
        await t.pump();
        expect(find.text('Enter the 4-digit verification code'), findsOneWidget);

        await t.pumpWidget(const SizedBox());
      },
    );
  });
}
