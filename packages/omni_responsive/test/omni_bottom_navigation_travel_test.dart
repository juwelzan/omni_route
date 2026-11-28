import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';
import 'package:omni_responsive/src/widgets/bottom_navigation/omni_bottom_navigation.dart'
    as internal;

const _items = [
  OmniBottomNavigationItem(icon: Icon(Icons.home_outlined), label: 'A'),
  OmniBottomNavigationItem(icon: Icon(Icons.explore_outlined), label: 'B'),
  OmniBottomNavigationItem(icon: Icon(Icons.wallet_outlined), label: 'C'),
  OmniBottomNavigationItem(icon: Icon(Icons.chat_outlined), label: 'D'),
  OmniBottomNavigationItem(icon: Icon(Icons.person_outline), label: 'E'),
];

/// Indicator position reconstructed from the per-item selection progress the
/// bar hands to `itemBuilder` (`1 - |travel - i|`, clamped).
class _TravelProbe {
  final progress = <int, double>{};

  Widget build(
    BuildContext context,
    OmniBottomNavigationItem item,
    bool selected,
    double p,
  ) {
    progress[_items.indexOf(item)] = p;
    return Center(child: Text(item.label));
  }

  double get travel {
    var sum = 0.0;
    var weight = 0.0;
    progress.forEach((i, p) {
      sum += i * p;
      weight += p;
    });
    return weight == 0 ? double.nan : sum / weight;
  }
}

Future<List<double>> _record(WidgetTester t, _TravelProbe probe) async {
  final frames = <double>[];
  for (var i = 0; i < 40; i++) {
    await t.pump(const Duration(milliseconds: 16));
    frames.add(probe.travel);
  }
  return frames;
}

void main() {
  testWidgets('4 → 3 → 2 never overshoots into tab 1 or jumps back', (t) async {
    final probe = _TravelProbe();
    final controller = OmniBottomNavigationController(initialIndex: 4);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            controller: controller,
            itemBuilder: probe.build,
            items: _items,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(probe.travel, closeTo(4, 1e-9));

    controller.select(3);
    await t.pump();
    await t.pump(const Duration(milliseconds: 90)); // mid-travel
    final interruptedAt = probe.travel;
    expect(interruptedAt, inExclusiveRange(3, 4));

    controller.select(2);
    final frames = await _record(t, probe);

    // Continues from where it was drawn: no backwards jump on retarget.
    expect(frames.first, lessThanOrEqualTo(interruptedAt + 1e-6));
    for (var i = 1; i < frames.length; i++) {
      final step = frames[i] - frames[i - 1];
      if (frames[i - 1] > 2.05) {
        expect(step, lessThanOrEqualTo(1e-6), reason: 'frame $i moved back');
      }
    }
    // The spring overshoot stays a small fraction of a tab.
    expect(frames.reduce((a, b) => a < b ? a : b), greaterThan(1.8));
    expect(frames.last, closeTo(2, 1e-6));
  });

  testWidgets('a long jump overshoots at most ~0.14 of a tab', (t) async {
    final probe = _TravelProbe();
    final controller = OmniBottomNavigationController(initialIndex: 4);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            controller: controller,
            itemBuilder: probe.build,
            items: _items,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    controller.select(1);
    final frames = await _record(t, probe);
    expect(frames.reduce((a, b) => a < b ? a : b), greaterThan(1 - 0.15));
    expect(frames.last, closeTo(1, 1e-6));
  });

  testWidgets('sliding pill glides over the centre action, no teleport', (
    t,
  ) async {
    final controller = OmniBottomNavigationController(initialIndex: 3);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: OmniBottomNavigationBar(
            style: OmniBottomNavigationStyle.slidingPill,
            controller: controller,
            centerAction: OmniBottomNavigationAction(
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
            items: _items.take(4).toList(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final pill = find.byWidgetPredicate(
      (w) => w is Positioned && w.top == 2 && w.bottom == 2,
    );
    double pillCenter() {
      final p = t.widget<Positioned>(pill);
      return p.left! + p.width! / 2;
    }

    final start = pillCenter();
    controller.select(1); // right side → left side, across the action
    await t.pump();
    final centres = <double>[start];
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 16));
      centres.add(pillCenter());
    }
    final slot = (start - centres.last) / 3; // 3 slots from D to B
    for (var i = 1; i < centres.length; i++) {
      expect(
        (centres[i] - centres[i - 1]).abs(),
        lessThan(slot * 0.8),
        reason: 'frame $i jumped',
      );
    }
  });

  testWidgets('route bars: a new page continues from the previous tab', (
    t,
  ) async {
    const routeItems = [
      OmniBottomNavigationItem(
        icon: Icon(Icons.home_outlined),
        label: 'A',
        routePath: '/a',
      ),
      OmniBottomNavigationItem(
        icon: Icon(Icons.explore_outlined),
        label: 'B',
        routePath: '/b',
      ),
      OmniBottomNavigationItem(
        icon: Icon(Icons.wallet_outlined),
        label: 'C',
        routePath: '/c',
      ),
    ];
    final seen = <double>[];
    final seenA = <double>[];
    Widget page(String location) => MaterialApp(
      home: internal.OmniRouteNavigationBridge(
        currentLocation: location,
        onNavigate: null,
        child: Scaffold(
          key: ValueKey(location), // a fresh bar state per page
          bottomNavigationBar: OmniBottomNavigationBar(
            items: routeItems,
            itemBuilder: (context, item, selected, p) {
              if (item.label == 'B') seen.add(p);
              if (item.label == 'A') seenA.add(p);
              return Text(item.label);
            },
          ),
        ),
      ),
    );

    await t.pumpWidget(page('/c'));
    await t.pumpAndSettle();
    seen.clear();
    seenA.clear();

    // New page at /b: the indicator slides in from C (B's progress grows from
    // 0), it does not start at tab 0 nor snap.
    await t.pumpWidget(page('/b'));
    await t.pump(const Duration(milliseconds: 40));
    expect(seen.first, lessThan(0.5));
    await t.pumpAndSettle();
    expect(seen.last, closeTo(1, 1e-6));
    expect(
      seenA.every((p) => p < 0.2),
      isTrue,
      reason: 'never swept in from tab 0',
    );
  });

  testWidgets('reduce motion snaps the indicator', (t) async {
    final probe = _TravelProbe();
    final controller = OmniBottomNavigationController(initialIndex: 0);
    addTearDown(controller.dispose);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: OmniBottomNavigationBar(
              controller: controller,
              itemBuilder: probe.build,
              items: _items,
            ),
          ),
        ),
      ),
    );
    controller.select(3);
    await t.pump();
    expect(probe.travel, closeTo(3, 1e-9));
  });
}
