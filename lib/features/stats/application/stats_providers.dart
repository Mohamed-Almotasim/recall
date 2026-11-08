import 'package:recall/app/providers.dart';
import 'package:recall/features/stats/domain/review_log.dart';
import 'package:recall/features/stats/domain/stats_calculator.dart';
import 'package:recall/features/study/domain/scheduler/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'stats_providers.g.dart';

/// Review history for the heatmap window (a little over a year).
@riverpod
Stream<List<ReviewLog>> yearLogs(Ref ref) {
  final now = ref.watch(clockProvider).now();
  final since = DateTime(now.year, now.month, now.day - 371);
  return ref.watch(statsRepositoryProvider).watchLogs(since: since);
}

@riverpod
Stream<List<CardState>> allStates(Ref ref) =>
    ref.watch(statsRepositoryProvider).watchStates();

@riverpod
HeatmapData heatmap(Ref ref) => buildHeatmap(
  ref.watch(yearLogsProvider).value ?? const [],
  ref.watch(clockProvider).now(),
);

@riverpod
List<RetentionPoint> retention(Ref ref) =>
    retentionCurve(ref.watch(yearLogsProvider).value ?? const []);

@riverpod
int streak(Ref ref) => currentStreak(ref.watch(heatmapProvider));

@riverpod
MaturityBreakdown maturityBreakdown(Ref ref) =>
    maturity(ref.watch(allStatesProvider).value ?? const []);

@riverpod
({int today, int tomorrow}) dueSoon(Ref ref) => dueForecast(
  ref.watch(allStatesProvider).value ?? const [],
  ref.watch(clockProvider).now(),
);
