import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// لوجو كوتشينج الرسمي — زهرة التوازن
/// 6 بتلات تمثل 6 محاور الحياة (عمل، علاقات، صحة، مال، روح، تطوير)
/// 3 بتلات فيروزية + 3 ذهبية + مركز أبيض + نقطة فيروزية داخلية
class CoachingLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  final bool darkMode;

  const CoachingLogo({
    super.key,
    this.size = 80,
    this.withBackground = true,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = CustomPaint(
      size: Size(size, size),
      painter: _FlowerPainter(darkMode: darkMode),
    );

    if (!withBackground) return logo;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: darkMode ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.22),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: logo,
    );
  }
}

class _FlowerPainter extends CustomPainter {
  final bool darkMode;
  _FlowerPainter({this.darkMode = false});

  static const _teal1 = Color(0xFF22909A);
  static const _teal2 = Color(0xFF1A6B72);
  static const _gold1 = Color(0xFFFFD166);
  static const _gold2 = Color(0xFFF5A623);

  @override
  void paint(Canvas canvas, Size size) {
    // SVG viewBox = 160×160, scale to actual widget size
    final s = size.width / 160.0;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Petal: rx=16, ry=32, center at (80,50) in SVG → offset = -30 from (80,80)
    final rx = 16.0 * s;
    final ry = 32.0 * s;
    final offsetY = -30.0 * s;

    // 6 petals: angle in radians, color, opacity
    final petals = <(double, Color, double)>[
      (0.0,               _teal1, 0.90),
      (math.pi / 3,       _teal1, 0.70),  // 60°
      (2 * math.pi / 3,   _teal1, 0.85),  // 120°
      (math.pi,           _gold2, 0.60),  // 180°
      (4 * math.pi / 3,   _gold2, 0.75),  // 240°
      (5 * math.pi / 3,   _gold2, 0.65),  // 300°
    ];

    for (final (angle, color, opacity) in petals) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, offsetY), width: rx * 2, height: ry * 2),
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    // White ring
    canvas.drawCircle(
      Offset(cx, cy),
      22.0 * s,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );

    // Teal inner circle
    canvas.drawCircle(
      Offset(cx, cy),
      16.0 * s,
      Paint()..color = _teal2..style = PaintingStyle.fill,
    );

    // White center dot
    canvas.drawCircle(
      Offset(cx, cy),
      5.0 * s,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// نسخة اللوجو مع الاسم
class CoachingLogoWithName extends StatelessWidget {
  final double logoSize;
  final bool horizontal;
  final Color textColor;

  const CoachingLogoWithName({
    super.key,
    this.logoSize = 60,
    this.horizontal = false,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final nameWidget = Text(
      'كوتشينج',
      style: TextStyle(
        color: textColor,
        fontSize: logoSize * 0.45,
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
        letterSpacing: 1.2,
      ),
    );

    final taglineWidget = Text(
      'طوّر نفسك، حقّق أهدافك',
      style: TextStyle(
        color: textColor.withOpacity(0.8),
        fontSize: logoSize * 0.22,
        fontFamily: 'Cairo',
      ),
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoachingLogo(size: logoSize, withBackground: false, darkMode: true),
          const SizedBox(width: 12),
          nameWidget,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoachingLogo(size: logoSize),
        const SizedBox(height: 12),
        nameWidget,
        const SizedBox(height: 4),
        taglineWidget,
      ],
    );
  }
}
