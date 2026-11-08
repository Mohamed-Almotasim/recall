import 'package:flutter/material.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/features/study/presentation/grade_style.dart';
import 'package:recall/features/study/presentation/interval_label.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

/// Four grade buttons with the next-interval hint: the accessible
/// alternative to swiping.
class GradeBar extends StatelessWidget {
  const GradeBar({
    required this.preview,
    required this.enabled,
    required this.onGrade,
    super.key,
  });

  final Map<Grade, Duration> preview;
  final bool enabled;
  final ValueChanged<Grade> onGrade;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        for (final g in Grade.values) ...[
          if (g != Grade.again) const SizedBox(width: 8),
          Expanded(
            child: _GradeButton(
              grade: g,
              interval: intervalLabel(l, preview[g] ?? Duration.zero),
              enabled: enabled,
              onTap: () => onGrade(g),
            ),
          ),
        ],
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({
    required this.grade,
    required this.interval,
    required this.enabled,
    required this.onTap,
  });

  final Grade grade;
  final String interval;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = grade.color(context);
    final name = grade.label(l);
    return Semantics(
      button: true,
      enabled: enabled,
      label: l.gradeButtonSemantics(name, interval),
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Tooltip(
        message: l.gradeButtonHint(name, interval),
        child: Material(
          color: color.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: context.text.labelLarge?.copyWith(color: color),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    interval,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
