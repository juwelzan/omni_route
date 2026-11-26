import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_route/omni_route.dart';

class S extends OmniStatelessWidget {
  const S(this.label, {super.key, this.blockBack = false});
  final String label;
  final bool blockBack;
  @override
  String get screenName => label;
  @override
  Widget build(BuildContext context) {
    final body = Scaffold(body: Center(child: Text(label)));
    return blockBack ? PopScope(canPop: false, child: body) : body;
  }
}

Widget app({
  OmniPageType transition = OmniPages.material,
  bool escape = false,
}) => OmniApp(
  transition: transition,
  escapeGoesBack: escape,
  routes: [
    OmniPage('/', (_) => const S('home')),
    OmniPage('/a', (_) => const S('page a')),
    OmniPage('/locked', (_) => const S('locked', blockBack: true)),
    OmniPage('/fade', (_) => const S('fade'), transition: OmniPages.none),
  ],
  builder: (_, r) => MaterialApp.router(routerConfig: r),
);

Future<void> openA(WidgetTester t, [String to = '/a']) async {
  await t.pumpWidget(app());
  await t.pumpAndSettle();
  OmniRoute.push(to);
  await t.pumpAndSettle();
}

void main() {
  group('Android', () {
    testWidgets('system back pops; PopScope can block it', (t) async {
      await openA(t);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      OmniRoute.push('/locked');
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('locked'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('desktop shortcuts are inactive on mobile', (t) async {
      await openA(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await t.pumpAndSettle();
      expect(find.text('page a'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('iOS', () {
    testWidgets('swipe from left edge goes back (default material page)', (
      t,
    ) async {
      await openA(t);
      await t.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('swipe back respects PopScope', (t) async {
      await openA(t, '/locked');
      await t.dragFrom(const Offset(5, 300), const Offset(500, 0));
      await t.pumpAndSettle();
      expect(find.text('locked'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('Desktop', () {
    testWidgets('Alt+Left goes back', (t) async {
      await openA(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('Alt+Left goes back (Linux)', (t) async {
      await openA(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('Cmd+[ goes back', (t) async {
      await openA(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('mouse back button goes back, respects PopScope', (t) async {
      await openA(t);
      final g = await t.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await g.down(const Offset(100, 100));
      await g.up();
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      OmniRoute.push('/locked');
      await t.pumpAndSettle();
      await g.down(const Offset(100, 100));
      await g.up();
      await t.pumpAndSettle();
      expect(find.text('locked'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Escape only when enabled; dialog closes first', (t) async {
      await openA(t);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('page a'), findsOneWidget, reason: 'off by default');

      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(escape: true));
      await t.pumpAndSettle();
      OmniRoute.push('/a');
      await t.pumpAndSettle();
      showDialog<void>(
        context: t.element(find.text('page a')),
        builder: (_) => const Text('dialog'),
      );
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('dialog'), findsNothing);
      expect(find.text('page a'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('Page types', () {
    testWidgets('cupertino and none page types', (t) async {
      await t.pumpWidget(app(transition: OmniPages.cupertino));
      await t.pumpAndSettle();
      OmniRoute.push('/a');
      await t.pumpAndSettle();
      expect(
        t.widget<Navigator>(find.byType(Navigator)).pages.last,
        isA<CupertinoPage<void>>(),
      );
      OmniRoute.push('/fade');
      final frames = await t.pumpAndSettle();
      expect(
        frames,
        lessThanOrEqualTo(2),
        reason: 'per-route none = no animation',
      );
    });

    testWidgets('default material page uses platform transitions', (t) async {
      await openA(t);
      expect(
        t.widget<Navigator>(find.byType(Navigator)).pages.last,
        isA<MaterialPage<void>>(),
      );
    }, variant: TargetPlatformVariant.all());
  });
}
