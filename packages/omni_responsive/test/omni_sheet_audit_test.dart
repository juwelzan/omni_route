import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_responsive/omni_responsive.dart';

const _header = Key('header');

void main() {
  testWidgets('a vetoed drag-dismiss that opens a dialog springs back', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showOmniBottomSheet<void>(
                  context: context,
                  style: OmniSheetStyle.material,
                  detents: const [OmniSheetDetent.medium],
                  builder: (sheetContext) => PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      if (didPop) return;
                      showDialog<void>(
                        context: sheetContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Discard?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Keep'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const SizedBox.expand(
                      child: Center(child: Text('Sheet body')),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final openTop = t.getTopLeft(find.text('Sheet body')).dy;

    await t.timedDrag(
      find.text('Sheet body'),
      const Offset(0, 300),
      const Duration(milliseconds: 300),
    );
    await t.pumpAndSettle();
    expect(find.text('Discard?'), findsOneWidget);
    // Behind the dialog the sheet is back in place, not stuck half-way.
    expect(t.getTopLeft(find.text('Sheet body')).dy, closeTo(openTop, 1));

    await t.tap(find.text('Keep'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('Sheet body')).dy, closeTo(openTop, 1));
  });

  testWidgets('header state survives the list scrolling (frosted styles)', (
    t,
  ) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmniScalableSheet(
            style: OmniSheetStyle.cupertino,
            animateOnOpen: false,
            detents: const [OmniSheetDetent.large],
            header: (_) => SizedBox(
              key: _header,
              height: 56,
              child: TextField(controller: text),
            ),
            body: const SizedBox.expand(),
            builder: (_) => ListView(
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 50, child: Text('row $i')),
              ],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byType(TextField));
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump();
    final field = t.state<EditableTextState>(find.byType(EditableText));

    await t.drag(find.text('row 5'), const Offset(0, -300));
    await t.pumpAndSettle();

    expect(
      t.state<EditableTextState>(find.byType(EditableText)),
      same(field),
      reason: 'the header subtree must not be re-created when scrolled',
    );
  });

  testWidgets('a reversed (chat) list scrolls instead of moving the sheet', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OmniScalableSheet(
            style: OmniSheetStyle.material,
            animateOnOpen: false,
            detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
            initialDetent: 1,
            header: (_) => const SizedBox(key: _header, height: 40),
            body: const SizedBox.expand(),
            builder: (_) => ListView(
              reverse: true,
              children: [
                for (var i = 0; i < 60; i++)
                  SizedBox(height: 50, child: Text('msg $i')),
              ],
            ),
          ),
        ),
      ),
    );
    final top = t.getTopLeft(find.byKey(_header)).dy;
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;

    // At the newest message, a finger moving up must not drag the sheet
    // down (it used to: the reversed list's "top" was taken for the start).
    await t.drag(find.text('msg 2'), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(_header)).dy, closeTo(top, 1));

    // Finger down reveals older messages; the sheet stays.
    await t.drag(find.text('msg 2'), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(position.pixels, greaterThan(100));
    expect(t.getTopLeft(find.byKey(_header)).dy, closeTo(top, 1));

    // And back up to the newest, past the end: still only scrolls.
    await t.drag(find.text('msg 8'), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(position.pixels, closeTo(0, 0.5));
    expect(t.getTopLeft(find.byKey(_header)).dy, closeTo(top, 1));
  });
}
