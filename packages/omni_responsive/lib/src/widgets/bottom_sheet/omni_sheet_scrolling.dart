part of 'omni_bottom_sheet.dart';

/// How lists inside a sheet scroll.
enum OmniSheetScrollPhysics {
  /// Bounces on iOS / macOS and in the cupertino style, clamps (with the
  /// Android stretch) everywhere else.
  adaptive,

  /// iOS rubber-band overscroll.
  bouncing,

  /// Stops at the edges (Material).
  clamping,
}

/// Scroll behaviour of scroll views inside an Omni sheet (modal or
/// [OmniScalableSheet]). Scroll views pick it up on their own; a scroll
/// view's own `physics` still wins.
///
/// ```dart
/// showOmniBottomSheet(
///   context: context,
///   detents: const [OmniSheetDetent.medium, OmniSheetDetent.large],
///   scrolling: const OmniSheetScrolling(resetOnCollapse: false),
///   header: (context) => const Text('Students'),
///   builder: (context) => ListView(...),
/// );
/// ```
@immutable
class OmniSheetScrolling {
  /// Creates a scroll behaviour.
  const OmniSheetScrolling({
    this.physics = OmniSheetScrollPhysics.adaptive,
    this.expandBeforeScroll = true,
    this.resetOnCollapse = true,
    this.handleTapScrollsToTop = true,
    this.dismissKeyboardOnDrag = true,
    this.hapticFeedback = false,
  });

  /// Bounce or clamp at the edges.
  final OmniSheetScrollPhysics physics;

  /// Dragging the list up grows the sheet to its largest detent first, then
  /// scrolls (iOS, Maps). Off: the list scrolls at any size and only the
  /// handle / header resize the sheet.
  final bool expandBeforeScroll;

  /// Collapsing to the smallest detent scrolls the list back to its top.
  final bool resetOnCollapse;

  /// A tap on the handle first scrolls a scrolled list to its top, and only
  /// then moves to the next detent.
  final bool handleTapScrollsToTop;

  /// Dragging the sheet closes an open keyboard.
  final bool dismissKeyboardOnDrag;

  /// A light haptic tick when a drag settles on a different detent.
  final bool hapticFeedback;

  /// The physics for [style] on [platform].
  ScrollPhysics resolve(OmniSheetStyle style, TargetPlatform platform) {
    final bouncing = switch (physics) {
      OmniSheetScrollPhysics.bouncing => true,
      OmniSheetScrollPhysics.clamping => false,
      OmniSheetScrollPhysics.adaptive =>
        style == OmniSheetStyle.cupertino ||
            platform == TargetPlatform.iOS ||
            platform == TargetPlatform.macOS,
    };
    return bouncing
        ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
        : const ClampingScrollPhysics();
  }

  @override
  bool operator ==(Object other) =>
      other is OmniSheetScrolling &&
      other.physics == physics &&
      other.expandBeforeScroll == expandBeforeScroll &&
      other.resetOnCollapse == resetOnCollapse &&
      other.handleTapScrollsToTop == handleTapScrollsToTop &&
      other.dismissKeyboardOnDrag == dismissKeyboardOnDrag &&
      other.hapticFeedback == hapticFeedback;

  @override
  int get hashCode => Object.hash(
    physics,
    expandBeforeScroll,
    resetOnCollapse,
    handleTapScrollsToTop,
    dismissKeyboardOnDrag,
    hapticFeedback,
  );
}
