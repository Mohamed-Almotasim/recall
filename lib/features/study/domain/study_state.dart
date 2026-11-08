import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recall/features/decks/domain/models.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';

part 'study_state.freezed.dart';

@freezed
abstract class SessionData with _$SessionData {
  const factory SessionData({
    required StudyCard current,
    required List<StudyCard> queue,
    required int totalCards,
    required int completedCards,
    required Map<Grade, int> gradeCounts,
    required Map<Grade, Duration> preview,
    required DateTime shownAt,
    required DateTime startedAt,
    @Default(false) bool saveFailed,
  }) = _SessionData;
}

@freezed
abstract class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    required int reviewed,
    required Map<Grade, int> gradeCounts,
    required Duration duration,
  }) = _SessionSummary;

  const SessionSummary._();

  int get recalled =>
      (gradeCounts[Grade.good] ?? 0) + (gradeCounts[Grade.easy] ?? 0);

  /// Share of answers that were Good or Easy, 0..1.
  double get recallRate => reviewed == 0 ? 0 : recalled / reviewed;
}

/// Explicit state machine for one study session.
@freezed
sealed class StudyState with _$StudyState {
  const factory StudyState.loading() = StudyLoading;
  const factory StudyState.showingFront({required SessionData data}) =
      ShowingFront;
  const factory StudyState.showingBack({required SessionData data}) =
      ShowingBack;
  const factory StudyState.grading({
    required SessionData data,
    required Grade grade,
  }) = Grading;
  const factory StudyState.finished({required SessionSummary summary}) =
      StudyFinished;
}
