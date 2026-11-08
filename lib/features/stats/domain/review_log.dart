import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

part 'review_log.freezed.dart';

@freezed
abstract class ReviewLog with _$ReviewLog {
  const factory ReviewLog({
    required int cardId,
    required int deckId,
    required DateTime reviewedAt,
    required Grade grade,
    required Phase phaseBefore,
    required int intervalBefore,
    required int intervalAfter,
    required double easeAfter,
    required int elapsedDays,
    required int durationMs,
  }) = _ReviewLog;
}
