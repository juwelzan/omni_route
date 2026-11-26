// 0.3.0: app-switcher colour and TapRegion keyboard dismiss.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key});
  final String label;
  @override
  String get routePath => '/$label';
  @override
  String get title => label;
  @override
  Widget build(BuildContext context) => Text(label);
}

/// The last colour sent with the title [label].
Future<int?> switcherColor(
  WidgetTester t,
  Widget app, {
  String label = 'home',
}) async {
  int? color;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'SystemChrome.setApplicationSwitcherDescription') {
          final args = c.arguments as Map;
          if (args['label'] == label) color = args['primaryColor'] as int;
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  await t.pumpWidget(app);
  await t.pumpAndSettle();
  return color;
}

Widget material({Color? titleColor, ThemeData? theme}) => OmniApp(
  titleColor: titleColor,
  routes: [OmniPage('/', (_) => const S('home'))],
  builder: (_, r) => MaterialApp.router(theme: theme, routerConfig: r),
);

var buttonTaps = 0;

class Form extends OmniStatelessWidget {
  const Form({super.key});
  @override
  String get routePath => '/form';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        const SizedBox(height: 150),
        const SizedBox(width: 200, child: TextField()),
        TextButton(onPressed: () => buttonTaps++, child: const Text('Btn')),
        const SizedBox(height: 2000),
      ],
    ),
  );
}

bool focused(WidgetTester t) =>
    t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

Future<void> openForm(WidgetTester t) async {
  await t.pumpWidget(
    OmniApp(
      dismissKeyboardOnTap: true,
      routes: [OmniPage('/', (_) => const Form())],
      builder: (_, r) => MaterialApp.router(routerConfig: r),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byType(TextField));
  await t.pump();
  expect(focused(t), isTrue);
}

void main() {
  group('dismissKeyboardOnTap (TapRegion)', () {
    testWidgets('a scroll outside keeps the keyboard open', (t) async {
      await openForm(t);
      await t.dragFrom(const Offset(400, 400), const Offset(0, -80));
      await t.pumpAndSettle();
      expect(focused(t), isTrue);
      expect(t.getTopLeft(find.byType(TextField)).dy, lessThan(150));
    });

    testWidgets('a button tap still works and closes the keyboard', (t) async {
      buttonTaps = 0;
      await openForm(t);
      await t.tap(find.text('Btn'));
      await t.pump();
      expect(buttonTaps, 1);
      expect(focused(t), isFalse);
    });

    testWidgets('no gesture detector above the app', (t) async {
      await openForm(t);
      expect(
        find.ancestor(
          of: find.byType(MaterialApp),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('titleColor', () {
    testWidgets('explicit colour', (t) async {
      expect(
        await switcherColor(t, material(titleColor: const Color(0xFF123456))),
        0xFF123456,
      );
    });

    testWidgets("default: the theme's primary colour", (t) async {
      final theme = ThemeData(colorSchemeSeed: Colors.teal);
      expect(
        await switcherColor(t, material(theme: theme)),
        theme.colorScheme.primary.toARGB32(),
      );
    });

    testWidgets('no Material theme: black', (t) async {
      final app = OmniApp(
        routes: [OmniPage('/', (_) => const S('home'))],
        builder: (_, r) =>
            WidgetsApp.router(routerConfig: r, color: const Color(0xFFFF0000)),
      );
      expect(await switcherColor(t, app), 0xFF000000);
    });
  });
}
