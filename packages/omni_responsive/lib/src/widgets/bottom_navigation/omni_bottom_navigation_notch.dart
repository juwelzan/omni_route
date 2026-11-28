part of 'omni_bottom_navigation.dart';

/// The cut-out under the raised orb of [OmniBottomNavigationStyle.curvedNotch]
/// and the centre button of [OmniBottomNavigationStyle.centerFabNotch].
enum OmniNotchShape {
  /// A soft wave that eases into the bar (default).
  smooth,

  /// A round cut that hugs the orb at [OmniBottomNavigationNotch.gap], like
  /// Material's notched `BottomAppBar`.
  circular,

  /// No cut: the orb floats over a straight bar.
  none,
}

/// How the orb and its notch move to a newly selected tab
/// ([OmniBottomNavigationStyle.curvedNotch]).
enum OmniNotchTravel {
  /// Orb and notch slide along the bar together (default).
  slide,

  /// They slide while the orb sinks and the notch flattens, rising again
  /// on arrival — like a drop moving through liquid.
  dip,

  /// The notch closes on the old tab and opens on the new one; the orb
  /// shrinks away and pops up in the new place.
  pop,
}

/// Shape, size and motion of the notched bar's orb and cut-out.
///
/// Every field has a default derived from the orb size, so
/// `const OmniBottomNavigationNotch()` is the standard look and any single
/// field can be changed on its own:
///
/// ```dart
/// OmniBottomNavigationBar(
///   style: OmniBottomNavigationStyle.curvedNotch,
///   notch: const OmniBottomNavigationNotch(
///     shape: OmniNotchShape.circular,
///     travel: OmniNotchTravel.dip,
///     orbSize: 56,
///     gap: 8,
///   ),
///   items: [...],
/// )
/// ```
@immutable
class OmniBottomNavigationNotch {
  /// Creates a notch configuration; unset sizes follow the orb.
  const OmniBottomNavigationNotch({
    this.shape = OmniNotchShape.smooth,
    this.travel = OmniNotchTravel.slide,
    this.orbSize,
    this.lift,
    this.gap,
    this.depth,
    this.spread = 1.48,
    this.orbShadow,
  }) : assert(orbSize == null || orbSize > 0),
       assert(gap == null || gap >= 0),
       assert(depth == null || depth >= 0),
       assert(spread >= 1.0);

  /// The standard look.
  static const OmniBottomNavigationNotch standard = OmniBottomNavigationNotch();

  /// Cut-out shape.
  final OmniNotchShape shape;

  /// Motion between tabs (curved notch only; the centre button stays put).
  final OmniNotchTravel travel;

  /// Orb diameter. Default: 50 for the curved notch, the action's
  /// [OmniBottomNavigationAction.size] for the centre button.
  final double? orbSize;

  /// How far the orb's top rises above the bar's top edge (default 40 % of
  /// [orbSize]). `0` sits it flush; the rest of the orb sinks into the cut.
  final double? lift;

  /// Space between the orb and the cut-out's edge (default 12 % of
  /// [orbSize]).
  final double? gap;

  /// How deep the cut goes ([OmniNotchShape.smooth]; the circular cut
  /// follows the orb). Default: about ¾ of the sunken part of the orb plus
  /// [gap].
  final double? depth;

  /// Width of the smooth wave as a multiple of its radius (orb radius +
  /// [gap]); larger is gentler. At least 1.
  final double spread;

  /// Shadow under the orb (default: a soft glow in the orb colour).
  final List<BoxShadow>? orbShadow;

  /// A copy with the given fields replaced.
  OmniBottomNavigationNotch copyWith({
    OmniNotchShape? shape,
    OmniNotchTravel? travel,
    double? orbSize,
    double? lift,
    double? gap,
    double? depth,
    double? spread,
    List<BoxShadow>? orbShadow,
  }) => OmniBottomNavigationNotch(
    shape: shape ?? this.shape,
    travel: travel ?? this.travel,
    orbSize: orbSize ?? this.orbSize,
    lift: lift ?? this.lift,
    gap: gap ?? this.gap,
    depth: depth ?? this.depth,
    spread: spread ?? this.spread,
    orbShadow: orbShadow ?? this.orbShadow,
  );

  /// Interpolates sizes; shape, travel and shadow switch half-way.
  static OmniBottomNavigationNotch? lerp(
    OmniBottomNavigationNotch? a,
    OmniBottomNavigationNotch? b,
    double t,
  ) {
    if (a == null || b == null) return t < 0.5 ? a : b;
    return OmniBottomNavigationNotch(
      shape: t < 0.5 ? a.shape : b.shape,
      travel: t < 0.5 ? a.travel : b.travel,
      orbSize: lerpDouble(a.orbSize, b.orbSize, t),
      lift: lerpDouble(a.lift, b.lift, t),
      gap: lerpDouble(a.gap, b.gap, t),
      depth: lerpDouble(a.depth, b.depth, t),
      spread: lerpDouble(a.spread, b.spread, t)!,
      orbShadow: t < 0.5 ? a.orbShadow : b.orbShadow,
    );
  }

  _NotchGeometry _resolve(double defaultOrbSize) {
    final orb = orbSize ?? defaultOrbSize;
    final rise = lift ?? orb * 0.4;
    final space = gap ?? orb * 0.12;
    return _NotchGeometry(
      shape: shape,
      orbSize: orb,
      lift: rise,
      radius: orb / 2 + space,
      depth: depth ?? math.max(0.0, orb - rise + space) * 0.72,
      spread: spread,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OmniBottomNavigationNotch &&
      other.shape == shape &&
      other.travel == travel &&
      other.orbSize == orbSize &&
      other.lift == lift &&
      other.gap == gap &&
      other.depth == depth &&
      other.spread == spread &&
      listEquals(other.orbShadow, orbShadow);

  @override
  int get hashCode => Object.hash(
    shape,
    travel,
    orbSize,
    lift,
    gap,
    depth,
    spread,
    orbShadow == null ? null : Object.hashAll(orbShadow!),
  );
}

/// Resolved sizes for one bar.
class _NotchGeometry {
  const _NotchGeometry({
    required this.shape,
    required this.orbSize,
    required this.lift,
    required this.radius,
    required this.depth,
    required this.spread,
  });

  final OmniNotchShape shape;
  final double orbSize;
  final double lift;
  final double radius;
  final double depth;
  final double spread;

  /// Room above the bar for the raised orb (+2 for its shadow).
  double get headroom => math.max(0.0, lift) + 2;

  /// Orb top, measured from the top of the whole widget.
  double get orbTop => headroom - lift;

  /// The cut for this geometry, [scale] 0–1 (travel animations).
  _NotchCut cut({double scale = 1}) => _NotchCut(
    shape: scale <= 0 ? OmniNotchShape.none : shape,
    radius: radius * (shape == OmniNotchShape.circular ? scale : 1),
    depth: depth * scale,
    spread: spread,
    centerDepth: orbSize / 2 - lift,
  );
}

/// What the painter and clipper cut out of the bar's top edge.
@immutable
class _NotchCut {
  const _NotchCut({
    required this.shape,
    required this.radius,
    required this.depth,
    required this.spread,
    required this.centerDepth,
  });

  final OmniNotchShape shape;

  /// Orb radius + gap.
  final double radius;

  /// Smooth wave depth.
  final double depth;

  /// Smooth wave width / [radius].
  final double spread;

  /// Orb centre below the bar's top edge (negative: above it).
  final double centerDepth;

  @override
  bool operator ==(Object other) =>
      other is _NotchCut &&
      other.shape == shape &&
      other.radius == radius &&
      other.depth == depth &&
      other.spread == spread &&
      other.centerDepth == centerDepth;

  @override
  int get hashCode => Object.hash(shape, radius, depth, spread, centerDepth);
}
