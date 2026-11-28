part of 'omni_bottom_navigation.dart';

/// The bar's outline with [cut] taken out of its top edge at [notchCenterX].
///
/// The notch is never shifted away from [notchCenterX] (the orb is drawn
/// there): near the bar's ends the top corner on that side shrinks instead,
/// so orb and cut always line up.
Path _buildNotchedBarPath({
  required Size size,
  required double topOffset,
  required double notchCenterX,
  required _NotchCut cut,
  required double cornerRadius,
}) {
  final rCorner = cornerRadius
      .clamp(0.0, math.min(size.width * 0.25, 36.0))
      .toDouble();
  final top = topOffset;
  final bottom = size.height;
  final cx = notchCenterX;
  final r = cut.radius;

  // Half-width of the cut along the top edge; 0 when there is none.
  var halfWidth = 0.0;
  var dx = 0.0;
  var fillet = 0.0;
  var shape = cut.shape;
  if (shape == OmniNotchShape.smooth && cut.depth > 0.01) {
    halfWidth = r * cut.spread;
  } else if (shape == OmniNotchShape.circular &&
      cut.centerDepth.abs() < r - 0.01) {
    dx = math.sqrt(r * r - cut.centerDepth * cut.centerDepth);
    fillet = math.min(6.0, r * 0.25);
    halfWidth = dx + fillet;
  } else {
    shape = OmniNotchShape.none;
  }

  final rL = shape == OmniNotchShape.none
      ? rCorner
      : math.min(rCorner, math.max(0.0, cx - halfWidth));
  final rR = shape == OmniNotchShape.none
      ? rCorner
      : math.min(rCorner, math.max(0.0, size.width - (cx + halfWidth)));

  final path = Path()..moveTo(0, top + rL);
  if (rL > 0) {
    path.quadraticBezierTo(0, top, rL, top);
  } else {
    path.lineTo(0, top);
  }

  switch (shape) {
    case OmniNotchShape.smooth:
      final k = cut.spread / 1.48;
      path
        ..lineTo(cx - halfWidth, top)
        ..cubicTo(
          cx - r * 0.78 * k,
          top,
          cx - r * 0.68 * k,
          top + cut.depth,
          cx,
          top + cut.depth,
        )
        ..cubicTo(
          cx + r * 0.68 * k,
          top + cut.depth,
          cx + r * 0.78 * k,
          top,
          cx + halfWidth,
          top,
        );
    case OmniNotchShape.circular:
      final cy = top + cut.centerDepth;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final thetaL = math.atan2(top - cy, -dx);
      final thetaR = math.atan2(top - cy, dx);
      final delta = fillet / r;
      final start = thetaL - delta;
      final sweep = thetaR - thetaL - 2 * math.pi + 2 * delta;
      path
        ..lineTo(cx - halfWidth, top)
        ..quadraticBezierTo(
          cx - dx,
          top,
          cx + r * math.cos(start),
          cy + r * math.sin(start),
        )
        ..arcTo(rect, start, sweep, false)
        ..quadraticBezierTo(cx + dx, top, cx + halfWidth, top);
    case OmniNotchShape.none:
      break;
  }

  path.lineTo(size.width - rR, top);
  if (rR > 0) {
    path.quadraticBezierTo(size.width, top, size.width, top + rR);
  }
  if (rCorner > 0) {
    path
      ..lineTo(size.width, bottom - rCorner)
      ..quadraticBezierTo(size.width, bottom, size.width - rCorner, bottom)
      ..lineTo(rCorner, bottom)
      ..quadraticBezierTo(0, bottom, 0, bottom - rCorner);
  } else {
    path
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom);
  }
  return path..close();
}

class _CurvedNotchBarPainter extends CustomPainter {
  const _CurvedNotchBarPainter({
    required this.notchCenterX,
    required this.cut,
    required this.topOffset,
    required this.cornerRadius,
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.borderColor,
    required this.borderWidth,
    required this.shadows,
  });

  final double notchCenterX;
  final _NotchCut cut;
  final double topOffset;
  final double cornerRadius;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildNotchedBarPath(
      size: size,
      topOffset: topOffset,
      notchCenterX: notchCenterX,
      cut: cut,
      cornerRadius: cornerRadius,
    );

    for (final s in shadows) {
      canvas
        ..save()
        ..translate(s.offset.dx, s.offset.dy)
        ..drawPath(path, s.toPaint())
        ..restore();
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    if (backgroundGradient != null) {
      fillPaint.shader = backgroundGradient!.createShader(
        Rect.fromLTWH(0, topOffset, size.width, size.height - topOffset),
      );
    } else {
      fillPaint.color = backgroundColor;
    }
    canvas.drawPath(path, fillPaint);

    if (borderWidth > 0 && borderColor.a > 0) {
      final strokePaint = Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvedNotchBarPainter old) =>
      old.notchCenterX != notchCenterX ||
      old.cut != cut ||
      old.topOffset != topOffset ||
      old.cornerRadius != cornerRadius ||
      old.backgroundColor != backgroundColor ||
      old.backgroundGradient != backgroundGradient ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      !listEquals(old.shadows, shadows);
}

class _CurvedNotchClipper extends CustomClipper<Path> {
  const _CurvedNotchClipper({
    required this.notchCenterX,
    required this.cut,
    required this.topOffset,
    required this.cornerRadius,
  });

  final double notchCenterX;
  final _NotchCut cut;
  final double topOffset;
  final double cornerRadius;

  @override
  Path getClip(Size size) => _buildNotchedBarPath(
    size: size,
    topOffset: topOffset,
    notchCenterX: notchCenterX,
    cut: cut,
    cornerRadius: cornerRadius,
  );

  @override
  bool shouldReclip(covariant _CurvedNotchClipper old) =>
      old.notchCenterX != notchCenterX ||
      old.cut != cut ||
      old.topOffset != topOffset ||
      old.cornerRadius != cornerRadius;
}

class _SpotlightGlowPainter extends CustomPainter {
  const _SpotlightGlowPainter({
    required this.centerX,
    required this.barWidth,
    required this.color,
    required this.isDark,
  });

  final double centerX;
  final double barWidth;
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = centerX
        .clamp(
          barWidth * 0.6,
          math.max(barWidth * 0.6, size.width - barWidth * 0.6),
        )
        .toDouble();
    final halfTop = barWidth * 0.45;
    final halfBottom = barWidth * 0.92;
    final beamBottom = size.height * 0.88;

    final cone = Path()
      ..moveTo(cx - halfTop, 3)
      ..lineTo(cx + halfTop, 3)
      ..lineTo(cx + halfBottom, beamBottom)
      ..lineTo(cx - halfBottom, beamBottom)
      ..close();

    final beamPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: isDark ? 0.34 : 0.22),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(cx - halfBottom, 3, halfBottom * 2, beamBottom),
          );
    canvas.drawPath(cone, beamPaint);

    final barRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, 2), width: barWidth, height: 3.6),
      const Radius.circular(3),
    );
    final barPaint = Paint()..color = color;
    canvas.drawRRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightGlowPainter old) =>
      old.centerX != centerX ||
      old.barWidth != barWidth ||
      old.color != color ||
      old.isDark != isDark;
}
