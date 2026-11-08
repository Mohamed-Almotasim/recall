// Pure Dart: delimited text -> cards.
import 'package:csv/csv.dart';
import 'package:recall/features/decks/domain/models.dart';

enum Delimiter {
  comma(','),
  tab('\t'),
  semicolon(';');

  Delimiter(this.char);
  final String char;
}

/// Picks the separator that appears most often in the first lines.
Delimiter sniffDelimiter(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .take(5)
      .toList();
  var best = Delimiter.comma;
  var bestCount = 0;
  for (final d in Delimiter.values) {
    final n = lines.fold(0, (a, l) => a + d.char.allMatches(l).length);
    if (n > bestCount) {
      best = d;
      bestCount = n;
    }
  }
  return best;
}

/// Parses [text] into trimmed string cells. Handles quotes, escaped quotes,
/// a leading BOM and ragged rows.
List<List<String>> parseTable(String text, Delimiter d) {
  const bom = 0xFEFF;
  final clean = text.isNotEmpty && text.codeUnitAt(0) == bom
      ? text.substring(1)
      : text;
  if (clean.trim().isEmpty) return const [];
  final rows = Csv(fieldDelimiter: d.char, autoDetect: false).decode(clean);
  return [
    for (final r in rows) [for (final c in r) '$c'.trim()],
  ];
}

enum ColumnRole { skip, front, back }

class ColumnMapping {
  const ColumnMapping(this.roles);

  /// Front = column 0, back = column 1 when there are at least two columns.
  factory ColumnMapping.suggest(int columns) =>
      ColumnMapping(List.generate(columns, _suggested));

  static ColumnRole _suggested(int i) => switch (i) {
    0 => ColumnRole.front,
    1 => ColumnRole.back,
    _ => ColumnRole.skip,
  };

  final List<ColumnRole> roles;

  int get frontIndex => roles.indexOf(ColumnRole.front);
  int get backIndex => roles.indexOf(ColumnRole.back);
  bool get isValid => frontIndex >= 0 && backIndex >= 0;

  /// Sets one column's role. Front and back are unique: assigning one moves it.
  ColumnMapping withRole(int column, ColumnRole role) => ColumnMapping(
    List.generate(roles.length, (i) => _roleAt(i, column, role)),
  );

  ColumnRole _roleAt(int i, int column, ColumnRole role) {
    if (i == column) return role;
    final taken = role != ColumnRole.skip && roles[i] == role;
    return taken ? ColumnRole.skip : roles[i];
  }
}

class ImportResult {
  const ImportResult({required this.cards, required this.skipped});
  final List<CardDraft> cards;

  /// Rows dropped because front or back was empty or missing.
  final int skipped;
}

ImportResult applyMapping(
  List<List<String>> rows,
  ColumnMapping m, {
  required bool hasHeader,
}) {
  if (!m.isValid) return const ImportResult(cards: [], skipped: 0);
  final body = hasHeader ? rows.skip(1) : rows;
  final cards = <CardDraft>[];
  var skipped = 0;
  for (final r in body) {
    final f = m.frontIndex < r.length ? r[m.frontIndex] : '';
    final b = m.backIndex < r.length ? r[m.backIndex] : '';
    if (f.isEmpty || b.isEmpty) {
      skipped++;
    } else {
      cards.add(CardDraft(front: f, back: b));
    }
  }
  return ImportResult(cards: cards, skipped: skipped);
}

const _headerWords = {
  'front',
  'back',
  'question',
  'answer',
  'term',
  'definition',
  'word',
  'meaning',
  'english',
  'arabic',
};

/// True when the first row looks like column titles.
bool looksLikeHeader(List<List<String>> rows) =>
    rows.length > 1 &&
    rows.first.any((c) => _headerWords.contains(c.toLowerCase()));
