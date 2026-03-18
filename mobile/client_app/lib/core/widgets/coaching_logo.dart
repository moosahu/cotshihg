import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// اللوجو الرئيسي لتطبيق Coaching
/// الفكرة: حرف C مفتوح (Coaching) + سهم صاعد (النمو والتطوير)
/// الألوان: Teal للهيكل، Gold للسهم
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
      painter: _LogoPainter(darkMode: darkMode),
    );

    if (!withBackground) return logo;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: darkMode ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: logo,
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool darkMode;
  _LogoPainter({this.darkMode = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;
    final strokeW = size.width * 0.09;

    // الدائرة المفتوحة (C)
    final arcPaint = Paint()
      ..color = darkMode ? Colors.white : AppTheme.primaryColor
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.65,
      4.4,
      false,
      arcPaint,
    );

    // السهم الصاعد
    final arrowPaint = Paint()
      ..color = AppTheme.secondaryColor
      ..strokeWidth = strokeW * 0.85
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final start = Offset(center.dx - radius * 0.38, center.dy + radius * 0.32);
    final end = Offset(center.dx + radius * 0.42, center.dy - radius * 0.42);

    canvas.drawLine(start, end, arrowPaint);

    // رأس السهم
    canvas.drawLine(end, Offset(end.dx - radius * 0.26, end.dy), arrowPaint);
    canvas.drawLine(end, Offset(end.dx, end.dy + radius * 0.26), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// نسخة نصية من اللوجو (Logo + Name)
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
      'Coaching',
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
