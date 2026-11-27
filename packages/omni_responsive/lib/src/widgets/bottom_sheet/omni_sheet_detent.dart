part of 'omni_bottom_sheet.dart';

/// A resting height of a sheet: it snaps to the nearest one when released.
@immutable
class OmniSheetDetent {
  /// A share of the available height (`0 < fraction <= 1`).
  const OmniSheetDetent.fraction(double this.fraction)
    : assert(fraction > 0 && fraction <= 1),
      height = null;

  /// A fixed height in logical pixels (capped by the available height).
  const OmniSheetDetent.height(double this.height)
    : assert(height > 0),
      fraction = null;

  const OmniSheetDetent._content() : fraction = null, height = null;

  /// As tall as the content (capped by the available height). Use it on its
  /// own, not together with other detents.
  static const OmniSheetDetent content = OmniSheetDetent._content();

  /// Half of the available height.
  static const OmniSheetDetent medium = OmniSheetDetent.fraction(0.5);

  /// All of the available height.
  static const OmniSheetDetent large = OmniSheetDetent.fraction(1);

  /// The share of the available height, or `null`.
  final double? fraction;

  /// The fixed height, or `null`.
  final double? height;

  bool get _isContent => fraction == null && height == null;

  double _resolve(double available) =>
      height != null ? math.min(height!, available) : available * fraction!;

  @override
  bool operator ==(Object other) =>
      other is OmniSheetDetent &&
      other.fraction == fraction &&
      other.height == height;

  @override
  int get hashCode => Object.hash(fraction, height);
}
