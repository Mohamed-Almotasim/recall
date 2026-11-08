// Self-contained: depends only on Flutter. Copy this file into any project.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated splash: a card is drawn, flips from "?" to a check mark, a row of
/// dots spaces out like review intervals, and the wordmark settles in.
class RecallSplash extends StatefulWidget {
  const RecallSplash({
    required this.onFinished,
    super.key,
    this.accent = const Color(0xFF1F6F5C),
    this.ink = const Color(0xFF1B1A17),
    this.paper = const Color(0xFFF6F2EA),
    this.cardColor = const Color(0xFFFFFFFF),
    this.title = 'Recall',
    this.fontFamily,
    this.duration = const Duration(milliseconds: 2800),
  });

  final VoidCallback onFinished;
  final Color accent;
  final Color ink;
  final Color paper;
  final Color cardColor;
  final String title;
  final String? fontFamily;
  final Duration duration;

  @override
  State<RecallSplash> createState() => _RecallSplashState();
}

class _RecallSplashState extends State<RecallSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 500), _finish),
      );
    } else {
      unawaited(
        _c.forward().whenComplete(
          () =>
              Future<void>.delayed(const Duration(milliseconds: 350), _finish),
        ),
      );
    }
  }

  void _finish() {
    if (mounted) widget.onFinished();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: widget.paper,
    child: Center(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: const Size(260, 360),
            painter: _SplashPainter(
              t: _c.value,
              accent: widget.accent,
              ink: widget.ink,
              card: widget.cardColor,
              title: widget.title,
              fontFamily: widget.fontFamily,
            ),
          ),
        ),
      ),
    ),
  );
}

double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _SplashPainter extends CustomPainter {
  _SplashPainter({
    required this.t,
    required this.accent,
    required this.ink,
    required this.card,
    required this.title,
    required this.fontFamily,
  });

  final double t;
  final Color accent;
  final Color ink;
  final Color card;
  final String title;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    const cardW = 150.0;
    const cardH = 196.0;
    final center = Offset(size.width / 2, 110);
    final rect = Rect.fromCenter(center: center, width: cardW, height: cardH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final draw = _seg(t, 0, 0.34, Curves.easeInOutCubic);
    final fill = _seg(t, 0.28, 0.42);
    final flip = _seg(t, 0.42, 0.72, Curves.easeInOutCubic);
    final angle = math.pi * flip;
    final showBack = angle > math.pi / 2;

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateY(angle);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..transform(m.storage)
      ..translate(-center.dx, -center.dy);

    // Card body and shadow.
    if (fill > 0) {
      canvas
        ..drawShadow(
          Path()..addRRect(rrect),
          Colors.black.withValues(alpha: 0.5 * fill),
          10 * fill,
          false,
        )
        ..drawRRect(rrect, Paint()..color = card.withValues(alpha: fill));
    }

    // Outline drawn along the perimeter.
    final outline = Path()..addRRect(rrect);
    final metric = outline.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * draw),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(accent, ink.withValues(alpha: 0.18), fill)!,
    );

    // Face content. The back face is mirrored so it reads correctly.
    if (draw >= 1) {
      canvas.save();
      if (showBack) {
        canvas
          ..translate(center.dx, 0)
          ..scale(-1, 1)
          ..translate(-center.dx, 0);
        final check = Path()
          ..moveTo(center.dx - 26, center.dy + 2)
          ..lineTo(center.dx - 6, center.dy + 24)
          ..lineTo(center.dx + 30, center.dy - 22);
        canvas.drawPath(
          check,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = accent,
        );
      } else {
        _text(
          canvas,
          '?',
          center,
          fontSize: 84,
          color: ink.withValues(alpha: 0.85),
          weight: FontWeight.w600,
        );
      }
      canvas.restore();
    }
    canvas.restore();

    // Spaced-repetition dots: gaps double, like intervals 1, 2, 4, 8.
    const gaps = [0.0, 1.0, 3.0, 7.0, 15.0];
    const span = 190.0;
    final dotY = center.dy + cardH / 2 + 46;
    final left = center.dx - span / 2;
    for (var i = 0; i < gaps.length; i++) {
      final p = _seg(t, 0.66 + i * 0.045, 0.80 + i * 0.045, Curves.easeOutBack);
      if (p <= 0) continue;
      final x = left + span * gaps[i] / gaps.last;
      final strength = i / (gaps.length - 1);
      canvas.drawCircle(
        Offset(x, dotY),
        (3.5 + 2.5 * strength) * p,
        Paint()
          ..color = Color.lerp(ink.withValues(alpha: 0.35), accent, strength)!,
      );
    }

    // Wordmark.
    final w = _seg(t, 0.78, 1, Curves.easeOutCubic);
    if (w > 0) {
      _text(
        canvas,
        title,
        Offset(center.dx, dotY + 52 - 6 * (1 - w)),
        fontSize: 40,
        color: ink.withValues(alpha: w),
        weight: FontWeight.w600,
        spacing: 6 * (1 - w) - 0.5,
      );
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset center, {
    required double fontSize,
    required Color color,
    required FontWeight weight,
    double spacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          letterSpacing: spacing,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_SplashPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.ink != ink ||
      old.card != card ||
      old.title != title;
}
