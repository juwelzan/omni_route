part of 'omni_bottom_navigation.dart';

/// Builds a mathematically smooth $C^1$ cubic Bézier inward wave/cradle notch
/// path along the top edge of a docked or rounded bar.
Path _buildCurvedNotchPath({
  required Size size,
  required double topOffset,
  required double notchCenterX,
  required double notchRadius,
  required double notchDepth,
  required double cornerRadius,
}) {
  final rCorner = cornerRadius
      .clamp(0.0, math.min(size.width * 0.25, 36.0))
      .toDouble();
  final cx = notchCenterX
      .clamp(
        rCorner + notchRadius * 0.9,
        math.max(
          rCorner + notchRadius * 0.9,
          size.width - rCorner - notchRadius * 0.9,
        ),
      )
      .toDouble();
  final leftShoulder = math.max(rCorner, cx - notchRadius * 1.48);
  final rightShoulder = math.min(size.width - rCorner, cx + notchRadius * 1.48);
  final bottom = size.height;

  final path = Path()
    ..moveTo(0, topOffset + rCorner);

  if (rCorner > 0) {
    path.quadraticBezierTo(0, topOffset, rCorner, topOffset);
  } else {
    path.lineTo(0, topOffset);
  }

  path
    ..lineTo(leftShoulder, topOffset)
    ..cubicTo(
      cx - notchRadius * 0.78,
      topOffset,
      cx - notchRadius * 0.68,
      topOffset + notchDepth,
      cx,
      topOffset + notchDepth,
    )
    ..cubicTo(
      cx + notchRadius * 0.68,
      topOffset + notchDepth,
      cx + notchRadius * 0.78,
      topOffset,
      rightShoulder,
      topOffset,
    )
    ..lineTo(size.width - rCorner, topOffset);

  if (rCorner > 0) {
    path
      ..quadraticBezierTo(size.width, topOffset, size.width, topOffset + rCorner)
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
    required this.notchRadius,
    required this.notchDepth,
    required this.topOffset,
    required this.cornerRadius,
    required this.backgroundColor,
    required this.backgroundGradient,
    required this.borderColor,
    required this.borderWidth,
    required this.shadows,
  });

  final double notchCenterX;
  final double notchRadius;
  final double notchDepth;
  final double topOffset;
  final double cornerRadius;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildCurvedNotchPath(
      size: size,
      topOffset: topOffset,
      notchCenterX: notchCenterX,
      notchRadius: notchRadius,
      notchDepth: notchDepth,
      cornerRadius: cornerRadius,
    );

    for (final s in shadows) {
      final shadowPaint = s.toPaint();
      canvas
        ..save()
        ..translate(s.offset.dx, s.offset.dy)
        ..drawPath(path, shadowPaint)
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
      old.notchRadius != notchRadius ||
      old.notchDepth != notchDepth ||
      old.topOffset != topOffset ||
      old.cornerRadius != cornerRadius ||
      old.backgroundColor != backgroundColor ||
      old.backgroundGradient != backgroundGradient ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.shadows != shadows;
}

class _CurvedNotchClipper extends CustomClipper<Path> {
  const _CurvedNotchClipper({
    required this.notchCenterX,
    required this.notchRadius,
    required this.notchDepth,
    required this.topOffset,
    required this.cornerRadius,
  });

  final double notchCenterX;
  final double notchRadius;
  final double notchDepth;
  final double topOffset;
  final double cornerRadius;

  @override
  Path getClip(Size size) => _buildCurvedNotchPath(
    size: size,
    topOffset: topOffset,
    notchCenterX: notchCenterX,
    notchRadius: notchRadius,
    notchDepth: notchDepth,
    cornerRadius: cornerRadius,
  );

  @override
  bool shouldReclip(covariant _CurvedNotchClipper old) =>
      old.notchCenterX != notchCenterX ||
      old.notchRadius != notchRadius ||
      old.notchDepth != notchDepth ||
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
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.34 : 0.22),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(cx - halfBottom, 3, halfBottom * 2, beamBottom));
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
