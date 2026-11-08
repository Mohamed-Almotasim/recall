import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:recall/data/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Decks, Cards, CardStates, ReviewLogs, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// On-disk (or IndexedDB on web) database.
  factory AppDatabase.persistent() => AppDatabase(
    driftDatabase(
      name: 'recall',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 is the first schema. Add `if (from < 2) { ... }` steps here.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
