part of 'omni_bottom_sheet.dart';

/// A resting height of a sheet: it snaps to the nearest one when released.
@immutable
class OmniSheetDetent {
  /// A share of the available height (`0 < fraction <= 1`).
  const OmniSheetDetent.fraction(double this.fraction)
    : assert(
        fraction > 0 && fraction <= 1,
        'Fraction detent must be finite and in (0, 1].',
      ),
      height = null;

  /// A fixed height in logical pixels (capped by the available height).
  const OmniSheetDetent.height(double this.height)
    : assert(height > 0, 'Fixed height detent must be finite and > 0.'),
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

  void _validate(int index) {
    if (fraction case final f?) {
      if (!f.isFinite || f <= 0 || f > 1) {
        throw RangeError(
          'detents[$index].fraction must be finite and in (0, 1], got $f.',
        );
      }
    } else if (height case final h?) {
      if (!h.isFinite || h <= 0) {
        throw ArgumentError.value(
          h,
          'detents[$index].height',
          'Fixed height detent must be finite and > 0.',
        );
      }
    }
  }

  double _resolve(double available) {
    final safeAvailable = available.isFinite && available > 0 ? available : 0.0;
    return height != null
        ? math.min(height!, safeAvailable)
        : safeAvailable * fraction!;
  }

  @override
  bool operator ==(Object other) =>
      other is OmniSheetDetent &&
      other.fraction == fraction &&
      other.height == height;

  @override
  int get hashCode => Object.hash(fraction, height);

  @override
  String toString() {
    if (_isContent) return 'OmniSheetDetent.content';
    if (fraction != null) return 'OmniSheetDetent.fraction($fraction)';
    return 'OmniSheetDetent.height($height)';
  }
}
