import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'omni_responsive_config.dart';
import 'omni_responsive_scope.dart';

/// Lightweight observable selection controller for [OmniMasterDetail] so
/// changing the selected item only rebuilds the detail pane — **never** the
/// master list.
class OmniMasterDetailController<T> extends ValueNotifier<T?> {
  /// Creates a master-detail controller with an optional [initialSelection].
  OmniMasterDetailController([super.initialSelection]);

  /// Currently selected item, or `null` when empty.
  T? get selected => value;

  /// Updates the active selection and notifies ONLY detail listeners.
  void select(T? item) => value = item;

  /// Clears active selection back to `null`.
  void clear() => value = null;
}

/// Builds the list/master pane for [OmniMasterDetail].
typedef OmniMasterBuilder<T> = Widget Function(
  BuildContext context,
  ValueListenable<T?> selectionListenable,
  void Function(T item) onSelect,
);

/// Builds the detail pane for a selected item [item] inside [OmniMasterDetail].
typedef OmniDetailBuilder<T> = Widget Function(BuildContext context, T item);

/// Zero-jank responsive Master-Detail split layout:
///
/// - **On [OmniDeviceType.mobile]:** renders ONLY [masterBuilder] (`0` off-screen
///   detail allocations), invoking [onOpenMobile] when the user taps an item.
/// - **On tablet/desktop:** displays a side-by-side split view wrapping the
///   detail pane in [OmniResponsiveScope.constrained] so forms & grids inside the
///   detail pane adapt cleanly to the pane's width rather than the full screen.
/// - Selecting different items notifies ONLY the detail pane via
///   [ValueListenableBuilder], keeping the master list completely un-rebuilt.
class OmniMasterDetail<T> extends StatefulWidget {
  /// Creates a Master-Detail layout.
  const OmniMasterDetail({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    this.controller,
    this.initialSelection,
    this.emptyDetailBuilder,
    this.onOpenMobile,
    this.onSelectedChanged,
    this.masterWidth = 340,
    this.showDivider = true,
  });

  /// Builds the scrollable list/master pane. Observe [selectionListenable] inside
  /// individual row widgets (e.g. `ValueListenableBuilder`) so only the toggled
  /// rows highlight without rebuilding the whole list.
  final OmniMasterBuilder<T> masterBuilder;

  /// Builds the detail pane on wide layouts when an item is selected.
  final OmniDetailBuilder<T> detailBuilder;

  /// Optional external [OmniMasterDetailController]. If omitted, an internal
  /// controller is created and cleanly disposed automatically.
  final OmniMasterDetailController<T>? controller;

  /// Initial item selected when using the internal controller.
  final T? initialSelection;

  /// Placeholder shown in the detail pane on wide layouts before selection.
  final WidgetBuilder? emptyDetailBuilder;

  /// Called when tapping an item on mobile viewports (for example
  /// `(c, item) => c.push('/orders/${item.id}')`). If omitted on mobile, falls
  /// back to updating selection cleanly without crashing.
  final void Function(BuildContext context, T item)? onOpenMobile;

  /// Optional side-effect callback triggered whenever an item is selected.
  final void Function(BuildContext context, T item)? onSelectedChanged;

  /// Fixed width of the left master list pane on tablet/desktop.
  final double masterWidth;

  /// Renders a `VerticalDivider(width: 1)` between panes on wide screens.
  final bool showDivider;

  @override
  State<OmniMasterDetail<T>> createState() => _OmniMasterDetailState<T>();
}

class _OmniMasterDetailState<T> extends State<OmniMasterDetail<T>> {
  OmniMasterDetailController<T>? _owned;

  OmniMasterDetailController<T> get _controller =>
      widget.controller ??
      (_owned ??= OmniMasterDetailController<T>(widget.initialSelection));

  @override
  void didUpdateWidget(covariant OmniMasterDetail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _owned != null) {
      _owned!.dispose();
      _owned = null;
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  void _handleSelect(BuildContext context, T item, bool isMobile) {
    _controller.select(item);
    widget.onSelectedChanged?.call(context, item);
    if (isMobile) {
      widget.onOpenMobile?.call(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = OmniResponsiveScope.deviceOf(context);
    final controller = _controller;

    if (device == OmniDeviceType.mobile) {
      return widget.masterBuilder(
        context,
        controller,
        (item) => _handleSelect(context, item, true),
      );
    }

    return LayoutBuilder(
      builder: (splitCtx, constraints) {
        final effectiveMasterWidth = constraints.hasBoundedWidth &&
                widget.masterWidth > constraints.maxWidth * 0.5
            ? (constraints.maxWidth * 0.45).clamp(240.0, widget.masterWidth)
            : widget.masterWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: effectiveMasterWidth,
              child: OmniResponsiveScope.constrained(
                child: widget.masterBuilder(
                  splitCtx,
                  controller,
                  (item) => _handleSelect(splitCtx, item, false),
                ),
              ),
            ),
            if (widget.showDivider) const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: OmniResponsiveScope.constrained(
                child: ValueListenableBuilder<T?>(
                  valueListenable: controller,
                  builder: (detailContext, selected, _) {
                    if (selected == null) {
                      return widget.emptyDetailBuilder?.call(detailContext) ??
                          const SizedBox.shrink();
                    }
                    return widget.detailBuilder(detailContext, selected);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Foldable hardware hinge / dual-screen aware split layout.
///
/// Subscribes ONLY to `MediaQuery.maybeDisplayFeaturesOf(context)` and
/// `OmniResponsiveScope.deviceOf(context)` (zero keyboard rebuilds):
/// - On foldable devices with a vertical [ui.DisplayFeatureType.hinge] or
///   [ui.DisplayFeatureType.fold], positions [primary] strictly left of the
///   hinge bounds and [secondary] strictly right so no content sits underneath
///   the hardware crease.
/// - Without a vertical hinge, displays side-by-side panes from [splitFrom]
///   upward, or shows only [primary] (or stacked panes) on mobile.
class OmniFoldableSplit extends StatelessWidget {
  /// Creates a hinge-aware two-pane split widget.
  const OmniFoldableSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.splitFrom = OmniDeviceType.tablet,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
    this.stackOnMobile = false,
    this.divider = const VerticalDivider(width: 1, thickness: 1),
  });

  /// Primary (left/top) pane widget.
  final Widget primary;

  /// Secondary (right/bottom) pane widget.
  final Widget secondary;

  /// Minimum [OmniDeviceType] to split side-by-side when no hinge is present.
  final OmniDeviceType splitFrom;

  /// Flex ratio for [primary] in standard non-hinge split mode.
  final int primaryFlex;

  /// Flex ratio for [secondary] in standard non-hinge split mode.
  final int secondaryFlex;

  /// When `true`, stacks [primary] above [secondary] on mobile instead of
  /// showing only [primary].
  final bool stackOnMobile;

  /// Optional divider rendered in standard non-hinge horizontal split mode.
  final Widget? divider;

  static ui.DisplayFeature? _findVerticalHinge(BuildContext context) {
    final features = MediaQuery.maybeDisplayFeaturesOf(context);
    if (features == null || features.isEmpty) return null;
    for (final f in features) {
      final isFoldOrHinge =
          f.type == ui.DisplayFeatureType.hinge ||
          f.type == ui.DisplayFeatureType.fold;
      if (!isFoldOrHinge) continue;
      if (f.bounds.height > f.bounds.width && f.bounds.left > 0) {
        return f;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hinge = _findVerticalHinge(context);
    if (hinge != null) {
      final gapWidth = hinge.bounds.width;
      return LayoutBuilder(
        builder: (layoutCtx, constraints) {
          final maxW = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.maybeSizeOf(layoutCtx)?.width ?? 600;
          final leftWidth = hinge.bounds.left.clamp(0.0, maxW);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftWidth,
                child: OmniResponsiveScope.constrained(child: primary),
              ),
              if (gapWidth > 0) SizedBox(width: gapWidth),
              Expanded(
                child: OmniResponsiveScope.constrained(child: secondary),
              ),
            ],
          );
        },
      );
    }

    final device = OmniResponsiveScope.deviceOf(context);
    if (device.index >= splitFrom.index) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: primaryFlex,
            child: OmniResponsiveScope.constrained(child: primary),
          ),
          ?divider,
          Expanded(
            flex: secondaryFlex,
            child: OmniResponsiveScope.constrained(child: secondary),
          ),
        ],
      );
    }

    if (stackOnMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          secondary,
        ],
      );
    }

    return primary;
  }
}
