import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _box = Key('box');

late BuildContext _ctx;

Widget _app({ThemeData? theme, TransitionBuilder? builder}) => MaterialApp(
  theme: theme,
  builder: builder,
  home: Builder(
    builder: (c) {
      _ctx = c;
      return const Scaffold(body: SizedBox.expand());
    },
  ),
);

Rect _rect(WidgetTester t, [Key key = _box]) => t.getRect(find.byKey(key));

void main() {
  testWidgets('opens with a spring, builds content once, returns a result', (
    t,
  ) async {
    await t.pumpWidget(_app());
    var builds = 0;
    final result = showOmniBottomSheet<String>(
      context: _ctx,
      style: OmniSheetStyle.material,
      builder: (c) {
        builds++;
        return const SizedBox(key: _box, height: 200);
      },
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 80));
    final midTop = _rect(t).top;
    await t.pumpAndSettle();
    expect(_rect(t).bottom, 600, reason: 'anchored to the bottom edge');
    expect(midTop, greaterThan(_rect(t).top), reason: 'slid up');

    // A small slow drag springs back; content is not rebuilt.
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 60),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_rect(t).bottom, 600);
    expect(builds, 1);

    OmniSheet.of(t.element(find.byKey(_box))).close('done');
    await t.pumpAndSettle();
    expect(await result, 'done');
    expect(find.byKey(_box), findsNothing);
  });

  testWidgets('dragging past half dismisses; fast flick dismisses too', (
    t,
  ) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 160),
      const Duration(milliseconds: 800),
    );
    await t.pumpAndSettle();
    expect(find.byKey(_box), findsNothing);

    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();
    await t.fling(find.byKey(_box), const Offset(0, 80), 2500);
    await t.pumpAndSettle();
    expect(find.byKey(_box), findsNothing);
  });

  testWidgets('barrier tap closes; isDismissible: false keeps it', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 50));
    await t.pumpAndSettle();
    expect(find.byKey(_box), findsNothing);

    showOmniBottomSheet<void>(
      context: _ctx,
      isDismissible: false,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 50));
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 300),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(find.byKey(_box), findsOneWidget);
    expect(_rect(t).bottom, 600);
  });

  testWidgets('detents: opens at medium, flings to large, snapTo', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      showHandle: false,
      detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
      builder: (_) => const SizedBox.expand(key: _box),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 300);
    final sheet = OmniSheet.of(t.element(find.byKey(_box)));
    expect(sheet.detent.value, 0);

    await t.fling(find.byKey(_box), const Offset(0, -120), 1500);
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
    expect(_rect(t).height, 600, reason: 'resized to the detent');
    expect(sheet.detent.value, 1);

    sheet.snapTo(0);
    await t.pumpAndSettle();
    expect(_rect(t).top, 300);
    expect(_rect(t).height, 300);
  });

  testWidgets('initialDetent follows the given order', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      showHandle: false,
      detents: const [OmniSheetDetent.large, OmniSheetDetent.medium],
      builder: (_) => const SizedBox.expand(key: _box),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
  });

  testWidgets('a list inside hands its drag over to the sheet', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      showHandle: false,
      detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
      builder: (_) => ListView(
        key: _box,
        children: [
          for (var i = 0; i < 60; i++)
            SizedBox(height: 50, child: Text('row $i')),
        ],
      ),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 300);

    // Dragging the list up first expands the sheet, not the list.
    await t.timedDrag(
      find.text('row 2'),
      const Offset(0, -300),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
    expect(find.text('row 0'), findsOneWidget, reason: 'list not scrolled');

    // Fully expanded: now the list scrolls.
    await t.timedDrag(
      find.text('row 5'),
      const Offset(0, -200),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(find.text('row 0'), findsNothing);
    expect(_rect(t).top, 0);

    // Dragging down scrolls the list back before moving the sheet.
    await t.timedDrag(
      find.text('row 6'),
      const Offset(0, 120),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);

    // At the top of the list a long drag down dismisses the sheet.
    // (The list is scrolled a little: it scrolls back first, then the sheet
    // follows the finger.)
    await t.timedDragFrom(
      const Offset(400, 200),
      const Offset(0, 380),
      const Duration(milliseconds: 900),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 300, reason: 'came down to the medium detent');

    // From the medium detent, a drag down at the top of the list dismisses.
    await t.timedDragFrom(
      const Offset(400, 400),
      const Offset(0, 190),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(find.byKey(_box), findsNothing);
  });

  testWidgets('cupertino: top gap, grabber and rubber-band stretch', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.cupertino,
      showHandle: false,
      detents: const [OmniSheetDetent.large],
      builder: (_) => const SizedBox.expand(key: _box),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 10, reason: 'iOS leaves a gap above a large sheet');

    final g = await t.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(0, -20));
    await g.moveBy(const Offset(0, -200));
    await t.pump();
    final stretched = _rect(t).top;
    expect(stretched, lessThan(10));
    expect(stretched, greaterThan(10 - 200), reason: 'with resistance');
    await g.up();
    await t.pumpAndSettle();
    expect(_rect(t).top, 10);
  });

  testWidgets('material: no stretch past the top', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      showHandle: false,
      detents: const [OmniSheetDetent.large],
      builder: (_) => const SizedBox.expand(key: _box),
    );
    await t.pumpAndSettle();
    final g = await t.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(0, -20));
    await g.moveBy(const Offset(0, -200));
    await t.pump();
    expect(_rect(t).top, 0);
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('floating: inset card with all corners rounded', (t) async {
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.floating,
      showHandle: false,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();
    final r = _rect(t);
    expect(r.bottom, 590, reason: 'lifted off the bottom edge');
    expect(r.width, 560, reason: 'floating sheets are 560 wide at most');
    expect(r.center.dx, 400);
    final material = t.widget<Material>(
      find
          .ancestor(of: find.byKey(_box), matching: find.byType(Material))
          .first,
    );
    expect(
      (material.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(28)),
    );
  });

  testWidgets('wide screens get a centered sheet', (t) async {
    t.view.physicalSize = const Size(1600, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 100),
    );
    await t.pumpAndSettle();
    final r = _rect(t);
    expect(r.width, 640);
    expect(r.center.dx, 800);
  });

  testWidgets('adaptive is cupertino on iOS and material on Android', (
    t,
  ) async {
    await t.pumpWidget(_app(theme: ThemeData(platform: TargetPlatform.iOS)));
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 100),
    );
    await t.pumpAndSettle();
    expect(
      OmniSheet.of(t.element(find.byKey(_box))).style,
      OmniSheetStyle.cupertino,
    );
    OmniSheet.of(t.element(find.byKey(_box))).close();
    await t.pumpAndSettle();

    await t.pumpWidget(
      _app(theme: ThemeData(platform: TargetPlatform.android)),
    );
    await t.pumpAndSettle(); // MaterialApp animates the theme change.
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 100),
    );
    await t.pumpAndSettle();
    expect(
      OmniSheet.of(t.element(find.byKey(_box))).style,
      OmniSheetStyle.material,
    );
  });

  testWidgets('works inside a CupertinoApp with system colors', (t) async {
    await t.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (c) {
            _ctx = c;
            return const CupertinoPageScaffold(child: SizedBox.expand());
          },
        ),
      ),
    );
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.cupertino,
      builder: (_) => const SizedBox(key: _box, height: 120, child: Text('Hi')),
    );
    await t.pumpAndSettle();
    expect(find.text('Hi'), findsOneWidget);
    final material = t.widget<Material>(
      find
          .ancestor(of: find.byKey(_box), matching: find.byType(Material))
          .first,
    );
    expect(material.color!.toARGB32(), CupertinoColors.white.toARGB32());
    await t.tapAt(const Offset(400, 40));
    await t.pumpAndSettle();
    expect(find.text('Hi'), findsNothing);
  });

  testWidgets('a PopScope in the sheet blocks drag dismissal', (t) async {
    var asked = 0;
    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      builder: (_) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => asked++,
        child: const SizedBox(key: _box, height: 200),
      ),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 180),
      const Duration(milliseconds: 700),
    );
    await t.pumpAndSettle();
    expect(asked, 1);
    expect(find.byKey(_box), findsOneWidget);
    expect(_rect(t).bottom, 600, reason: 'sprang back');
  });

  testWidgets('reduce motion fades instead of sliding', (t) async {
    await t.pumpWidget(
      _app(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    expect(_rect(t).bottom, 600, reason: 'already in place while fading');
    await t.pumpAndSettle();
    expect(_rect(t).bottom, 600);
  });

  testWidgets('uses the Omni theme colors', (t) async {
    const sheetColor = Color(0xFFFFF7ED);
    final theme =
        const OmniTheme(
          light: OmniColorPalette(bottomSheetColor: sheetColor),
        ).resolve(
          device: OmniDeviceType.mobile,
          tokens: OmniResponsiveTokens.mobile,
          brightness: Brightness.light,
        );
    await t.pumpWidget(_app(theme: theme));
    showOmniBottomSheet<void>(
      context: _ctx,
      builder: (_) => const SizedBox(key: _box, height: 100),
    );
    await t.pumpAndSettle();
    final material = t.widget<Material>(
      find
          .ancestor(of: find.byKey(_box), matching: find.byType(Material))
          .first,
    );
    expect(material.color, sheetColor);
  });

  testWidgets('sits above the keyboard', (t) async {
    await t.pumpWidget(
      _app(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 250)),
          child: child!,
        ),
      ),
    );
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.material,
      builder: (_) => const SizedBox(key: _box, height: 100),
    );
    await t.pumpAndSettle();
    expect(_rect(t).bottom, 350);
  });
}
