part of 'omni_bottom_sheet.dart';

class _SheetScrollController extends ScrollController {
  _SheetScrollController(this.sheet);

  final _OmniSheetViewState sheet;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SheetScrollPosition(
    sheet: sheet,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class _SheetScrollPosition extends ScrollPositionWithSingleContext {
  _SheetScrollPosition({
    required this.sheet,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final _OmniSheetViewState sheet;
  bool _driving = false;
  bool _inBallistic = false;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (_driving && !_inBallistic && newActivity is! DragScrollActivity) {
      _driving = false;
      if (!sheet._disposed && sheet.mounted) {
        sheet._dragEnd(0);
      }
    }
    super.beginActivity(newActivity);
  }

  @override
  void applyUserOffset(double delta) {
    if (delta == 0) return;
    if (sheet._disposed || !sheet.mounted || !sheet._canDragSheet) {
      if (_driving) {
        _driving = false;
        if (!sheet._disposed && sheet.mounted) sheet._dragEnd(0);
      }
      super.applyUserOffset(delta);
      return;
    }

    // A drag down that reaches the top mid-gesture: the list scrolls the
    // rest of the way to its top, the remainder moves the sheet.
    if (!_driving &&
        delta > 0 &&
        pixels > minScrollExtent &&
        pixels - delta < minScrollExtent &&
        sheet._heights.isNotEmpty) {
      final toTop = pixels - minScrollExtent;
      super.applyUserOffset(toTop);
      _driving = true;
      sheet._dragStart();
      sheet._dragUpdate(delta - toTop);
      return;
    }

    if (_driving || sheet._takesScroll(delta, this)) {
      if (!_driving) {
        _driving = true;
        sheet._dragStart();
      }

      if (sheet._heights.isEmpty) {
        _driving = false;
        super.applyUserOffset(delta);
        return;
      }

      final max = sheet._heights.last;
      final canScrollContent =
          maxScrollExtent > minScrollExtent || physics is BouncingScrollPhysics;

      // Dragging up while expandBeforeScroll is enabled: expand the sheet up
      // to max, then cleanly hand off remaining drag to scroll content.
      if (delta < 0 &&
          sheet._config.scrolling.expandBeforeScroll &&
          sheet._raw < max) {
        final remainingUp = max - sheet._raw;
        if ((-delta) > remainingUp && maxScrollExtent > minScrollExtent) {
          sheet._dragUpdate(-remainingUp);
          _driving = false;
          sheet._finishHandoffToScroll();
          super.applyUserOffset(delta + remainingUp);
          return;
        }
      }

      // Already at or above max detent while dragging up: hand off to scroll
      // when content can scroll (or when expandBeforeScroll is disabled).
      if (delta < 0 &&
          sheet._presence.value >= 1 &&
          sheet._raw >= max &&
          (!sheet._config.scrolling.expandBeforeScroll ||
              maxScrollExtent > minScrollExtent)) {
        _driving = false;
        sheet._finishHandoffToScroll();
        super.applyUserOffset(delta);
        return;
      }

      // When expandBeforeScroll is off and a downward drag returned up to the
      // minimum detent, hand upward drag back to scrollable content.
      if (!sheet._config.scrolling.expandBeforeScroll &&
          delta < 0 &&
          sheet._presence.value < 1 &&
          canScrollContent) {
        final min = sheet._heights.first;
        final toMin = min - sheet._raw;
        if (toMin > 0 && (-delta) > toMin) {
          sheet._dragUpdate(-toMin);
          _driving = false;
          sheet._finishHandoffToScroll();
          super.applyUserOffset(delta + toMin);
          return;
        }
      }

      sheet._dragUpdate(delta);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (_driving) {
      _driving = false;
      _inBallistic = true;
      try {
        if (sheet._disposed || !sheet.mounted || sheet._heights.isEmpty) {
          super.goBallistic(0);
          return;
        }
        final atMax =
            sheet._presence.value >= 1 &&
            sheet._raw >= sheet._heights.last - 0.5;
        final canFlingContent =
            velocity > 0 &&
            (atMax || !sheet._config.scrolling.expandBeforeScroll) &&
            (maxScrollExtent > minScrollExtent ||
                physics is BouncingScrollPhysics);
        if (canFlingContent) {
          // The sheet is up: the content keeps its upward scroll fling.
          sheet._dragEnd(0);
          super.goBallistic(velocity);
        } else {
          sheet._dragEnd(-velocity);
          super.goBallistic(0);
        }
      } finally {
        _inBallistic = false;
      }
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  void dispose() {
    if (_driving) {
      _driving = false;
      if (!sheet._disposed && sheet.mounted) {
        sheet._dragEnd(0);
      }
    }
    super.dispose();
    if (!sheet._disposed && sheet.mounted) {
      sheet._scheduleRefreshScrolled();
    }
  }
}
