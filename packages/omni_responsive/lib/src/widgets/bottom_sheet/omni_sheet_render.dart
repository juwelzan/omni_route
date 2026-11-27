// Named constructor parameters stay public names; the fields are private.
// ignore_for_file: prefer_initializing_formals

part of 'omni_bottom_sheet.dart';

class _SheetMetrics {
  _SheetMetrics({required this.index});

  int index;
  List<double> heights = const [];

  /// Height the sheet may grow to (below the top gap, above the bottom
  /// gap); written at layout.
  double available = 0;
  bool ready = false;
  bool settled = true;
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
    required this.horizontalMargin,
    required this.fill,
    required this.fadeOnly,
    super.child,
  });

  final Animation<double> presence;
  final AnimationController extent;
  final _SheetMetrics metrics;
  final List<OmniSheetDetent> detents;
  final double topGap;
  final double bottomGap;
  final double maxWidth;
  final double horizontalMargin;
  final Color? fill;
  final bool fadeOnly;

  @override
  _RenderSheet createRenderObject(BuildContext context) => _RenderSheet(
    presence: presence,
    extent: extent,
    metrics: metrics,
    detents: detents,
    topGap: topGap,
    bottomGap: bottomGap,
    maxWidth: maxWidth,
    horizontalMargin: horizontalMargin,
    fill: fill,
    fadeOnly: fadeOnly,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSheet renderObject) {
    renderObject
      ..detents = detents
      ..topGap = topGap
      ..bottomGap = bottomGap
      ..maxWidth = maxWidth
      ..horizontalMargin = horizontalMargin
      ..fill = fill
      ..fadeOnly = fadeOnly;
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
    required double horizontalMargin,
    required Color? fill,
    required bool fadeOnly,
  }) : _presence = presence,
       _extent = extent,
       _metrics = metrics,
       _detents = detents,
       _topGap = topGap,
       _bottomGap = bottomGap,
       _maxWidth = maxWidth,
       _horizontalMargin = horizontalMargin,
       _fill = fill,
       _fadeOnly = fadeOnly;

  final Animation<double> _presence;
  final AnimationController _extent;
  final _SheetMetrics _metrics;
  final LayerHandle<OpacityLayer> _opacity = LayerHandle<OpacityLayer>();

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

  double _horizontalMargin;
  set horizontalMargin(double v) {
    if (v == _horizontalMargin) return;
    _horizontalMargin = v;
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
    markNeedsPaint();
  }

  bool get _contentSized => _detents.first._isContent;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(markNeedsPaint);
    _extent.addListener(_onExtent);
  }

  @override
  void detach() {
    _presence.removeListener(markNeedsPaint);
    _extent.removeListener(_onExtent);
    super.detach();
  }

  @override
  void dispose() {
    _opacity.layer = null;
    super.dispose();
  }

  void _onExtent() {
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
    final index = _metrics.index.clamp(0, heights.length - 1);
    _metrics.index = index;
    final target = heights[index];
    if (!_metrics.ready || (_metrics.settled && _extent.value != target)) {
      _metrics.ready = true;
      _extent.value = target;
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    _metrics.available = math.max(0, size.height - _topGap - _bottomGap);
    final width = math.max(
      0.0,
      math.min(size.width - _horizontalMargin * 2, _maxWidth),
    );
    if (_contentSized) {
      child.layout(
        BoxConstraints(minWidth: width, maxWidth: width, maxHeight: _available),
        parentUsesSize: true,
      );
      _metrics.heights = [child.size.height];
      _syncExtent();
    } else {
      final firstLayout = !_metrics.ready;
      final heights = <double>{
        for (final d in _detents) math.max(1.0, d._resolve(_available)),
      }.toList()..sort();
      if (firstLayout) {
        // The initial detent was given in the caller's order.
        final initial = _detents[_metrics.index.clamp(0, _detents.length - 1)]
            ._resolve(_available);
        _metrics.index = heights.indexWhere(
          (h) => (h - math.max(1.0, initial)).abs() < 0.01,
        );
        if (_metrics.index < 0) _metrics.index = 0;
      }
      _metrics.heights = heights;
      _syncExtent();
      child.layout(
        BoxConstraints.tightFor(width: width, height: _layoutHeight()),
        parentUsesSize: true,
      );
    }
  }

  Offset _childOffset() {
    final child = this.child!;
    final visible = _extent.value;
    final presence = _presence.value;
    final x = (size.width - child.size.width) / 2;
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

    final presence = _presence.value;
    if (_fadeOnly && presence < 1) {
      _opacity.layer = context.pushOpacity(
        offset,
        (presence * 255).round(),
        paintSheet,
        oldLayer: _opacity.layer,
      );
    } else {
      _opacity.layer = null;
      paintSheet(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || _presence.value <= 0) return false;
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
