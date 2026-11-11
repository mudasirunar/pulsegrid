import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Inverted Concave Sweep with Tactical Topographic Grid,
/// Corner Telemetry Readouts, and Interconnected Mesh Nodes.
class TacticalChamferHeader extends StatelessWidget {
  final bool isDark;

  const TacticalChamferHeader({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerBg = isDark ? AppColors.surfaceDark : AppColors.primaryLight;
    final accentColor = isDark ? AppColors.accentDark : AppColors.accentLight;
    final microTextColor = isDark
        ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.65);

    return CustomPaint(
      painter: _TacticalMeshPainter(
        fillColor: headerBg,
        borderColor: accentColor,
        isDark: isDark,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + 16,
          bottom: 58,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Corner Telemetry HUD Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me_outlined, size: 11, color: microTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '37.7749° N, 122.4194° W',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: microTextColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SAT-MESH ACTIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Center Tactical Emblem with glowing halo
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.backgroundDark.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.crisis_alert_rounded,
                size: 30,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'PULSE GRID',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                color: isDark ? AppColors.textPrimaryDark : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Offline-First Incident & Resource Coordination',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TacticalMeshPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final bool isDark;

  _TacticalMeshPainter({
    required this.fillColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw base concave background
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.lineTo(0, size.height);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height - 34,
      size.width,
      size.height,
    );
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, fillPaint);

    // 2. Draw subtle background tactical grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.white).withValues(alpha: 0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height - 34), gridPaint);
    }
    for (double y = 0; y < size.height - 34; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Draw interconnected emergency node lines in background
    final nodeLinePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final nodeDotPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final nodes = [
      Offset(size.width * 0.15, size.height * 0.45),
      Offset(size.width * 0.32, size.height * 0.68),
      Offset(size.width * 0.68, size.height * 0.68),
      Offset(size.width * 0.85, size.height * 0.45),
      Offset(size.width * 0.50, size.height * 0.35),
    ];

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        canvas.drawLine(nodes[i], nodes[j], nodeLinePaint);
      }
      canvas.drawCircle(nodes[i], 2.5, nodeDotPaint);
    }

    // 4. Draw Solar Gold bottom concave accent curve
    final borderPath = Path();
    borderPath.moveTo(0, size.height);
    borderPath.quadraticBezierTo(
      size.width * 0.5,
      size.height - 34,
      size.width,
      size.height,
    );
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TacticalMeshPainter oldDelegate) {
    return oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isDark != isDark;
  }
}
