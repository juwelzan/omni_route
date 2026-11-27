import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';
import 'package:omni_route_example/main.dart';

void main() {
  testWidgets(
    'Fast ExampleApp flow: guards, page-entry Bloc, OmniRouteGroup, onExit, '
    'Settings animations, Dark/Light & Color Palette switching, nested profile',
    (tester) async {
      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();

      // 1. AuthGuard redirects unauthenticated startup -> /login (with OmniEmailField.gmail & OmniPasswordField).
      expect(OmniRoute.routePath, '/login');
      expect(find.byType(OmniEmailField), findsOneWidget);
      expect(find.byType(OmniPasswordField), findsOneWidget);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      // 2. Dashboard: OmniStatefulWidget + OmniLifecycle + .hosted() OmniStatelessWidget.
      expect(OmniRoute.routePath, '/dashboard');
      expect(find.textContaining('Hosted OmniStatelessWidget'), findsOneWidget);

      // Classic Named Route (`/classic-student/205`).
      await tester.tap(find.text('Classic Named Route'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Classic Style:'), findsOneWidget);
      await tester.tap(find.text('Pop Classic Route'));
      await tester.pumpAndSettle();

      // Jump directly to /students/101 (OmniRouteGroup + StudentDetailBloc).
      await tester.tap(find.text('Open student 101'));
      await tester.pumpAndSettle();
      expect(find.text('Route: /students/101'), findsOneWidget);

      // AttendanceBloc (page-scoped on StudentDetailScreen).
      await tester.tap(find.text('Mark present'));
      await tester.pumpAndSettle();
      expect(find.text('Present: true'), findsOneWidget);

      // Edit screen with slideUp transition + onExit confirmation guard.
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Rahim Updated');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to list'));
      await tester.pumpAndSettle();
      expect(find.text('Discard edits?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rahim Updated'), findsOneWidget);

      // Re-tap active Students tab -> resets Branch 1 to /students (with OmniSearchField).
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(find.byType(OmniSearchField), findsOneWidget);
      expect(find.text('Student #101'), findsOneWidget);

      // Settings -> Animation picker, Dark/Light mode & 1-click Color Palette -> Nested `/settings/profile`.
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final settingsScroll = find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Diagonal Sweep'),
        120,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diagonal Sweep'));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(SettingsScreen)).activeThemeAnimationMode,
        OmniThemeAnimationMode.diagonalSweep,
      );
      await tester.scrollUntilVisible(
        find.text('Dark'),
        -120,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(find.text('Emerald'));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(SettingsScreen)).colors.primaryColor,
        OmniTheme.emerald.dark!.primaryColor,
      );
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(SettingsScreen)).colors.primaryColor,
        OmniTheme.emerald.seedColor,
      );

      final profileTile = find.text('Profile');
      await tester.scrollUntilVisible(
        profileTile,
        150,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(profileTile);
      await tester.pumpAndSettle();

      expect(OmniRoute.routePath, '/settings/profile');
      expect(
        find.text('Full nested routePath: /settings/profile'),
        findsOneWidget,
      );
      expect(find.byType(OmniPhoneField), findsOneWidget);
      expect(find.byType(OmniOtpField), findsOneWidget);
      expect(find.byType(OmniNumberField), findsNWidgets(2));
      expect(find.byType(OmniUrlField), findsOneWidget);
      expect(find.byType(OmniMultilineField), findsOneWidget);
      expect(find.byType(OmniTextField), findsNWidgets(3));

      // Verify OTP paste completion inside nested ProfileScreen:
      final otpBox = find
          .descendant(
            of: find.byType(OmniOtpField),
            matching: find.byType(TextField),
          )
          .first;
      await tester.ensureVisible(otpBox);
      await tester.enterText(otpBox, '123456');
      await tester.pumpAndSettle();
      expect(find.text('OTP Verified'), findsOneWidget);

      // 4. Interactive Fields Playground tab -> showcases EVERY predefined field + 3/4/5/6 OTP lengths:
      await tester.tap(find.text('Fields'));
      await tester.pumpAndSettle();
      expect(OmniRoute.routePath, '/fields');

      final playgroundScroll = find
          .descendant(
            of: find.byType(FieldsPlaygroundScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      expect(find.byType(OmniNameField), findsNWidgets(4));
      expect(find.byType(OmniEmailField), findsNWidgets(2));
      expect(find.byType(OmniPasswordField), findsNWidgets(3));

      await tester.scrollUntilVisible(
        find.byType(OmniOtpField),
        200,
        scrollable: playgroundScroll,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OmniPhoneField), findsOneWidget);

      // Verify switching OTP length 6 -> 3 -> 4 -> 5 updates box counts live:
      expect(find.text('11/11'), findsOneWidget);
      for (final digits in const [3, 4, 5, 6]) {
        final btn = find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('$digits'),
        );
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await tester.pumpAndSettle();
        final cells = find.descendant(
          of: find.byType(OmniOtpField),
          matching: find.byType(AnimatedContainer),
        );
        expect(cells, findsNWidgets(digits));
      }

      // Exercise Warning, Error, Simulate Verify (mergeCheck) & Reset in FieldsPlayground:
      await tester.ensureVisible(find.text('Warning'));
      await tester.tap(find.text('Warning'));
      await tester.pumpAndSettle();
      expect(
        find.text('Only 2 attempts left — check your SMS code'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Error'));
      await tester.tap(find.text('Error'));
      await tester.pumpAndSettle();
      expect(
        find.text('Invalid verification code — please retry'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Simulate Verify'));
      await tester.tap(find.text('Simulate Verify'));
      await tester.pumpAndSettle();
      expect(find.text('OTP Verified'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.ensureVisible(find.text('Reset OTP'));
      await tester.tap(find.text('Reset OTP'));
      await tester.pumpAndSettle();
      expect(find.text('OTP Verified'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Validate All Fields'),
        220,
        scrollable: playgroundScroll,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OmniNumberField), findsNWidgets(4));
      expect(find.byType(OmniSearchField), findsOneWidget);
      expect(find.byType(OmniUrlField), findsOneWidget);
      expect(find.byType(OmniMultilineField), findsOneWidget);
      expect(find.byType(OmniTextField), findsNWidgets(3));
    },
  );
}
