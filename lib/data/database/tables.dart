import 'package:drift/drift.dart';

@DataClassName('DeckRow')
class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get colorValue => integer()();
  TextColumn get iconKey => text().withDefault(const Constant('book'))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId =>
      integer().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Latest scheduling result per card. Stats never read this; they use logs.
@DataClassName('CardStateRow')
class CardStates extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get phase => integer()();
  IntColumn get stepIndex => integer()();
  RealColumn get ease => real()();
  IntColumn get intervalDays => integer()();
  IntColumn get reps => integer()();
  IntColumn get lapses => integer()();
  DateTimeColumn get due => dateTime()();
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {cardId};
}

@TableIndex(name: 'review_logs_time', columns: {#reviewedAt})
@TableIndex(name: 'review_logs_card', columns: {#cardId})
@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer()();
  IntColumn get deckId => integer()();
  DateTimeColumn get reviewedAt => dateTime()();
  IntColumn get grade => integer()();
  IntColumn get phaseBefore => integer()();
  IntColumn get intervalBefore => integer()();
  IntColumn get intervalAfter => integer()();
  RealColumn get easeAfter => real()();
  IntColumn get elapsedDays => integer()();
  IntColumn get durationMs => integer()();
}

@DataClassName('SettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
