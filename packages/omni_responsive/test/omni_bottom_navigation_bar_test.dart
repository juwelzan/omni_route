import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

List<OmniBottomNavigationItem> _sampleItems({bool withBadges = false}) => [
  OmniBottomNavigationItem(
    icon: const Icon(Icons.home_outlined),
    selectedIcon: const Icon(Icons.home_rounded),
    label: 'Home',
    activeColor: const Color(0xFF2563EB),
    badgeCount: withBadges ? 4 : null,
  ),
  OmniBottomNavigationItem(
    icon: const Icon(Icons.explore_outlined),
    selectedIcon: const Icon(Icons.explore_rounded),
    label: 'Explore',
    activeColor: const Color(0xFF7C3AED),
    showDotBadge: withBadges,
  ),
  OmniBottomNavigationItem(
    icon: const Icon(Icons.chat_bubble_outline_rounded),
    selectedIcon: const Icon(Icons.chat_bubble_rounded),
    label: 'Inbox',
    activeColor: const Color(0xFF059669),
    badgeCount: withBadges ? 140 : null,
  ),
  OmniBottomNavigationItem(
    icon: const Icon(Icons.person_outline_rounded),
    selectedIcon: const Icon(Icons.person_rounded),
    label: 'Profile',
    activeColor: const Color(0xFFD97706),
    badgeText: withBadges ? 'NEW' : null,
  ),
];

void main() {
  testWidgets(
    'controller validation clamps negative, out-of-range, and valid indexes',
    (t) async {
      final controller = OmniBottomNavigationController(initialIndex: -5);
      addTearDown(controller.dispose);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: OmniBottomNavigationBar(
              controller: controller,
              items: _sampleItems(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(controller.index, 0);

      controller.select(-10);
      await t.pump();
      expect(controller.index, 0);

      controller.select(99);
      await t.pump();
      expect(controller.index, 3);

      controller.select(2);
      await t.pump();
      expect(controller.index, 2);

      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.select(2);
      await t.pump();
      expect(notifications, 0);
      controller.select(1);
      await t.pump();
      expect(notifications, 1);
    },
  );

  testWidgets('controller index is clamped when the item count shrinks', (
    t,
  ) async {
    final controller = OmniBottomNavigationController(initialIndex: 3);
    addTearDown(controller.dispose);
    var items = _sampleItems();

    await t.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: OmniBottomNavigationBar(
              controller: controller,
              items: items,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(controller.index, 3);

    items = _sampleItems().take(1).toList();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            controller: controller,
            items: items,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(controller.index, 0);
  });

  testWidgets('item validation: empty list renders nothing safely', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            items: const [],
            currentIndex: 10,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.byType(OmniBottomNavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OmniBottomNavigationBar),
        matching: find.byType(IgnorePointer),
      ),
      findsNothing,
    );
  });

  testWidgets('item validation: one item is rendered at index zero', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            items: const [
              OmniBottomNavigationItem(
                icon: Icon(Icons.home_outlined),
                label: 'Only',
              ),
            ],
            currentIndex: 20,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.text('Only'), findsOneWidget);
  });

  testWidgets('item validation: normal item list remains unchanged', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            items: _sampleItems(),
            currentIndex: 1,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.text('Explore'), findsOneWidget);
  });

  testWidgets('renders all 12 CollectUI styles without layout overflow', (
    t,
  ) async {
    for (final style in OmniBottomNavigationStyle.values) {
      var selected = 0;
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 720)),
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                extendBody: true,
                body: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (_, i) => ListTile(title: Text('Row $i')),
                ),
                bottomNavigationBar: OmniBottomNavigationBar(
                  style: style,
                  currentIndex: selected,
                  onTap: (i) => setState(() => selected = i),
                  centerAction:
                      style == OmniBottomNavigationStyle.centerFabNotch ||
                          style == OmniBottomNavigationStyle.splitIsland
                      ? OmniBottomNavigationAction(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          tooltip: 'Scan',
                          onPressed: () {},
                        )
                      : null,
                  items: _sampleItems(
                    withBadges: style == OmniBottomNavigationStyle.floating,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(t.takeException(), isNull, reason: 'No overflow on $style');
      await t.tap(find.byIcon(Icons.explore_outlined));
      await t.pumpAndSettle();
      expect(selected, 1, reason: 'Tab 1 selected cleanly in $style');
    }
  });

  testWidgets(
    'floatingBubble expands selected item label and switches cleanly',
    (t) async {
      var selected = 0;
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: OmniBottomNavigationBar(
                style: OmniBottomNavigationStyle.floatingBubble,
                currentIndex: selected,
                onTap: (i) => setState(() => selected = i),
                items: _sampleItems(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsNothing);

      await t.tap(find.byIcon(Icons.explore_outlined));
      await t.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    },
  );

  testWidgets('centerFabNotch & splitIsland trigger centerAction callback', (
    t,
  ) async {
    for (final style in const [
      OmniBottomNavigationStyle.centerFabNotch,
      OmniBottomNavigationStyle.splitIsland,
    ]) {
      var fabCount = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: OmniBottomNavigationBar(
              style: style,
              currentIndex: 0,
              onTap: (_) {},
              centerAction: OmniBottomNavigationAction(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Create',
                onPressed: () => fabCount++,
              ),
              items: _sampleItems(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pumpAndSettle();
      expect(fabCount, 1, reason: 'centerAction tapped for $style');
    }
  });

  testWidgets('curvedNotch pops active orb, handles tap & RTL directionality', (
    t,
  ) async {
    var selected = 0;
    var reselected = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (_, setState) => Scaffold(
              extendBody: true,
              body: const SizedBox.expand(),
              bottomNavigationBar: OmniBottomNavigationBar(
                style: OmniBottomNavigationStyle.curvedNotch,
                currentIndex: selected,
                onTap: (i) => setState(() => selected = i),
                onReselect: (_) => reselected++,
                items: _sampleItems(),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    // Active tab 0 renders the elevated selected icon inside the orb.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.home_rounded));
    await t.pumpAndSettle();
    expect(reselected, 1);

    await t.tap(find.byIcon(Icons.person_outline_rounded));
    await t.pumpAndSettle();
    expect(selected, 3);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets(
    'glass renders BackdropFilter blur & custom Gradient themes work',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [
              OmniBottomNavigationStyleData(
                blurSigma: 22,
                backgroundOpacity: 0.72,
                indicatorGradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
              ),
            ],
          ),
          home: Scaffold(
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: OmniBottomNavigationBar(
              style: OmniBottomNavigationStyle.glass,
              currentIndex: 1,
              onTap: (_) {},
              items: _sampleItems(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    },
  );

  testWidgets('badges, labelMode, press scale, haptics & controller work', (
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

    final controller = OmniBottomNavigationController(initialIndex: 0);
    addTearDown(controller.dispose);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.slidingPill,
            labelMode: OmniBottomNavLabelMode.selectedOnly,
            controller: controller,
            items: _sampleItems(withBadges: true),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsNothing);

    await t.tap(find.byIcon(Icons.explore_outlined));
    await t.pumpAndSettle();
    expect(controller.index, 1);
    expect(find.text('Explore'), findsOneWidget);
    expect(haptics, contains('HapticFeedbackType.selectionClick'));

    controller.select(3);
    await t.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    controller.hide();
    await t.pumpAndSettle();
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    controller.show();
    await t.pumpAndSettle();
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets('hideOnScroll with one attached position slides bar on scroll', (
    t,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: ListView.builder(
            controller: scroll,
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Item $i')),
          ),
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.floating,
            scrollController: scroll,
            hideOnScroll: true,
            currentIndex: 0,
            onTap: (_) {},
            items: _sampleItems(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    scroll.jumpTo(300);
    await t.pumpAndSettle();
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    scroll.jumpTo(120);
    await t.pumpAndSettle();
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets('hideOnScroll safely handles multiple attached positions', (
    t,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: 40,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 60, child: Text('Left $i')),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: 40,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 60, child: Text('Right $i')),
                ),
              ),
            ],
          ),
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.floating,
            scrollController: scroll,
            hideOnScroll: true,
            currentIndex: 0,
            onTap: (_) {},
            items: _sampleItems(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(scroll.positions, hasLength(2));

    scroll.jumpTo(300);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    scroll.jumpTo(120);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      t
          .widget<IgnorePointer>(
            find
                .descendant(
                  of: find.byType(OmniBottomNavigationBar),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isFalse,
    );
  });

  testWidgets('hideOnKeyboard hides bar when soft keyboard opens', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: OmniBottomNavigationBar(
              style: OmniBottomNavigationStyle.floating,
              currentIndex: 0,
              onTap: (_) {},
              items: _sampleItems(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
  });
}
