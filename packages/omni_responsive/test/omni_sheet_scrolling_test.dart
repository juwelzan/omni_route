import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _list = Key('list');
const _header = Key('header');

Widget _rows(BuildContext _) => ListView(
  key: _list,
  children: [
    for (var i = 0; i < 60; i++) SizedBox(height: 50, child: Text('row $i')),
  ],
);

Widget _page({
  OmniScalableSheetController? controller,
  OmniSheetScrolling scrolling = const OmniSheetScrolling(),
  OmniSheetStyle style = OmniSheetStyle.material,
  int initialDetent = 1,
  bool showHandle = false,
  WidgetBuilder builder = _rows,
  TransitionBuilder? appBuilder,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme,
  builder: appBuilder,
  home: Scaffold(
    body: OmniScalableSheet(
      controller: controller,
      style: style,
      showHandle: showHandle,
      animateOnOpen: false,
      scrolling: scrolling,
      detents: const [
        OmniSheetDetent.height(140),
        OmniSheetDetent.medium,
        OmniSheetDetent.large,
      ],
      initialDetent: initialDetent,
      header: (_) => const SizedBox(
        key: _header,
        height: 48,
        child: Center(child: Text('Header')),
      ),
      body: const SizedBox.expand(),
      builder: builder,
    ),
  ),
);

double _sheetTop(WidgetTester t) => t.getTopLeft(find.byKey(_header)).dy;

double _scrollOffset(WidgetTester t) =>
    t.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

double _scrollOffsetWithin(WidgetTester t, Key key) => t
    .state<ScrollableState>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
          .first,
    )
    .position
    .pixels;

List<double> _scrollOffsetsWithin(WidgetTester t, Key key) => find
    .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
    .evaluate()
    .map(
      (element) => ((element as StatefulElement).state as ScrollableState)
          .position
          .pixels,
    )
    .toList();

double _separatorOpacity(WidgetTester t) => t
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(OmniScalableSheet),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Future<void> _scrollList(WidgetTester t, double by) async {
  await t.timedDragFrom(
    const Offset(400, 400),
    Offset(0, -by),
    const Duration(milliseconds: 600),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('pinned header: separator shows while the list is scrolled', (
    t,
  ) async {
    await t.pumpWidget(_page(initialDetent: 2));
    await t.pumpAndSettle();
    expect(_separatorOpacity(t), 0);

    await _scrollList(t, 200);
    expect(_scrollOffset(t), greaterThan(0));
    expect(_separatorOpacity(t), 1);
    expect(OmniSheet.of(t.element(find.byKey(_list))).isScrolled.value, isTrue);
  });

  testWidgets('dragging the header moves the sheet, not the list', (t) async {
    await t.pumpWidget(_page(initialDetent: 2));
    await t.pumpAndSettle();
    await _scrollList(t, 300);
    final offset = _scrollOffset(t);

    await t.timedDrag(
      find.byKey(_header),
      const Offset(0, 260),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_sheetTop(t), 300, reason: 'came down to medium');
    expect(_scrollOffset(t), offset, reason: 'list untouched');
  });

  testWidgets('collapsing to the smallest detent scrolls the list to top', (
    t,
  ) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_page(controller: controller, initialDetent: 2));
    await t.pumpAndSettle();
    await _scrollList(t, 300);
    expect(_scrollOffset(t), greaterThan(0));

    controller.collapse();
    await t.pumpAndSettle();
    expect(_scrollOffset(t), 0);
  });

  testWidgets('resetOnCollapse: false keeps the scroll position', (t) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _page(
        controller: controller,
        initialDetent: 2,
        scrolling: const OmniSheetScrolling(resetOnCollapse: false),
      ),
    );
    await t.pumpAndSettle();
    await _scrollList(t, 300);
    final offset = _scrollOffset(t);
    controller.collapse();
    await t.pumpAndSettle();
    expect(_scrollOffset(t), offset);
  });

  testWidgets('handle tap: scrolls to top first, then changes detent', (
    t,
  ) async {
    await t.pumpWidget(_page(initialDetent: 2, showHandle: true));
    await t.pumpAndSettle();
    await _scrollList(t, 300);

    // The handle sits right above the header.
    await t.tapAt(t.getTopLeft(find.byKey(_header)) - const Offset(-400, 18));
    await t.pumpAndSettle();
    expect(_scrollOffset(t), 0, reason: 'first tap: back to top');
    final top = _sheetTop(t);

    await t.tapAt(t.getTopLeft(find.byKey(_header)) - const Offset(-400, 18));
    await t.pumpAndSettle();
    expect(_sheetTop(t), isNot(top), reason: 'second tap: next detent');
  });

  testWidgets('expandBeforeScroll: false scrolls the list at any size', (
    t,
  ) async {
    await t.pumpWidget(
      _page(scrolling: const OmniSheetScrolling(expandBeforeScroll: false)),
    );
    await t.pumpAndSettle();
    final top = _sheetTop(t);
    await _scrollList(t, 150);
    expect(_sheetTop(t), top, reason: 'sheet stayed at medium');
    expect(_scrollOffset(t), greaterThan(0));
  });

  testWidgets('default: dragging the list up grows the sheet first', (t) async {
    await t.pumpWidget(_page());
    await t.pumpAndSettle();
    final top = _sheetTop(t);
    await _scrollList(t, 150);
    expect(_sheetTop(t), lessThan(top));
    expect(_scrollOffset(t), 0);
  });

  testWidgets('a drag that reaches the top hands the rest to the sheet', (
    t,
  ) async {
    await t.pumpWidget(_page(initialDetent: 2));
    await t.pumpAndSettle();
    await _scrollList(t, 120);
    expect(_scrollOffset(t), greaterThan(80));

    // One gesture: scrolls back to the top, then pulls the sheet down.
    await t.timedDragFrom(
      const Offset(400, 300),
      const Offset(0, 380),
      const Duration(milliseconds: 900),
    );
    await t.pumpAndSettle();
    expect(_scrollOffset(t), 0);
    expect(_sheetTop(t), greaterThan(0), reason: 'sheet followed');
  });

  testWidgets('adaptive physics: bounce for cupertino, clamp for material', (
    t,
  ) async {
    ScrollPhysics physicsIn(WidgetTester t) {
      final e = t.element(find.byKey(_list));
      return ScrollConfiguration.of(e).getScrollPhysics(e);
    }

    await t.pumpWidget(_page(style: OmniSheetStyle.cupertino));
    await t.pumpAndSettle();
    expect(physicsIn(t), isA<BouncingScrollPhysics>());

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_page());
    await t.pumpAndSettle();
    expect(physicsIn(t), isA<ClampingScrollPhysics>());

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      _page(
        scrolling: const OmniSheetScrolling(
          physics: OmniSheetScrollPhysics.bouncing,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(physicsIn(t), isA<BouncingScrollPhysics>());
  });

  testWidgets('haptic tick when a drag lands on another detent', (t) async {
    final calls = <String?>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String?);
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
    await t.pumpWidget(
      _page(scrolling: const OmniSheetScrolling(hapticFeedback: true)),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      find.byKey(_header),
      const Offset(0, -260),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(calls, ['HapticFeedbackType.selectionClick']);

    // A drag that returns to the same detent stays silent.
    await t.timedDrag(
      find.byKey(_header),
      const Offset(0, 40),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(calls, hasLength(1));
  });

  testWidgets('dragging the sheet closes the keyboard', (t) async {
    await t.pumpWidget(
      _page(
        appBuilder: (c, child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: 200)),
          child: child!,
        ),
        builder: (_) => const Align(
          alignment: Alignment.topCenter,
          child: TextField(autofocus: true),
        ),
      ),
    );
    await t.pumpAndSettle();
    bool fieldFocused() =>
        t.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
    expect(fieldFocused(), isTrue);

    await t.timedDrag(
      find.byKey(_header),
      const Offset(0, -60),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(fieldFocused(), isFalse);
  });

  testWidgets('modal sheets get the same header and scrolling', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold();
          },
        ),
      ),
    );
    showOmniBottomSheet<void>(
      context: ctx,
      style: OmniSheetStyle.cupertino,
      showHandle: false,
      detents: const [OmniSheetDetent.large],
      header: (_) => const SizedBox(key: _header, height: 48),
      builder: _rows,
    );
    await t.pumpAndSettle();
    final e = t.element(find.byKey(_list));
    expect(
      ScrollConfiguration.of(e).getScrollPhysics(e),
      isA<BouncingScrollPhysics>(),
    );
    await _scrollList(t, 200);
    expect(OmniSheet.of(e).isScrolled.value, isTrue);
  });

  testWidgets(
    'BS-09: dragging up to max then back down mid-gesture collapses smoothly',
    (t) async {
      await t.pumpWidget(
        _page(style: OmniSheetStyle.cupertino, initialDetent: 1),
      );
      await t.pumpAndSettle();
      // Cupertino reserves a 10px top gap, so medium = (600 - 10) * 0.5 = 295px
      // (top = 305px) and large top = 10px.
      expect(_sheetTop(t), 305);

      // Start inside the list and drag upward past full height,
      // scrolling the list slightly, then reverse downward in the SAME gesture.
      final g = await t.startGesture(const Offset(400, 450));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, -35));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_sheetTop(t), lessThanOrEqualTo(10));

      // Reverse downward continuously without lifting finger.
      for (var i = 0; i < 16; i++) {
        await g.moveBy(const Offset(0, 25));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(_scrollOffset(t), 0);
      expect(_sheetTop(t), greaterThan(10));

      await g.up();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'BS-06: popping modal sheet mid-scroll-drag causes no use-after-dispose',
    (t) async {
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      );
      showOmniBottomSheet<void>(
        context: ctx,
        style: OmniSheetStyle.material,
        showHandle: false,
        detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
        builder: _rows,
      );
      await t.pumpAndSettle();

      final g = await t.startGesture(const Offset(400, 450));
      await g.moveBy(const Offset(0, -350));
      await t.pump(const Duration(milliseconds: 20));
      await g.moveBy(const Offset(0, -40));
      await t.pump(const Duration(milliseconds: 20));

      // Close the sheet while scroll gesture is active, then finish/cancel gesture.
      OmniSheet.of(t.element(find.byKey(_list))).close();
      await t.pumpAndSettle();
      await g.up();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byKey(_list), findsNothing);
    },
  );

  testWidgets(
    'supports GridView, CustomScrollView, SingleChildScrollView, nested scrollables, and desktop PrimaryScrollController',
    (t) async {
      // 1. GridView
      await t.pumpWidget(
        _page(
          initialDetent: 1,
          builder: (_) => GridView.builder(
            key: _list,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 80,
            ),
            itemCount: 30,
            itemBuilder: (_, i) => Text('grid $i'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _scrollList(t, 450);
      expect(_sheetTop(t), 0);
      expect(_scrollOffset(t), greaterThan(0));

      // 2. CustomScrollView
      await t.pumpWidget(
        _page(
          initialDetent: 1,
          builder: (_) => CustomScrollView(
            key: _list,
            slivers: [
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (_, i) =>
                    SizedBox(height: 50, child: Text('sliver $i')),
              ),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      await _scrollList(t, 450);
      expect(_sheetTop(t), 0);
      expect(_scrollOffset(t), greaterThan(0));

      // 3. SingleChildScrollView on desktop (macOS) via PrimaryScrollController inheritance.
      await t.pumpWidget(
        _page(
          theme: ThemeData(platform: TargetPlatform.macOS),
          initialDetent: 1,
          builder: (_) => SingleChildScrollView(
            key: _list,
            child: Column(
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 50, child: Text('col $i')),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _scrollList(t, 450);
      expect(_sheetTop(t), 0);
      expect(_scrollOffset(t), greaterThan(0));

      // 4. Nested horizontal + inner vertical scrollables don't hijack vertical scroll lock incorrectly.
      await t.pumpWidget(
        _page(
          initialDetent: 2,
          builder: (_) => ListView(
            key: _list,
            children: [
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 10; i++)
                      SizedBox(width: 120, child: Text('h $i')),
                  ],
                ),
              ),
              for (var i = 0; i < 30; i++)
                SizedBox(height: 50, child: Text('v $i')),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.timedDrag(
        find.text('h 0'),
        const Offset(-100, 0),
        const Duration(milliseconds: 300),
      );
      await t.pumpAndSettle();
      expect(
        OmniSheet.of(t.element(find.byKey(_list))).isScrolled.value,
        isFalse,
      );
    },
  );

  testWidgets(
    'ListView, GridView, and CustomScrollView transfer remaining drag at detents',
    (t) async {
      final cases = <(String, WidgetBuilder)>[
        (
          'ListView',
          (_) => ListView(
            key: _list,
            children: [
              for (var i = 0; i < 60; i++)
                SizedBox(height: 50, child: Text('row $i')),
            ],
          ),
        ),
        (
          'GridView',
          (_) => GridView.builder(
            key: _list,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 80,
            ),
            itemCount: 60,
            itemBuilder: (_, i) => Text('grid $i'),
          ),
        ),
        (
          'CustomScrollView',
          (_) => CustomScrollView(
            key: _list,
            slivers: [
              SliverList.builder(
                itemCount: 60,
                itemBuilder: (_, i) =>
                    SizedBox(height: 50, child: Text('sliver $i')),
              ),
            ],
          ),
        ),
      ];

      for (final (name, builder) in cases) {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(_page(initialDetent: 1, builder: builder));
        await t.pumpAndSettle();

        await t.timedDragFrom(
          const Offset(400, 450),
          const Offset(0, -450),
          const Duration(milliseconds: 900),
        );
        await t.pumpAndSettle();
        expect(_sheetTop(t), 0, reason: '$name expanded to maximum');
        expect(
          _scrollOffsetWithin(t, _list),
          greaterThan(0),
          reason: '$name receives the remainder past maximum',
        );

        await t.timedDragFrom(
          const Offset(400, 450),
          const Offset(0, 650),
          const Duration(milliseconds: 1100),
        );
        await t.pumpAndSettle();
        expect(
          _scrollOffsetWithin(t, _list),
          0,
          reason: '$name returns to its top before collapsing the sheet',
        );
        expect(_sheetTop(t), 460, reason: '$name lets the sheet reach minimum');
      }
    },
  );

  testWidgets(
    'NestedScrollView scrolls its content and the sheet remains draggable',
    (t) async {
      const nested = Key('nested');
      const innerList = Key('nested-inner-list');

      await t.pumpWidget(
        _page(
          initialDetent: 1,
          builder: (_) => NestedScrollView(
            key: nested,
            headerSliverBuilder: (_, _) => [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
            body: ListView(
              key: innerList,
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 50, child: Text('nested row $i')),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.timedDrag(
        find.byKey(_header),
        const Offset(0, -350),
        const Duration(milliseconds: 700),
      );
      await t.pumpAndSettle();
      expect(_sheetTop(t), 0, reason: 'header drag expands the sheet');

      await t.timedDragFrom(
        const Offset(400, 450),
        const Offset(0, -450),
        const Duration(milliseconds: 900),
      );
      await t.pumpAndSettle();
      expect(
        _scrollOffsetsWithin(t, nested).any((pixels) => pixels > 0),
        isTrue,
        reason: 'NestedScrollView content scrolls inside the expanded sheet',
      );

      await t.timedDrag(
        find.byKey(_header),
        const Offset(0, 650),
        const Duration(milliseconds: 1100),
      );
      await t.pumpAndSettle();
      expect(_sheetTop(t), 460, reason: 'header drag reaches minimum');
    },
  );
}
