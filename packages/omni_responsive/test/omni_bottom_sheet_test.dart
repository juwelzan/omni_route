import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
      const BorderRadius.all(Radius.circular(36)),
    );
    expect(find.byType(OmniSheetCloseButton), findsOneWidget);
  });

  testWidgets('floating: iOS close button behavior, haptics, press scale & PopScope guard', (
    t,
  ) async {
    final haptics = <String?>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await t.pumpWidget(_app());
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.floating,
      title: 'Fee',
      builder: (_) => const SizedBox(key: _box, height: 200),
    );
    await t.pumpAndSettle();

    expect(find.text('Fee'), findsOneWidget);
    final closeBtn = find.byType(OmniSheetCloseButton);
    expect(closeBtn, findsOneWidget);

    // Pressing down scales the button smoothly like iOS UIButton before release.
    final g = await t.startGesture(t.getCenter(closeBtn));
    await t.pump(const Duration(milliseconds: 100));
    final pressedScale = t
        .widget<AnimatedScale>(
          find.descendant(of: closeBtn, matching: find.byType(AnimatedScale)),
        )
        .scale;
    expect(pressedScale, lessThan(1.0));
    await g.up();
    await t.pumpAndSettle();

    expect(haptics, contains('HapticFeedbackType.lightImpact'));
    expect(find.byKey(_box), findsNothing);

    // PopScope can block iOS close button dismissal just like swipe-to-dismiss.
    var guardCalls = 0;
    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.floating,
      title: 'Edit Note',
      builder: (_) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) guardCalls++;
        },
        child: const SizedBox(key: _box, height: 180),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(OmniSheetCloseButton));
    await t.pumpAndSettle();
    expect(guardCalls, 1);
    expect(find.byKey(_box), findsOneWidget);

    // Dismiss via controller cleanly and verify Floating adopts BouncingScrollPhysics.
    OmniSheet.of(t.element(find.byKey(_box))).close();
    await t.pumpAndSettle();

    showOmniBottomSheet<void>(
      context: _ctx,
      style: OmniSheetStyle.floating,
      showCloseButton: false,
      detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
      builder: (_) => ListView(
        children: const [SizedBox(key: _box, height: 120)],
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(OmniSheetCloseButton), findsNothing);
    final listEl = t.element(find.byKey(_box));
    expect(
      ScrollConfiguration.of(listEl).getScrollPhysics(listEl),
      isA<BouncingScrollPhysics>(),
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

  group('detent validation and mapping', () {
    test('runtime validation rejects invalid configurations', () {
      Widget dummy(BuildContext _) => const SizedBox();
      expect(
        () => OmniSheetRoute<void>(builder: dummy, detents: const []),
        throwsArgumentError,
      );
      expect(
        () => OmniSheetRoute<void>(
          builder: dummy,
          detents: const [OmniSheetDetent.content, OmniSheetDetent.medium],
        ),
        throwsArgumentError,
      );
      expect(
        () => OmniSheetRoute<void>(
          builder: dummy,
          detents: const [OmniSheetDetent.medium],
          initialDetent: 1,
        ),
        throwsRangeError,
      );
      expect(
        () => OmniSheetRoute<void>(
          builder: dummy,
          detents: const [OmniSheetDetent.medium],
          initialDetent: -1,
        ),
        throwsRangeError,
      );
      expect(
        () => OmniSheetRoute<void>(
          builder: dummy,
          detents: const [OmniSheetDetent.medium],
          maxWidth: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => OmniSheetRoute<void>(
          builder: dummy,
          detents: const [OmniSheetDetent.medium],
          cornerRadius: -4,
        ),
        throwsArgumentError,
      );
      expect(
        () => OmniSheetDetent.fraction(0.5),
        isNotNull,
      );
      expect(
        () => showOmniBottomSheet<void>(
          context: _ctx,
          builder: dummy,
          detents: const [],
        ),
        throwsArgumentError,
      );
    });

    testWidgets(
      'unsorted detents preserve caller initialDetent, detent ValueListenable, and snapTo',
      (t) async {
        await t.pumpWidget(_app());
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.material,
          showHandle: false,
          detents: const [OmniSheetDetent.large, OmniSheetDetent.medium],
          initialDetent: 0,
          builder: (_) => const SizedBox.expand(key: _box),
        );
        await t.pumpAndSettle();
        final sheet = OmniSheet.of(t.element(find.byKey(_box)));
        expect(sheet.detentCount, 2);
        expect(sheet.detent.value, 0);
        expect(_rect(t).top, 0);

        sheet.snapTo(1);
        await t.pumpAndSettle();
        expect(sheet.detent.value, 1);
        expect(_rect(t).top, 300);

        sheet.snapTo(0);
        await t.pumpAndSettle();
        expect(sheet.detent.value, 0);
        expect(_rect(t).top, 0);

        expect(() => sheet.snapTo(-1), throwsRangeError);
        expect(() => sheet.snapTo(2), throwsRangeError);
      },
    );

    testWidgets(
      'duplicate and equal-height detents map deterministically and cycle skips duplicates',
      (t) async {
        await t.pumpWidget(_app());
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.material,
          showHandle: false,
          detents: const [
            OmniSheetDetent.height(200),
            OmniSheetDetent.height(200),
            OmniSheetDetent.fraction(0.3333333333), // ~200 on 600px height
            OmniSheetDetent.large,
          ],
          initialDetent: 1,
          builder: (_) => const SizedBox.expand(key: _box),
        );
        await t.pumpAndSettle();
        final sheet = OmniSheet.of(t.element(find.byKey(_box)));
        expect(sheet.detentCount, 4);
        expect(sheet.detent.value, 1);
        expect(_rect(t).height, closeTo(200, 1));

        // Snapping to index 2 addresses the ~200px detent, not large!
        sheet.snapTo(2);
        await t.pumpAndSettle();
        expect(sheet.detent.value, 2);
        expect(_rect(t).height, closeTo(200, 1));

        // Snapping to index 3 reaches large (600).
        sheet.snapTo(3);
        await t.pumpAndSettle();
        expect(sheet.detent.value, 3);
        expect(_rect(t).top, 0);
      },
    );

    testWidgets(
      'orientation / height change swaps detent order while keeping active detent',
      (t) async {
        t.view.devicePixelRatio = 1.0;
        t.view.physicalSize = const Size(400, 800);
        addTearDown(() {
          t.view.resetPhysicalSize();
          t.view.resetDevicePixelRatio();
        });
        await t.pumpWidget(_app());
        // At 800px: height(360)=360, fraction(0.8)=640.
        // At 400px: height(360)=360, fraction(0.8)=320 (swapped!).
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.material,
          showHandle: false,
          detents: const [
            OmniSheetDetent.height(360),
            OmniSheetDetent.fraction(0.8),
          ],
          initialDetent: 0,
          builder: (_) => const SizedBox.expand(key: _box),
        );
        await t.pumpAndSettle();
        final sheet = OmniSheet.of(t.element(find.byKey(_box)));
        expect(sheet.detent.value, 0);
        expect(_rect(t).height, 360);

        // Rotate / resize to 400px tall (detents swap order).
        t.view.physicalSize = const Size(800, 400);
        await t.pumpAndSettle();
        expect(sheet.detent.value, 0);
        expect(_rect(t).height, 360, reason: 'kept height(360), did not jump to 320');
      },
    );
  });

  group('Phase 4 gesture, animation & render stability', () {
    testWidgets('BS-18: viewport/keyboard resize mid-animation retargets cleanly', (
      t,
    ) async {
      t.view.devicePixelRatio = 1.0;
      t.view.physicalSize = const Size(800, 600);
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(_app());

      showOmniBottomSheet<void>(
        context: _ctx,
        style: OmniSheetStyle.material,
        showHandle: false,
        detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
        initialDetent: 0,
        builder: (_) => const SizedBox.expand(key: _box),
      );
      await t.pumpAndSettle();
      expect(_rect(t).height, 300);

      // Snap to large, then shrink viewport mid-animation.
      OmniSheet.of(t.element(find.byKey(_box))).snapTo(1);
      await t.pump(const Duration(milliseconds: 40));
      t.view.physicalSize = const Size(800, 400);
      await t.pumpAndSettle();
      expect(_rect(t).height, 400, reason: 'retargeted to new large height');
      expect(t.takeException(), isNull);
    });

    testWidgets('BS-11: grabbing sheet mid-open does not jump downward', (
      t,
    ) async {
      await t.pumpWidget(_app());
      showOmniBottomSheet<void>(
        context: _ctx,
        style: OmniSheetStyle.material,
        showHandle: false,
        detents: const [OmniSheetDetent.height(240), OmniSheetDetent.large],
        initialDetent: 0,
        builder: (_) => const SizedBox.expand(key: _box),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 70));
      final topBeforeGrab = _rect(t).top;
      expect(topBeforeGrab, greaterThan(360));
      expect(topBeforeGrab, lessThan(600));

      final g = await t.startGesture(Offset(400, topBeforeGrab + 20));
      await g.moveBy(const Offset(0, -10));
      await t.pump();
      expect(
        _rect(t).top,
        lessThanOrEqualTo(topBeforeGrab),
        reason: 'visible top did not jump down below pre-grab visual position',
      );
      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('BS-07: material does not overshoot top and multi-detent top fling snaps instead of dismissing', (
      t,
    ) async {
      await t.pumpWidget(_app());
      showOmniBottomSheet<void>(
        context: _ctx,
        style: OmniSheetStyle.material,
        showHandle: false,
        detents: const [
          OmniSheetDetent.height(160),
          OmniSheetDetent.medium,
          OmniSheetDetent.large,
        ],
        initialDetent: 2,
        builder: (_) => const SizedBox.expand(key: _box),
      );
      await t.pumpAndSettle();
      expect(_rect(t).top, 0);

      // Downward fling of ~220px from top detent (600px -> ~380px) must snap
      // to medium/peek rather than dismissing the multi-detent sheet.
      await t.fling(find.byKey(_box), const Offset(0, 220), 1100);
      await t.pumpAndSettle();
      expect(find.byKey(_box), findsOneWidget);
      expect(_rect(t).top, greaterThan(0));
    });

    testWidgets('BS-02: zero-height content sheet drags safely without NaN', (
      t,
    ) async {
      await t.pumpWidget(_app());
      showOmniBottomSheet<void>(
        context: _ctx,
        style: OmniSheetStyle.cupertino,
        showHandle: false,
        builder: (_) => const SizedBox(key: _box, height: 0),
      );
      await t.pumpAndSettle();
      await t.dragFrom(const Offset(400, 595), const Offset(0, -40));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('Phase 5 route lifecycle, SafeArea, keyboard & a11y', () {
    testWidgets('close while route on top removes sheet only; repeated close is safe', (
      t,
    ) async {
      await t.pumpWidget(_app());
      final sheetFuture = showOmniBottomSheet<String>(
        context: _ctx,
        style: OmniSheetStyle.material,
        builder: (_) => const SizedBox(key: _box, height: 220),
      );
      await t.pumpAndSettle();
      final sheet = OmniSheet.of(t.element(find.byKey(_box)));

      // Push another route on top of the modal sheet.
      Navigator.of(_ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('top-page')),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('top-page'), findsOneWidget);

      // Programmatic close removes only the underlying sheet route, leaving top-page intact.
      sheet.close('underneath');
      sheet.close('ignored-second-call');
      await t.pumpAndSettle();
      expect(await sheetFuture, 'underneath');
      expect(find.text('top-page'), findsOneWidget);
      expect(find.byKey(_box), findsNothing);
    });

    testWidgets('programmatic close while dragging completes cleanly once', (
      t,
    ) async {
      await t.pumpWidget(_app());
      final sheetFuture = showOmniBottomSheet<String>(
        context: _ctx,
        style: OmniSheetStyle.material,
        builder: (_) => const SizedBox(key: _box, height: 240),
      );
      await t.pumpAndSettle();
      final sheet = OmniSheet.of(t.element(find.byKey(_box)));

      final g = await t.startGesture(const Offset(400, 500));
      await g.moveBy(const Offset(0, 40));
      await t.pump();

      sheet.close('closed-mid-drag');
      await g.up();
      await t.pumpAndSettle();
      expect(await sheetFuture, 'closed-mid-drag');
      expect(find.byKey(_box), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('nested navigator respects useRootNavigator and direct OmniSheetRoute localizes barrier', (
      t,
    ) async {
      late BuildContext nestedCtx;
      final observer = _CountingNavObserver();
      await t.pumpWidget(
        MaterialApp(
          home: Navigator(
            observers: [observer],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (c) {
                nestedCtx = c;
                return const Scaffold(body: Text('nested-home'));
              },
            ),
          ),
        ),
      );

      final future = showOmniBottomSheet<String>(
        context: nestedCtx,
        useRootNavigator: false,
        style: OmniSheetStyle.material,
        builder: (_) => const SizedBox(key: _box, height: 200),
      );
      await t.pumpAndSettle();
      expect(observer.pushed, greaterThanOrEqualTo(2));

      OmniSheet.of(t.element(find.byKey(_box))).close('nested-ok');
      await t.pumpAndSettle();
      expect(await future, 'nested-ok');

      // Direct OmniSheetRoute push preserves localized barrierLabel.
      final route = OmniSheetRoute<void>(
        style: OmniSheetStyle.material,
        builder: (_) => const SizedBox(key: _box, height: 180),
      );
      Navigator.of(nestedCtx).push(route);
      await t.pumpAndSettle();
      expect(route.barrierLabel, isNotEmpty);
    });

    testWidgets('PopScope blocks Escape and close button; close() still pops', (
      t,
    ) async {
      await t.pumpWidget(_app());
      final result = showOmniBottomSheet<String>(
        context: _ctx,
        style: OmniSheetStyle.floating,
        title: 'Locked',
        builder: (_) => PopScope(
          canPop: false,
          child: const SizedBox(key: _box, height: 200),
        ),
      );
      await t.pumpAndSettle();

      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byKey(_box), findsOneWidget);

      await t.tap(find.byType(OmniSheetCloseButton));
      await t.pumpAndSettle();
      expect(find.byKey(_box), findsOneWidget);

      OmniSheet.of(t.element(find.byKey(_box))).close('forced');
      await t.pumpAndSettle();
      expect(await result, 'forced');
    });

    testWidgets('Escape dismisses without autofocus child and Tab activates close button', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(_app());
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.floating,
          title: 'Accessible',
          detents: const [OmniSheetDetent.medium],
          builder: (_) => const SizedBox(key: _box, child: Text('Plain content')),
        );
        await t.pumpAndSettle();

        // Escape dismisses directly because FocusScope(autofocus: true) wraps the sheet.
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byKey(_box), findsNothing);

        // Open again and verify keyboard Tab + Enter activates the close button.
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.floating,
          title: 'Keyboard Close',
          detents: const [OmniSheetDetent.medium],
          builder: (_) => const SizedBox(key: _box, child: Text('Content')),
        );
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        // Close button or handle can be reached by Tab; explicitly focus close button
        // via primaryFocus traversal until close button node has focus, then press Enter.
        for (var i = 0; i < 6; i++) {
          final ctx = FocusManager.instance.primaryFocus?.context;
          if (ctx?.findAncestorWidgetOfExactType<OmniSheetCloseButton>() != null ||
              ctx?.widget is OmniSheetCloseButton) {
            break;
          }
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pump();
        }
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.byKey(_box), findsNothing);

        // Non-dismissible single detent handle is excluded from button/dismiss semantics.
        showOmniBottomSheet<void>(
          context: _ctx,
          style: OmniSheetStyle.material,
          isDismissible: false,
          showHandle: true,
          detents: const [OmniSheetDetent.medium],
          builder: (_) => const SizedBox(key: _box, height: 120),
        );
        await t.pumpAndSettle();
        expect(_hasCompiledSemanticsLabel(t, 'Dismiss'), isFalse);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('SafeArea, landscape cutouts, keyboard smoothness, RTL and large text scaling render without overflow across styles', (
      t,
    ) async {
      for (final style in [
        OmniSheetStyle.material,
        OmniSheetStyle.cupertino,
        OmniSheetStyle.floating,
      ]) {
        final insets = ValueNotifier<double>(0);
        addTearDown(insets.dispose);
        await t.pumpWidget(
          ValueListenableBuilder<double>(
            valueListenable: insets,
            builder: (_, kb, _) => MaterialApp(
              builder: (_, child) => MediaQuery(
                data: MediaQueryData(
                  size: const Size(700, 420),
                  padding: const EdgeInsets.only(left: 48, right: 16, bottom: 24),
                  viewInsets: EdgeInsets.only(bottom: kb),
                  textScaler: const TextScaler.linear(2.5),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: Builder(
                builder: (c) {
                  _ctx = c;
                  return const Scaffold(body: SizedBox.expand());
                },
              ),
            ),
          ),
        );

        showOmniBottomSheet<void>(
          context: _ctx,
          style: style,
          title: 'Very Long Scaled Sheet Header Title',
          showCloseButton: true,
          builder: (_) => ListView(
            key: _box,
            children: const [
              TextField(decoration: InputDecoration(labelText: 'First')),
              TextField(decoration: InputDecoration(labelText: 'Bottom Field')),
            ],
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$style open overflow check');
        // Left cutout clearance: sheet rect left >= 48.
        expect(
          _rect(t).left,
          greaterThanOrEqualTo(48),
          reason: '$style clears left landscape cutout',
        );

        // Keyboard smoothly ramps from 0 -> 12 -> 180 -> 0 without overflow.
        insets.value = 12;
        await t.pump();
        insets.value = 180;
        await t.pumpAndSettle();
        insets.value = 0;
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '$style keyboard cycle check');

        OmniSheet.of(t.element(find.byKey(_box))).close();
        await t.pumpAndSettle();
      }
    });
  });
}

class _CountingNavObserver extends NavigatorObserver {
  int pushed = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed++;
  }
}

bool _hasCompiledSemanticsLabel(WidgetTester t, String label) {
  var found = false;
  void visitSemantics(SemanticsNode node) {
    if (node.label == label) found = true;
    node.visitChildren((child) {
      visitSemantics(child);
      return !found;
    });
  }
  void visitPipeline(PipelineOwner owner) {
    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) visitSemantics(root);
    if (!found) owner.visitChildren(visitPipeline);
  }
  visitPipeline(t.binding.rootPipelineOwner);
  return found;
}
