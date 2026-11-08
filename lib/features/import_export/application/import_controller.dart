import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/features/import_export/domain/csv_import.dart';
import 'package:recall/features/import_export/domain/deck_json.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'import_controller.freezed.dart';
part 'import_controller.g.dart';

@freezed
abstract class ImportState with _$ImportState {
  const factory ImportState({
    @Default('') String text,
    @Default(Delimiter.comma) Delimiter delimiter,
    @Default(false) bool hasHeader,
    @Default('') String deckName,
    @Default(ColumnMapping([])) ColumnMapping mapping,
    @Default([]) List<List<String>> rows,
  }) = _ImportState;

  const ImportState._();

  int get columnCount => rows.fold(0, (m, r) => r.length > m ? r.length : m);

  ImportResult get result => applyMapping(rows, mapping, hasHeader: hasHeader);

  bool get canImport =>
      mapping.isValid && result.cards.isNotEmpty && deckName.trim().isNotEmpty;
}

@riverpod
class ImportController extends _$ImportController {
  @override
  ImportState build() => const ImportState();

  /// Replaces the source text, re-detecting separator, header and columns.
  void setText(String text, {String? suggestedName}) {
    final d = sniffDelimiter(text);
    final rows = parseTable(text, d);
    final cols = rows.fold(0, (m, r) => r.length > m ? r.length : m);
    state = state.copyWith(
      text: text,
      delimiter: d,
      rows: rows,
      hasHeader: looksLikeHeader(rows),
      mapping: ColumnMapping.suggest(cols),
      deckName: state.deckName.isEmpty ? (suggestedName ?? '') : state.deckName,
    );
  }

  void setDelimiter(Delimiter d) {
    final rows = parseTable(state.text, d);
    final cols = rows.fold(0, (m, r) => r.length > m ? r.length : m);
    state = state.copyWith(
      delimiter: d,
      rows: rows,
      hasHeader: looksLikeHeader(rows),
      mapping: ColumnMapping.suggest(cols),
    );
  }

  void setHasHeader({required bool value}) =>
      state = state.copyWith(hasHeader: value);

  void setDeckName(String name) => state = state.copyWith(deckName: name);

  void setRole(int column, ColumnRole role) =>
      state = state.copyWith(mapping: state.mapping.withRole(column, role));

  /// Creates the deck. Returns its id.
  Future<int> commit({required int colorValue}) {
    final s = state;
    return ref
        .read(deckRepositoryProvider)
        .createDeckWithCards(
          name: s.deckName.trim(),
          colorValue: colorValue,
          iconKey: 'translate',
          cards: s.result.cards,
        );
  }

  /// Imports a Recall JSON file. Throws [FormatException] when invalid.
  Future<int> importJson(String source) {
    final b = decodeDeck(source);
    return ref
        .read(deckRepositoryProvider)
        .createDeckWithCards(
          name: b.name,
          description: b.description,
          colorValue: b.colorValue,
          iconKey: b.iconKey,
          cards: b.cards,
        );
  }
}
