import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/stats/domain/stats_calculator.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// Retention by interval, drawn with CustomPainter (no chart package).
class RetentionChart extends StatelessWidget {
  const RetentionChart({required this.points, super.key});

  final List<RetentionPoint> points;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (points.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            l.retentionEmpty,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final semantics = [
      for (final p in points)
        '${p.label}: ${l.percentValue((p.retention * 100).round())}',
    ].join(', ');
    return Semantics(
      label: '${l.retentionTitle}. $semantics',
      child: SizedBox(
        height: 220,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(points.length),
          tween: Tween(begin: reduce ? 1 : 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: RetentionPainter(
                points: points,
                progress: t,
                line: scheme.primary,
                grid: scheme.outlineVariant,
                labelStyle: context.text.labelSmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                yLabels: [
                  for (final v in const [0, 25, 50, 75, 100]) l.percentValue(v),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RetentionPainter extends CustomPainter {
  RetentionPainter({
    required this.points,
    required this.progress,
    required this.line,
    required this.grid,
    required this.labelStyle,
    required this.yLabels,
  });

  final List<RetentionPoint> points;
  final double progress;
  final Color line;
  final Color grid;
  final TextStyle labelStyle;
  final List<String> yLabels;

  void _label(Canvas canvas, String s, Offset at, {bool rightAlign = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    tp.paint(
      canvas,
      Offset(
        rightAlign ? at.dx - tp.width : at.dx - tp.width / 2,
        at.dy - tp.height / 2,
      ),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const right = 14.0;
    const top = 10.0;
    const bottom = 30.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = top + h * (1 - i / 4);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      _label(canvas, yLabels[i], Offset(left - 8, y), rightAlign: true);
    }

    final n = points.length;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          left + (n == 1 ? w / 2 : w * i / (n - 1)),
          top + h * (1 - points[i].retention),
        ),
    ];
    for (var i = 0; i < n; i++) {
      _label(canvas, points[i].label, Offset(pts[i].dx, top + h + 16));
    }

    // Catmull-Rom spline through the points, as cubic Beziers.
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = pts[math.max(0, i - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[math.min(n - 1, i + 2)];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      double cy(double y) => y.clamp(top, top + h);
      path.cubicTo(c1.dx, cy(c1.dy), c2.dx, cy(c2.dy), p2.dx, p2.dy);
    }

    final area = Path.from(path)
      ..lineTo(pts.last.dx, top + h)
      ..lineTo(pts.first.dx, top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            line.withValues(alpha: 0.22 * progress),
            line.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );

    if (n > 1) {
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = line,
      );
    }
    for (var i = 0; i < n; i++) {
      final shown = n == 1 || progress >= i / (n - 1) - 0.001;
      if (!shown) continue;
      final r = 3.5 + math.min(4.0, math.sqrt(points[i].count) / 2);
      canvas
        ..drawCircle(
          pts[i],
          r + 2,
          Paint()..color = grid.withValues(alpha: 0.6),
        )
        ..drawCircle(pts[i], r, Paint()..color = line);
    }
  }

  @override
  bool shouldRepaint(RetentionPainter old) =>
      old.progress != progress ||
      !listEquals(old.points, points) ||
      old.line != line ||
      old.grid != grid ||
      !listEquals(old.yLabels, yLabels);
}
