import 'package:recall/core/clock.dart';
import 'package:recall/core/settings_repository.dart';
import 'package:recall/data/database/app_database.dart';
import 'package:recall/features/decks/data/deck_repository.dart';
import 'package:recall/features/stats/data/stats_repository.dart';
import 'package:recall/features/study/data/study_repository.dart';
import 'package:recall/features/study/domain/scheduler/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.persistent();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
DeckRepository deckRepository(Ref ref) =>
    DeckRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));

@Riverpod(keepAlive: true)
StudyRepository studyRepository(Ref ref) =>
    StudyRepository(ref.watch(appDatabaseProvider), ref.watch(clockProvider));

@Riverpod(keepAlive: true)
StatsRepository statsRepository(Ref ref) =>
    StatsRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
Scheduler scheduler(Ref ref) => Scheduler(ref.watch(clockProvider));
