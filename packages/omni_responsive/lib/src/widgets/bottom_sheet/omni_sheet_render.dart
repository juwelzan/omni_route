// Named constructor parameters stay public names; the fields are private.
// ignore_for_file: prefer_initializing_formals

part of 'omni_bottom_sheet.dart';

class _SheetMetrics {
  _SheetMetrics({required this.publicIndex});

  /// Active detent index in the caller's `detents` list.
  int publicIndex;

  /// Active detent index in [heights] (smallest-first).
  int sortedIndex = 0;

  /// Distinct resolved heights in ascending order.
  List<double> heights = const [];

  /// Maps each caller detent index to its entry in [heights].
  List<int> publicToSorted = const [];

  /// Canonical caller detent index for each entry in [heights].
  List<int> sortedToPublic = const [];

  /// Last target height synced to [_extent] while animating.
  double? lastSyncedTarget;

  /// Invoked when layout changes the height of an active animation target.
  void Function(int sortedIndex)? onRetargetNeeded;

  /// Height the sheet may grow to (below the top gap, above the bottom
  /// gap); written at layout.
  double available = 0;
  bool ready = false;
  bool settled = true;
  bool dragging = false;
}

class _SheetLayout extends SingleChildRenderObjectWidget {
  const _SheetLayout({
    required this.presence,
    required this.extent,
    required this.metrics,
    required this.detents,
    required this.topGap,
    required this.bottomGap,
    required this.maxWidth,
    required this.leftInset,
    required this.rightInset,
    required this.fill,
    required this.fadeOnly,
    required this.clipToBounds,
    super.child,
  });

  final Animation<double> presence;
  final AnimationController extent;
  final _SheetMetrics metrics;
  final List<OmniSheetDetent> detents;
  final double topGap;
  final double bottomGap;
  final double maxWidth;
  final double leftInset;
  final double rightInset;
  final Color? fill;
  final bool fadeOnly;
  final bool clipToBounds;

  @override
  _RenderSheet createRenderObject(BuildContext context) => _RenderSheet(
    presence: presence,
    extent: extent,
    metrics: metrics,
    detents: detents,
    topGap: topGap,
    bottomGap: bottomGap,
    maxWidth: maxWidth,
    leftInset: leftInset,
    rightInset: rightInset,
    fill: fill,
    fadeOnly: fadeOnly,
    clipToBounds: clipToBounds,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSheet renderObject) {
    renderObject
      ..presence = presence
      ..extent = extent
      ..metrics = metrics
      ..detents = detents
      ..topGap = topGap
      ..bottomGap = bottomGap
      ..maxWidth = maxWidth
      ..leftInset = leftInset
      ..rightInset = rightInset
      ..fill = fill
      ..fadeOnly = fadeOnly
      ..clipToBounds = clipToBounds;
  }
}

/// Lays the sheet out once and moves it in paint, so opening, closing and
/// dragging cost a repaint of one layer — never a rebuild or a relayout of
/// the content. Only moving between detents relayouts (the sheet resizes,
/// like on iOS, so bottom-pinned content stays visible).
class _RenderSheet extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderSheet({
    required Animation<double> presence,
    required AnimationController extent,
    required _SheetMetrics metrics,
    required List<OmniSheetDetent> detents,
    required double topGap,
    required double bottomGap,
    required double maxWidth,
    required double leftInset,
    required double rightInset,
    required Color? fill,
    required bool fadeOnly,
    required bool clipToBounds,
  }) : _presence = presence,
       _extent = extent,
       _metrics = metrics,
       _detents = detents,
       _topGap = topGap,
       _bottomGap = bottomGap,
       _maxWidth = maxWidth,
       _leftInset = leftInset,
       _rightInset = rightInset,
       _fill = fill,
       _fadeOnly = fadeOnly,
       _clipToBounds = clipToBounds;

  Animation<double> _presence;
  set presence(Animation<double> v) {
    if (identical(v, _presence)) return;
    if (attached) _presence.removeListener(_onPresence);
    _presence = v;
    if (attached) _presence.addListener(_onPresence);
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  AnimationController _extent;
  set extent(AnimationController v) {
    if (identical(v, _extent)) return;
    if (attached) _extent.removeListener(_onExtent);
    _extent = v;
    if (attached) _extent.addListener(_onExtent);
    markNeedsLayout();
  }

  _SheetMetrics _metrics;
  set metrics(_SheetMetrics v) {
    if (identical(v, _metrics)) return;
    _metrics = v;
    markNeedsLayout();
  }

  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  bool _lastNeedsOpacityLayer = false;

  List<OmniSheetDetent> _detents;
  set detents(List<OmniSheetDetent> v) {
    if (listEquals(v, _detents)) return;
    _detents = v;
    markNeedsLayout();
  }

  double _topGap;
  set topGap(double v) {
    if (v == _topGap) return;
    _topGap = v;
    markNeedsLayout();
  }

  double get _available => _metrics.available;

  double _bottomGap;
  set bottomGap(double v) {
    if (v == _bottomGap) return;
    _bottomGap = v;
    markNeedsLayout();
  }

  double _maxWidth;
  set maxWidth(double v) {
    if (v == _maxWidth) return;
    _maxWidth = v;
    markNeedsLayout();
  }

  double _leftInset;
  set leftInset(double v) {
    if (v == _leftInset) return;
    _leftInset = v;
    markNeedsLayout();
  }

  double _rightInset;
  set rightInset(double v) {
    if (v == _rightInset) return;
    _rightInset = v;
    markNeedsLayout();
  }

  Color? _fill;
  set fill(Color? v) {
    if (v == _fill) return;
    _fill = v;
    markNeedsPaint();
  }

  bool _fadeOnly;
  set fadeOnly(bool v) {
    if (v == _fadeOnly) return;
    _fadeOnly = v;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  bool _clipToBounds;
  set clipToBounds(bool v) {
    if (v == _clipToBounds) return;
    _clipToBounds = v;
    markNeedsPaint();
  }

  bool _inLayout = false;

  bool get _contentSized => _detents.first._isContent;

  bool get _needsOpacityLayer =>
      _fadeOnly && _presence.value > 0 && _presence.value < 1;

  @override
  bool get alwaysNeedsCompositing => _needsOpacityLayer;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _lastNeedsOpacityLayer = _needsOpacityLayer;
    _presence.addListener(_onPresence);
    _extent.addListener(_onExtent);
  }

  @override
  void detach() {
    _presence.removeListener(_onPresence);
    _extent.removeListener(_onExtent);
    super.detach();
  }

  @override
  void dispose() {
    _opacity.layer = null;
    _clip.layer = null;
    super.dispose();
  }

  void _onPresence() {
    final needsOpacity = _needsOpacityLayer;
    if (needsOpacity != _lastNeedsOpacityLayer) {
      _lastNeedsOpacityLayer = needsOpacity;
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  void _onExtent() {
    if (_inLayout) return;
    final child = this.child;
    if (!_contentSized &&
        child != null &&
        child.hasSize &&
        _metrics.heights.isNotEmpty &&
        _layoutHeight() != child.size.height) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  double _layoutHeight() =>
      _extent.value.clamp(_metrics.heights.first, _metrics.heights.last);

  void _syncExtent() {
    final heights = _metrics.heights;
    final index = _metrics.sortedIndex.clamp(0, heights.length - 1);
    _metrics.sortedIndex = index;
    final target = heights[index];
    if (!_metrics.ready) {
      _metrics.ready = true;
      _metrics.lastSyncedTarget = target;
      _extent.value = target;
      return;
    }
    if (_metrics.settled && !_metrics.dragging) {
      _metrics.lastSyncedTarget = target;
      if (_extent.value != target) {
        _extent.value = target;
      }
    } else if (!_metrics.dragging &&
        (_metrics.lastSyncedTarget == null ||
            (_metrics.lastSyncedTarget! - target).abs() > 0.5)) {
      _metrics.lastSyncedTarget = target;
      _metrics.onRetargetNeeded?.call(index);
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.hasBoundedWidth && constraints.hasBoundedHeight
      ? constraints.biggest
      : constraints.constrain(Size.zero);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    _inLayout = true;
    try {
      _metrics.available = math.max(0, size.height - _topGap - _bottomGap);
      final width = math.max(
        0.0,
        math.min(size.width - _leftInset - _rightInset, _maxWidth),
      );
      if (_contentSized) {
        child.layout(
          BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: _available,
          ),
          parentUsesSize: true,
        );
        _metrics
          ..heights = [child.size.height]
          ..publicToSorted = const [0]
          ..sortedToPublic = const [0]
          ..publicIndex = 0
          ..sortedIndex = 0;
        _syncExtent();
      } else {
        final entries = <({double height, int publicIndex})>[];
        for (var i = 0; i < _detents.length; i++) {
          final resolved = _detents[i]._resolve(_available);
          final h = _available > 0 ? math.max(1.0, resolved) : 0.0;
          entries.add((height: h, publicIndex: i));
        }
        entries.sort((a, b) {
          final cmp = a.height.compareTo(b.height);
          return cmp != 0 ? cmp : a.publicIndex.compareTo(b.publicIndex);
        });
        const epsilon = 0.01;
        final heights = <double>[];
        final publicToSorted = List<int>.filled(_detents.length, 0);
        final sortedToPublic = <int>[];
        for (final entry in entries) {
          if (heights.isEmpty ||
              (entry.height - heights.last).abs() > epsilon) {
            heights.add(entry.height);
            sortedToPublic.add(entry.publicIndex);
          }
          publicToSorted[entry.publicIndex] = heights.length - 1;
        }
        final publicIdx = _metrics.publicIndex.clamp(0, _detents.length - 1);
        final sortedIdx = publicToSorted[publicIdx];
        _metrics
          ..heights = heights
          ..publicToSorted = publicToSorted
          ..sortedToPublic = sortedToPublic
          ..publicIndex = publicIdx
          ..sortedIndex = sortedIdx;
        _syncExtent();
        child.layout(
          BoxConstraints.tightFor(width: width, height: _layoutHeight()),
          parentUsesSize: true,
        );
      }
    } finally {
      _inLayout = false;
    }
  }

  Offset _childOffset() {
    final child = this.child!;
    final visible = _extent.value;
    final presence = _presence.value;
    final innerWidth = math.max(0.0, size.width - _leftInset - _rightInset);
    final x = _leftInset + (innerWidth - child.size.width) / 2;
    final y = _fadeOnly
        ? size.height - _bottomGap - visible
        : size.height - (visible + _bottomGap) * presence;
    return Offset(x, y);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || _presence.value <= 0) {
      _opacity.layer = null;
      _clip.layer = null;
      return;
    }
    final childOffset = _childOffset();
    void paintSheet(PaintingContext context, Offset offset) {
      final visible = _extent.value;
      final fill = _fill;
      if (fill != null && visible > child.size.height) {
        // Rubber-band stretch past the top: extend the sheet's color down
        // instead of showing a gap under it.
        final top = offset.dy + childOffset.dy + child.size.height - 1;
        context.canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + childOffset.dx,
            top,
            child.size.width,
            visible - child.size.height + _bottomGap + 1,
          ),
          Paint()..color = fill,
        );
      }
      context.paintChild(child, offset + childOffset);
    }

    void paintWithOptionalOpacity(PaintingContext context, Offset offset) {
      final presence = _presence.value;
      if (_fadeOnly && presence < 1) {
        _opacity.layer = context.pushOpacity(
          offset,
          (presence * 255).round().clamp(0, 255),
          paintSheet,
          oldLayer: _opacity.layer,
        );
      } else {
        _opacity.layer = null;
        paintSheet(context, offset);
      }
    }

    if (_clipToBounds) {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        paintWithOptionalOpacity,
        oldLayer: _clip.layer,
      );
    } else {
      _clip.layer = null;
      paintWithOptionalOpacity(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null ||
        _presence.value <= 0 ||
        !(Offset.zero & size).contains(position)) {
      return false;
    }
    return result.addWithPaintOffset(
      offset: _childOffset(),
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final o = _childOffset();
    transform.translateByDouble(o.dx, o.dy, 0, 1);
  }
}
