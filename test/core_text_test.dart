import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recall/core/formatting.dart';
import 'package:recall/core/markdown_lite.dart';
import 'package:recall/core/text_direction.dart';

void main() {
  group('detectDirection', () {
    final cases = <(String, TextDirection?)>[
      ('hello', TextDirection.ltr),
      ('كتاب', TextDirection.rtl),
      ('123 كتاب', TextDirection.rtl),
      ('"book" كتاب', TextDirection.ltr),
      ('**مرحبا**', TextDirection.rtl),
      ('12345', null),
      ('', null),
      ('שלום', TextDirection.rtl),
    ];
    for (final (s, want) in cases) {
      test('"$s"', () => expect(detectDirection(s), want));
    }
  });

  group('parseMarkdownLite', () {
    test('plain text is one run', () {
      expect(parseMarkdownLite('hello'), [(text: 'hello', kind: MdKind.plain)]);
    });
    test('bold, italic and code', () {
      expect(parseMarkdownLite('a **b** *c* `d` e'), [
        (text: 'a ', kind: MdKind.plain),
        (text: 'b', kind: MdKind.bold),
        (text: ' ', kind: MdKind.plain),
        (text: 'c', kind: MdKind.italic),
        (text: ' ', kind: MdKind.plain),
        (text: 'd', kind: MdKind.code),
        (text: ' e', kind: MdKind.plain),
      ]);
    });
    test('unmatched markers stay literal', () {
      expect(parseMarkdownLite('2 * 3'), [(text: '2 * 3', kind: MdKind.plain)]);
    });
    test('Arabic inside bold', () {
      expect(parseMarkdownLite('**كتاب**').single.kind, MdKind.bold);
    });
  });

  group('wrapSelection', () {
    test('wraps the selection', () {
      const v = TextEditingValue(
        text: 'say hello now',
        selection: TextSelection(baseOffset: 4, extentOffset: 9),
      );
      final r = wrapSelection(v, '**');
      expect(r.text, 'say **hello** now');
      expect(r.selection.textInside(r.text), 'hello');
    });
    test('empty selection inserts a pair with the caret inside', () {
      const v = TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 1),
      );
      final r = wrapSelection(v, '`');
      expect(r.text, 'a``b');
      expect(r.selection.baseOffset, 2);
    });
  });

  test('latinDigits converts Arabic-Indic and Persian digits', () {
    expect(latinDigits('٨ نوفمبر ٢٠٢٦'), '8 نوفمبر 2026');
    expect(latinDigits('۱۲۳'), '123');
    expect(latinDigits('abc 5'), 'abc 5');
  });
}
