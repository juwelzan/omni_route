import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _box = Key('box');
const _peek = OmniSheetDetent.height(140);

Rect _rect(WidgetTester t) => t.getRect(find.byKey(_box));

Widget _page({
  OmniScalableSheetController? controller,
  OmniSheetStyle style = OmniSheetStyle.material,
  List<OmniSheetDetent> detents = const [
    _peek,
    OmniSheetDetent.medium,
    OmniSheetDetent.large,
  ],
  int initialDetent = 1,
  bool animateOnOpen = true,
  bool isDismissible = false,
  int? dimFromDetent,
  ValueChanged<int>? onDetentChanged,
  VoidCallback? onDismissed,
  VoidCallback? onBodyTap,
  WidgetBuilder? builder,
  PreferredSizeWidget? appBar,
}) => MaterialApp(
  home: Scaffold(
    appBar: appBar,
    body: OmniScalableSheet(
      controller: controller,
      style: style,
      showHandle: false,
      detents: detents,
      initialDetent: initialDetent,
      animateOnOpen: animateOnOpen,
      isDismissible: isDismissible,
      dimFromDetent: dimFromDetent,
      onDetentChanged: onDetentChanged,
      onDismissed: onDismissed,
      body: Align(
        alignment: Alignment.topCenter,
        child: TextButton(
          onPressed: onBodyTap ?? () {},
          child: const Text('page button'),
        ),
      ),
      builder: builder ?? (_) => const SizedBox.expand(key: _box),
    ),
  ),
);

void main() {
  testWidgets('opens at the initial size, the page stays usable', (t) async {
    var taps = 0;
    await t.pumpWidget(_page(onBodyTap: () => taps++));
    await t.pump(const Duration(milliseconds: 60));
    expect(_rect(t).top, greaterThan(300), reason: 'sliding up');
    await t.pumpAndSettle();
    expect(_rect(t).top, 300, reason: 'medium of 600');

    await t.tap(find.text('page button'));
    expect(taps, 1);
  });

  testWidgets('without animateOnOpen it is in place on the first frame', (
    t,
  ) async {
    await t.pumpWidget(_page(animateOnOpen: false, initialDetent: 0));
    expect(_rect(t).top, 600 - 140);
  });

  testWidgets('snaps to detents and is held between the smallest and largest', (
    t,
  ) async {
    await t.pumpWidget(_page());
    await t.pumpAndSettle();

    // A long drag down stops at the peek size (not dismissible).
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 280),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 600 - 140);

    // Further down: stretches, then springs back to the peek.
    await t.timedDragFrom(
      const Offset(400, 520),
      const Offset(0, 70),
      const Duration(milliseconds: 500),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 600 - 140);

    // A fling up goes to the next detent up the way it is thrown.
    await t.fling(find.byKey(_box), const Offset(0, -150), 1200);
    await t.pumpAndSettle();
    expect(_rect(t).top, anyOf(300.0, 0.0));
    await t.fling(find.byKey(_box), const Offset(0, -150), 2500);
    await t.pumpAndSettle();
    expect(_rect(t).top, 0, reason: 'never past the largest');
  });

  testWidgets('controller: snapTo, expand, collapse, detent and height', (
    t,
  ) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    final changes = <int>[];
    await t.pumpWidget(
      _page(controller: controller, onDetentChanged: changes.add),
    );
    await t.pumpAndSettle();
    expect(controller.detent.value, 1);
    expect(controller.height.value, 300);

    controller.expand();
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
    expect(controller.detent.value, 2);
    expect(controller.height.value, 600);

    controller.collapse();
    await t.pumpAndSettle();
    expect(_rect(t).top, 600 - 140);
    expect(controller.detent.value, 0);

    controller.snapTo(1);
    await t.pumpAndSettle();
    expect(_rect(t).top, 300);
    expect(changes, [1, 2, 0, 1]);
  });

  testWidgets('hide and show; a dismissible sheet can be dragged away', (
    t,
  ) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    var dismissed = 0;
    await t.pumpWidget(
      _page(
        controller: controller,
        isDismissible: true,
        initialDetent: 0,
        onDismissed: () => dismissed++,
      ),
    );
    await t.pumpAndSettle();

    controller.hide();
    await t.pumpAndSettle();
    expect(controller.isShown.value, isFalse);
    expect(find.byKey(_box).hitTestable(), findsNothing);

    controller.show();
    await t.pumpAndSettle();
    expect(_rect(t).top, 600 - 140);

    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, 120),
      const Duration(milliseconds: 500),
    );
    await t.pumpAndSettle();
    expect(dismissed, 1);
    expect(controller.isShown.value, isFalse);
  });

  testWidgets('floating style keeps its margins on the page', (t) async {
    await t.pumpWidget(_page(style: OmniSheetStyle.floating, initialDetent: 0));
    await t.pumpAndSettle();
    final r = _rect(t);
    expect(r.bottom, 590);
    expect(r.height, 140);
    expect(r.width, 560);
  });

  testWidgets('dims past a detent; a tap on the dimmed page collapses', (
    t,
  ) async {
    var taps = 0;
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _page(controller: controller, dimFromDetent: 1, onBodyTap: () => taps++),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('page button'));
    expect(taps, 1, reason: 'not dimmed at medium');

    controller.expand();
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 600 - 5)); // inside the sheet: ignored
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);

    controller.snapTo(1);
    await t.pumpAndSettle();
    controller.expand();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
  });

  testWidgets('tapping the dimmed page above a shorter top collapses', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      _page(
        detents: const [_peek, OmniSheetDetent.fraction(0.8)],
        initialDetent: 1,
        dimFromDetent: 0,
        onBodyTap: () => taps++,
      ),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 120);
    await t.tap(find.text('page button'), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(taps, 0, reason: 'the dim layer took the tap');
    expect(_rect(t).top, 600 - 140, reason: 'collapsed');
    await t.tap(find.text('page button'));
    expect(taps, 1, reason: 'undimmed again');
  });

  testWidgets('back collapses an expanded sheet before leaving', (t) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    await t.pumpWidget(_page(controller: controller));
    await t.pumpAndSettle();
    controller.expand();
    await t.pumpAndSettle();

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_rect(t).top, 600 - 140);
    expect(controller.detent.value, 0);
  });

  testWidgets('a list inside expands the sheet before scrolling', (t) async {
    await t.pumpWidget(
      _page(
        builder: (_) => ListView(
          key: _box,
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 50, child: Text('row $i')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      find.text('row 1'),
      const Offset(0, -320),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 0);
    expect(find.text('row 0'), findsOneWidget);
  });

  testWidgets('drags never rebuild the content; a parent rebuild does', (
    t,
  ) async {
    var builds = 0;
    final label = ValueNotifier('one');
    addTearDown(label.dispose);
    await t.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: label,
        builder: (_, text, _) => _page(
          builder: (_) {
            builds++;
            return SizedBox.expand(key: _box, child: Text(text));
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final first = builds;
    await t.timedDrag(
      find.byKey(_box),
      const Offset(0, -200),
      const Duration(milliseconds: 500),
    );
    await t.pumpAndSettle();
    expect(builds, first);

    label.value = 'two';
    await t.pump();
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('stays inside the Scaffold body under an app bar', (t) async {
    await t.pumpWidget(
      _page(appBar: AppBar(title: const Text('Map')), initialDetent: 2),
    );
    await t.pumpAndSettle();
    expect(_rect(t).top, 56, reason: 'large = the body, below the app bar');
  });

  testWidgets(
    'widgets listening to height rebuild safely (no build in layout)',
    (t) async {
      final controller = OmniScalableSheetController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniScalableSheet(
              controller: controller,
              animateOnOpen: false,
              detents: const [_peek, OmniSheetDetent.large],
              body: AnimatedBuilder(
                animation: controller.height,
                builder: (_, _) => Text('h=${controller.height.value.round()}'),
              ),
              builder: (_) => const SizedBox.expand(key: _box),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('h=140'), findsOneWidget);
      controller.expand();
      await t.pumpAndSettle();
      expect(find.text('h=600'), findsOneWidget);
    },
  );

  testWidgets(
    'unsorted detents work with expand, collapse, dimFromDetent, and back button',
    (t) async {
      final controller = OmniScalableSheetController();
      addTearDown(controller.dispose);
      final changes = <int>[];
      await t.pumpWidget(
        _page(
          controller: controller,
          detents: const [OmniSheetDetent.large, OmniSheetDetent.medium, _peek],
          initialDetent: 0, // large
          dimFromDetent: 1, // medium -> dims above medium
          onDetentChanged: changes.add,
        ),
      );
      await t.pumpAndSettle();
      expect(controller.detent.value, 0);
      expect(_rect(t).top, 0);

      // Back collapses to smallest detent (index 2 = _peek).
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(controller.detent.value, 2);
      expect(_rect(t).top, 600 - 140);

      controller.expand();
      await t.pumpAndSettle();
      expect(controller.detent.value, 0);
      expect(_rect(t).top, 0);

      controller.collapse();
      await t.pumpAndSettle();
      expect(controller.detent.value, 2);
      expect(_rect(t).top, 600 - 140);
      expect(changes, [0, 2, 0, 2]);
    },
  );

  testWidgets('dynamic detent changes remap active detent safely', (t) async {
    final controller = OmniScalableSheetController();
    addTearDown(controller.dispose);
    final detents = ValueNotifier<List<OmniSheetDetent>>(const [
      _peek,
      OmniSheetDetent.large,
    ]);
    addTearDown(detents.dispose);

    await t.pumpWidget(
      ValueListenableBuilder<List<OmniSheetDetent>>(
        valueListenable: detents,
        builder: (_, list, _) => _page(
          controller: controller,
          detents: list,
          initialDetent: 1, // large
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(controller.detent.value, 1);
    expect(_rect(t).top, 0);

    // Insert medium in the middle -> large moves to index 2.
    detents.value = const [
      _peek,
      OmniSheetDetent.medium,
      OmniSheetDetent.large,
    ];
    await t.pumpAndSettle();
    expect(controller.detent.value, 2);
    expect(_rect(t).top, 0);
  });

  testWidgets(
    'hide, show, and expand keep isShown synchronized and floating sheet clips bounds',
    (t) async {
      final controller = OmniScalableSheetController();
      addTearDown(controller.dispose);
      var bodyTaps = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniScalableSheet(
              controller: controller,
              animateOnOpen: false,
              style: OmniSheetStyle.floating,
              detents: const [_peek, OmniSheetDetent.large],
              initialDetent: 0,
              body: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                  onPressed: () => bodyTaps++,
                  child: const Text('bg tap'),
                ),
              ),
              builder: (_) => const SizedBox.expand(key: _box),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(controller.isShown.value, isTrue);

      controller.hide();
      await t.pumpAndSettle();
      expect(controller.isShown.value, isFalse);

      // Tapping above the hidden sheet hits the underlying page cleanly.
      await t.tap(find.text('bg tap'));
      expect(bodyTaps, 1);

      controller.show();
      await t.pumpAndSettle();
      expect(controller.isShown.value, isTrue);
      expect(_rect(t).bottom, lessThanOrEqualTo(600));
    },
  );

  testWidgets('hidden scalable sheet is excluded from semantics and focus', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    try {
      final controller = OmniScalableSheetController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniScalableSheet(
              controller: controller,
              animateOnOpen: false,
              detents: const [_peek, OmniSheetDetent.large],
              initialDetent: 0,
              body: const Text('Page Body'),
              builder: (_) => TextButton(
                onPressed: () {},
                child: const Text('Sheet Action'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(_hasCompiledSemanticsLabel(t, 'Sheet Action'), isTrue);

      controller.hide();
      await t.pumpAndSettle();
      expect(_hasCompiledSemanticsLabel(t, 'Sheet Action'), isFalse);
      expect(_hasCompiledSemanticsLabel(t, 'Page Body'), isTrue);

      // Focus traversal skips hidden sheet children when hidden.
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TextButton>(),
        isNull,
      );

      controller.show();
      await t.pumpAndSettle();
      expect(_hasCompiledSemanticsLabel(t, 'Sheet Action'), isTrue);
    } finally {
      semantics.dispose();
    }
  });
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
