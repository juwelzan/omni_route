part of 'omni_bottom_sheet.dart';

/// How a sheet moves: a spring described the way iOS and SwiftUI do, by
/// [response] (seconds for one oscillation) and [dampingRatio] (`1` = no
/// bounce).
@immutable
class OmniSheetMotion {
  /// Creates a motion.
  const OmniSheetMotion({
    this.response = 0.42,
    this.dampingRatio = 1.0,
    this.rubberBand = true,
    this.dismissVelocity = 900,
  }) : assert(response > 0),
       assert(dampingRatio > 0),
       assert(dismissVelocity >= 0);

  /// iOS sheet presentation: smooth, no bounce, stretches past the top.
  static const OmniSheetMotion ios = OmniSheetMotion(response: 0.45);

  /// Material 3: quicker, no bounce, stops hard at the top.
  static const OmniSheetMotion material = OmniSheetMotion(
    response: 0.34,
    rubberBand: false,
  );

  /// Fast and crisp.
  static const OmniSheetMotion snappy = OmniSheetMotion(response: 0.28);

  /// A soft overshoot when settling on a detent.
  static const OmniSheetMotion bouncy = OmniSheetMotion(
    response: 0.5,
    dampingRatio: 0.78,
  );

  /// Seconds for one oscillation; smaller is faster.
  final double response;

  /// `1` settles without overshoot, below `1` bounces.
  final double dampingRatio;

  /// Stretches with resistance when pulled past the largest detent (or below
  /// the smallest one when the sheet can't be dismissed).
  final bool rubberBand;

  /// A downward fling faster than this (logical px/s) dismisses the sheet.
  final double dismissVelocity;

  /// The [SpringDescription] of this motion.
  SpringDescription get spring {
    final omega = 2 * math.pi / response;
    return SpringDescription(
      mass: 1,
      stiffness: omega * omega,
      damping: 2 * dampingRatio * omega,
    );
  }

  void _validate() {
    if (!response.isFinite || response <= 0) {
      throw ArgumentError.value(
        response,
        'motion.response',
        'Response must be finite and > 0.',
      );
    }
    if (!dampingRatio.isFinite || dampingRatio <= 0) {
      throw ArgumentError.value(
        dampingRatio,
        'motion.dampingRatio',
        'Damping ratio must be finite and > 0.',
      );
    }
    if (!dismissVelocity.isFinite || dismissVelocity < 0) {
      throw ArgumentError.value(
        dismissVelocity,
        'motion.dismissVelocity',
        'Dismiss velocity must be finite and >= 0.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OmniSheetMotion &&
      other.response == response &&
      other.dampingRatio == dampingRatio &&
      other.rubberBand == rubberBand &&
      other.dismissVelocity == dismissVelocity;

  @override
  int get hashCode =>
      Object.hash(response, dampingRatio, rubberBand, dismissVelocity);
}

// iOS rubber-band: resistance grows the further it is pulled.
double _rubber(double offset, double dimension) {
  if (offset <= 0 || dimension <= 0) return 0;
  const c = 0.55;
  return (1 - 1 / (offset * c / dimension + 1)) * dimension;
}

double _rubberInverse(double stretched, double dimension) {
  if (stretched <= 0 || dimension <= 0) return 0;
  const c = 0.55;
  final ratio = (stretched / dimension).clamp(0.0, 0.999);
  return (1 / (1 - ratio) - 1) * dimension / c;
}

/// A spring that lands exactly on its target once it is within tolerance,
/// so a settled sheet sits on whole pixels instead of a hair off.
Simulation _settlingSpring(
  SpringDescription spring,
  double start,
  double end,
  double velocity, {
  required Tolerance tolerance,
  double? minValue,
  double? maxValue,
}) => _SettlingSimulation(
  SpringSimulation(spring, start, end, velocity, tolerance: tolerance),
  end,
  minValue: minValue,
  maxValue: maxValue,
);

class _SettlingSimulation extends Simulation {
  _SettlingSimulation(
    this._inner,
    this._end, {
    this.minValue,
    this.maxValue,
  }) : super(tolerance: _inner.tolerance);

  final SpringSimulation _inner;
  final double _end;
  final double? minValue;
  final double? maxValue;

  @override
  double x(double time) {
    if (_inner.isDone(time)) return _end;
    var value = _inner.x(time);
    if (minValue != null && value < minValue!) value = minValue!;
    if (maxValue != null && value > maxValue!) value = maxValue!;
    return value;
  }

  @override
  double dx(double time) => _inner.isDone(time) ? 0 : _inner.dx(time);

  @override
  bool isDone(double time) => _inner.isDone(time);
}
