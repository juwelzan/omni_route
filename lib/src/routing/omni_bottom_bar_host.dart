import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'omni_route_state.dart';

/// Signature for building an [OmniPage]-level bottom navigation bar from the
/// active [BuildContext] and matched [OmniRouteState].
typedef OmniBottomNavigationBarBuilder =
    Widget Function(BuildContext context, OmniRouteState state);

enum _PageBarSlot { body, bottomBar }

class _BottomNavBodyConstraints extends BoxConstraints {
  const _BottomNavBodyConstraints({
    required super.maxWidth,
    required super.maxHeight,
    required this.bottomBarHeight,
  });

  final double bottomBarHeight;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _BottomNavBodyConstraints &&
      other.bottomBarHeight == bottomBarHeight;

  @override
  int get hashCode => Object.hash(super.hashCode, bottomBarHeight);

  @override
  String toString() =>
      '${super.toString()} (bottomBarHeight: $bottomBarHeight)';
}

class _PageBottomBarLayoutDelegate extends MultiChildLayoutDelegate {
  _PageBottomBarLayoutDelegate({
    required this.extendBody,
    required this.keyboardInset,
    required this.hideOnKeyboard,
  });

  final bool extendBody;
  final double keyboardInset;
  final bool hideOnKeyboard;

  @override
  void performLayout(Size size) {
    final fullWidth = BoxConstraints.loose(size).tighten(width: size.width);
    var barHeight = 0.0;
    final keyboardOpen = hideOnKeyboard && keyboardInset > 0;

    if (hasChild(_PageBarSlot.bottomBar)) {
      final barSize = layoutChild(_PageBarSlot.bottomBar, fullWidth);
      if (!keyboardOpen) {
        barHeight = barSize.height;
      }
      final barTop = math.max(0.0, size.height - barSize.height);
      positionChild(_PageBarSlot.bottomBar, Offset(0, barTop));
    }

    if (hasChild(_PageBarSlot.body)) {
      final bodyHeight = extendBody
          ? size.height
          : math.max(0.0, size.height - barHeight);
      final propagatedBottom = extendBody ? barHeight : 0.0;

      layoutChild(
        _PageBarSlot.body,
        _BottomNavBodyConstraints(
          maxWidth: size.width,
          maxHeight: bodyHeight,
          bottomBarHeight: propagatedBottom,
        ),
      );
      positionChild(_PageBarSlot.body, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(covariant _PageBottomBarLayoutDelegate old) =>
      old.extendBody != extendBody ||
      old.keyboardInset != keyboardInset ||
      old.hideOnKeyboard != hideOnKeyboard;
}

/// Hosts an [OmniPage]-level [bottomNavigationBar] cleanly above [child] without
/// introducing a second nested `Scaffold` (preserving `ScaffoldMessenger`,
/// `Drawer`, and inner `AppBar` behavior while still propagating accurate
/// `MediaQuery.padding.bottom` to lists, safe areas, and FABs).
class OmniPageBottomBarHost extends StatelessWidget {
  /// Wraps [child] with [bottomNavigationBar].
  const OmniPageBottomBarHost({
    super.key,
    required this.bottomNavigationBar,
    required this.child,
    this.extendBody = true,
    this.hideOnKeyboard = true,
  });

  /// Navigation bar placed at the bottom of the page.
  final Widget bottomNavigationBar;

  /// Screen widget below the bar.
  final Widget child;

  /// When `true` (default), [child] spans full height underneath translucent /
  /// floating / curved bars and receives `MediaQuery.padding.bottom` matching
  /// the bar's height. When `false`, [child] is docked strictly above the bar.
  final bool extendBody;

  /// Collapses bottom padding impact when the software keyboard opens.
  final bool hideOnKeyboard;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    return CustomMultiChildLayout(
      delegate: _PageBottomBarLayoutDelegate(
        extendBody: extendBody,
        keyboardInset: keyboardInset,
        hideOnKeyboard: hideOnKeyboard,
      ),
      children: [
        LayoutId(
          id: _PageBarSlot.body,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final navConstraints = constraints as _BottomNavBodyConstraints;
              final baseMedia = MediaQuery.of(ctx);
              final adjustedBottom = extendBody
                  ? math.max(
                      baseMedia.padding.bottom,
                      navConstraints.bottomBarHeight,
                    )
                  : 0.0;
              return MediaQuery(
                data: baseMedia.copyWith(
                  padding: baseMedia.padding.copyWith(bottom: adjustedBottom),
                ),
                child: child,
              );
            },
          ),
        ),
        LayoutId(id: _PageBarSlot.bottomBar, child: bottomNavigationBar),
      ],
    );
  }
}
