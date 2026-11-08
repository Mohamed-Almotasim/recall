import 'package:flutter_test/flutter_test.dart';
import 'package:recall/features/import_export/domain/csv_import.dart';

void main() {
  group('sniffDelimiter', () {
    final cases = <(String, String, Delimiter)>[
      ('commas', 'a,b\nc,d', Delimiter.comma),
      ('tabs', 'a\tb\nc\td', Delimiter.tab),
      ('semicolons', 'a;b\nc;d', Delimiter.semicolon),
      ('none defaults to comma', 'hello', Delimiter.comma),
      ('tabs win over stray commas', 'a, b\tc\nd\te', Delimiter.tab),
    ];
    for (final (name, text, want) in cases) {
      test(name, () => expect(sniffDelimiter(text), want));
    }
  });

  group('parseTable', () {
    test('plain rows and trimming', () {
      expect(parseTable('a, b\nc ,d', Delimiter.comma), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });
    test('quoted field with delimiter, newline and escaped quote', () {
      final rows = parseTable(
        '"hello, world","say ""hi""\nthere"\nx,y',
        Delimiter.comma,
      );
      expect(rows[0], ['hello, world', 'say "hi"\nthere']);
      expect(rows[1], ['x', 'y']);
    });
    test('TSV', () {
      expect(parseTable('كتاب\tbook\nماء\twater', Delimiter.tab), [
        ['كتاب', 'book'],
        ['ماء', 'water'],
      ]);
    });
    test('BOM, CRLF and blank lines', () {
      expect(parseTable('﻿a,b\r\n\r\nc,d\r\n', Delimiter.comma), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });
    test('semicolon', () {
      expect(parseTable('a;b', Delimiter.semicolon), [
        ['a', 'b'],
      ]);
    });
    test('numbers stay strings', () {
      expect(parseTable('1,2.50', Delimiter.comma), [
        ['1', '2.50'],
      ]);
    });
    test(
      'empty input',
      () => expect(parseTable('  \n', Delimiter.comma), isEmpty),
    );
  });

  group('ColumnMapping', () {
    test('suggest', () {
      expect(ColumnMapping.suggest(3).roles, [
        ColumnRole.front,
        ColumnRole.back,
        ColumnRole.skip,
      ]);
      expect(ColumnMapping.suggest(1).isValid, isFalse);
    });
    test('assigning a role moves it from the previous column', () {
      final m = ColumnMapping.suggest(3).withRole(2, ColumnRole.front);
      expect(m.roles, [ColumnRole.skip, ColumnRole.back, ColumnRole.front]);
      expect(m.frontIndex, 2);
    });
    test('skipping a column invalidates the mapping', () {
      expect(
        ColumnMapping.suggest(2).withRole(1, ColumnRole.skip).isValid,
        isFalse,
      );
    });
  });

  group('applyMapping', () {
    final rows = [
      ['Q', 'A', 'note'],
      ['one', '1', 'x'],
      ['', '2', 'x'],
      ['three', '', 'x'],
      ['four'],
      ['five', '5', 'x'],
    ];
    test('header skipped, bad rows counted', () {
      final r = applyMapping(rows, ColumnMapping.suggest(3), hasHeader: true);
      expect([for (final c in r.cards) c.front], ['one', 'five']);
      expect(r.skipped, 3);
    });
    test('without header the first row is a card', () {
      final r = applyMapping(rows, ColumnMapping.suggest(3), hasHeader: false);
      expect(r.cards.first.front, 'Q');
    });
    test('swapped mapping swaps sides', () {
      final m = ColumnMapping.suggest(3)
          .withRole(0, ColumnRole.back)
          .withRole(1, ColumnRole.front);
      final r = applyMapping(rows, m, hasHeader: true);
      expect(r.cards.first.front, '1');
      expect(r.cards.first.back, 'one');
    });
    test('invalid mapping yields nothing', () {
      final r = applyMapping(
        rows,
        const ColumnMapping([ColumnRole.front, ColumnRole.skip]),
        hasHeader: false,
      );
      expect(r.cards, isEmpty);
    });
  });

  test('looksLikeHeader', () {
    expect(
      looksLikeHeader([
        ['Question', 'Answer'],
        ['a', 'b'],
      ]),
      isTrue,
    );
    expect(
      looksLikeHeader([
        ['a', 'b'],
        ['c', 'd'],
      ]),
      isFalse,
    );
  });
}
