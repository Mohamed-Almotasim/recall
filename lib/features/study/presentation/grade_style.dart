import 'package:flutter/material.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

extension GradeUi on Grade {
  Color color(BuildContext context) {
    final g = context.grades;
    return switch (this) {
      Grade.again => g.again,
      Grade.hard => g.hard,
      Grade.good => g.good,
      Grade.easy => g.easy,
    };
  }

  String label(AppLocalizations l) => switch (this) {
    Grade.again => l.gradeAgain,
    Grade.hard => l.gradeHard,
    Grade.good => l.gradeGood,
    Grade.easy => l.gradeEasy,
  };

  /// Physical swipe direction: left, up, right, down.
  Offset get direction => switch (this) {
    Grade.again => const Offset(-1, 0),
    Grade.hard => const Offset(0, -1),
    Grade.good => const Offset(1, 0),
    Grade.easy => const Offset(0, 1),
  };

  IconData get icon => switch (this) {
    Grade.again => Icons.refresh,
    Grade.hard => Icons.trending_flat,
    Grade.good => Icons.check,
    Grade.easy => Icons.bolt,
  };
}

/// Which grade a drag offset points at. Pure so it can be unit tested.
Grade gradeForOffset(Offset o) => o.dx.abs() >= o.dy.abs()
    ? (o.dx < 0 ? Grade.again : Grade.good)
    : (o.dy < 0 ? Grade.hard : Grade.easy);
