import 'package:flutter/material.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/stats/domain/stats_calculator.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// Stacked bar: new / learning / young / mature.
class MaturityBar extends StatelessWidget {
  const MaturityBar({required this.data, super.key});

  final MaturityBreakdown data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = context.colors;
    final segments = [
      (l.cardStateNew, data.fresh, scheme.outline),
      (l.cardStateLearning, data.learning, context.grades.hard),
      (l.cardStateYoung, data.young, context.grades.easy),
      (l.cardStateMature, data.mature, context.grades.good),
    ];
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 14,
            child: data.total == 0
                ? ColoredBox(color: scheme.surfaceContainerHighest)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduce ? 1 : 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (_, n, c) in segments)
                          if (n > 0)
                            Expanded(
                              flex: (n * 1000 * t).round().clamp(1, 1 << 30),
                              child: ColoredBox(color: c),
                            ),
                        // Keeps the bar from over-filling while it grows in.
                        if (t < 1)
                          Expanded(
                            flex: ((1 - t) * data.total * 1000).round().clamp(
                              1,
                              1 << 30,
                            ),
                            child: ColoredBox(
                              color: scheme.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            for (final (label, n, c) in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$label  ', style: context.text.bodySmall),
                  Text('$n', style: context.text.labelLarge),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
