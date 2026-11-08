import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/domain/study_state.dart';
import 'package:recall/features/study/presentation/grade_style.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// End-of-session screen: a ring fills to the recall rate while a burst of
/// grade-coloured dots settles around it.
class SessionSummaryView extends StatefulWidget {
  const SessionSummaryView({
    required this.summary,
    required this.onDone,
    super.key,
  });

  final SessionSummary summary;
  final VoidCallback onDone;

  @override
  State<SessionSummaryView> createState() => _SessionSummaryViewState();
}

class _SessionSummaryViewState extends State<SessionSummaryView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.summary;
    final empty = s.reviewed == 0;
    final secs = s.duration.inSeconds;
    final colors = [
      context.grades.again,
      context.grades.hard,
      context.grades.good,
      context.grades.easy,
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                empty ? l.sessionCompleteEmpty : l.sessionCompleteTitle,
                style: context.text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (!empty) ...[
                RepaintBoundary(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final ring = Curves.easeOutCubic.transform(
                          (_c.value / 0.7).clamp(0.0, 1.0),
                        );
                        final pct = (s.recallRate * 100 * ring).round();
                        return CustomPaint(
                          painter: _RingPainter(
                            t: _c.value,
                            progress: s.recallRate * ring,
                            track: context.colors.surfaceContainerHighest,
                            accent: context.colors.primary,
                            particleColors: colors,
                            animate: !MediaQuery.disableAnimationsOf(context),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l.percentValue(pct),
                                  style: context.text.displaySmall,
                                ),
                                Text(
                                  l.accuracyLabel,
                                  style: context.text.labelMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: l.reviewedLabel,
                        value: '${s.reviewed}',
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: l.timeLabel,
                        value: l.durationMinutesSeconds(secs ~/ 60, secs % 60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.gradeBreakdown, style: context.text.titleSmall),
                ),
                const SizedBox(height: 12),
                for (final g in Grade.values)
                  _BreakdownRow(
                    label: g.label(l),
                    color: g.color(context),
                    count: s.gradeCounts[g] ?? 0,
                    max: s.gradeCounts.values.fold(1, math.max),
                    t: _c.value,
                  ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDone,
                  child: Text(l.backToDeck),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: context.text.headlineSmall),
      const SizedBox(height: 2),
      Text(
        label,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.color,
    required this.count,
    required this.max,
    required this.t,
  });

  final String label;
  final Color color;
  final int count;
  final int max;
  final double t;

  @override
  Widget build(BuildContext context) {
    final grow = Curves.easeOutCubic.transform(((t - 0.3) / 0.6).clamp(0, 1));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: context.text.bodyMedium),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: count / max * grow,
                minHeight: 10,
                color: color,
                backgroundColor: context.colors.surfaceContainerHighest,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: context.text.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.t,
    required this.progress,
    required this.track,
    required this.accent,
    required this.particleColors,
    required this.animate,
  });

  final double t;
  final double progress;
  final Color track;
  final Color accent;
  final List<Color> particleColors;
  final bool animate;

  static const _count = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const stroke = 14.0;
    final r = size.width / 2 - 34;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track,
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );

    if (!animate) return;
    // Burst starts once the ring is mostly full; deterministic so repaint is stable.
    final b = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    if (b <= 0) return;
    final rnd = math.Random(11);
    final ease = Curves.easeOutCubic.transform(b);
    for (var i = 0; i < _count; i++) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final speed = 28 + rnd.nextDouble() * 62;
      final size0 = 2.5 + rnd.nextDouble() * 3.5;
      final color = particleColors[i % particleColors.length];
      final dist = r + stroke / 2 + 6 + speed * ease;
      final sag = 10 * b * b; // slight gravity
      final p = c + Offset(math.cos(a) * dist, math.sin(a) * dist + sag);
      canvas.drawCircle(
        p,
        size0 * (1 - 0.4 * b),
        Paint()..color = color.withValues(alpha: (1 - b) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.t != t || old.progress != progress || old.track != track;
}
