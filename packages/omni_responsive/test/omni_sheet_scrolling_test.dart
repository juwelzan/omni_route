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
}
