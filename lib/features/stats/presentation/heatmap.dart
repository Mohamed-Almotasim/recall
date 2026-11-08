import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/core/formatting.dart';
import 'package:recall/features/stats/domain/stats_calculator.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

const _cell = 13.0;
const _gap = 3.0;
const _weeks = 53;
const _labelH = 20.0;

/// GitHub-style yearly heatmap. Tap a day for its details.
class StudyHeatmap extends StatefulWidget {
  const StudyHeatmap({required this.data, super.key});

  final HeatmapData data;

  @override
  State<StudyHeatmap> createState() => _StudyHeatmapState();
}

class _StudyHeatmapState extends State<StudyHeatmap> {
  DateTime? _selected;

  DateTime get _start {
    final today = widget.data.today;
    final row = today.weekday % 7; // Sunday = 0
    return DateTime(
      today.year,
      today.month,
      today.day - row - (_weeks - 1) * 7,
    );
  }

  DateTime _dateAt(int col, int row) {
    final s = _start;
    return DateTime(s.year, s.month, s.day + col * 7 + row);
  }

  void _onTap(Offset p) {
    final col = (p.dx / (_cell + _gap)).floor();
    final row = ((p.dy - _labelH) / (_cell + _gap)).floor();
    if (col < 0 || col >= _weeks || row < 0 || row > 6) return;
    final d = _dateAt(col, row);
    if (d.isAfter(widget.data.today)) return;
    setState(() => _selected = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = context.colors;
    final data = widget.data;
    final selected = _selected ?? data.today;
    final activity = data.days[selected];

    final months = <(int, String)>[];
    final fmt = DateFormat.MMM(locale);
    final dayLabel = latinDigits(DateFormat.yMMMEd(locale).format(selected));
    for (var c = 0; c < _weeks; c++) {
      final first = _dateAt(c, 0);
      if (first.isAfter(data.today)) break;
      if (c == 0 || first.day <= 7) {
        if (c == 0 && first.day > 7) continue;
        months.add((c, fmt.format(first)));
      }
    }

    final levels = [
      scheme.surfaceContainerHighest,
      for (final a in const [0.28, 0.5, 0.75, 1.0])
        scheme.primary.withValues(alpha: a),
    ];

    final summary =
        '$dayLabel: '
        '${l.reviewsOnDay(activity?.reviews ?? 0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // open on the most recent weeks
            child: Semantics(
              label: summary,
              child: GestureDetector(
                onTapUp: (d) => _onTap(d.localPosition),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(
                      _weeks * (_cell + _gap),
                      _labelH + 7 * (_cell + _gap),
                    ),
                    painter: HeatmapPainter(
                      data: data,
                      start: _start,
                      selected: selected,
                      levels: levels,
                      outline: scheme.onSurface,
                      months: months,
                      labelStyle: context.text.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(dayLabel, style: context.text.titleSmall),
        const SizedBox(height: 2),
        Text(
          activity == null
              ? l.reviewsOnDay(0)
              : '${l.reviewsOnDay(activity.reviews)} · '
                    '${l.dayDetailRecalled((activity.recallRate * 100).round())}',
          style: context.text.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(l.heatmapLess, style: context.text.labelSmall),
            const SizedBox(width: 6),
            for (final c in levels)
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 6),
            Text(l.heatmapMore, style: context.text.labelSmall),
          ],
        ),
      ],
    );
  }
}

/// Repaints only when the data, selection or colours change.
class HeatmapPainter extends CustomPainter {
  HeatmapPainter({
    required this.data,
    required this.start,
    required this.selected,
    required this.levels,
    required this.outline,
    required this.months,
    required this.labelStyle,
  });

  final HeatmapData data;
  final DateTime start;
  final DateTime selected;
  final List<Color> levels;
  final Color outline;
  final List<(int, String)> months;
  final TextStyle labelStyle;

  int _level(int reviews) {
    if (reviews == 0) return 0;
    final r = reviews / data.maxReviews;
    return r <= 0.25
        ? 1
        : r <= 0.5
        ? 2
        : r <= 0.75
        ? 3
        : 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (col, text) in months) {
      (TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout()).paint(canvas, Offset(col * (_cell + _gap), 0));
    }
    final paint = Paint();
    for (var c = 0; c < _weeks; c++) {
      for (var r = 0; r < 7; r++) {
        final d = DateTime(start.year, start.month, start.day + c * 7 + r);
        if (d.isAfter(data.today)) return;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            c * (_cell + _gap),
            _labelH + r * (_cell + _gap),
            _cell,
            _cell,
          ),
          const Radius.circular(3),
        );
        paint.color = levels[_level(data.days[d]?.reviews ?? 0)];
        canvas.drawRRect(rect, paint);
        if (d == selected) {
          canvas.drawRRect(
            rect.inflate(1.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = outline,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(HeatmapPainter old) =>
      old.data != data ||
      old.selected != selected ||
      old.start != start ||
      !listEquals(old.levels, levels) ||
      !listEquals(old.months, months) ||
      old.outline != outline;
}
