import 'package:flutter/material.dart';
import 'package:recall/core/formatting.dart';
import 'package:recall/core/text_direction.dart';

enum MdKind { plain, bold, italic, code }

typedef MdRun = ({String text, MdKind kind});

final _token = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');

/// Parses **bold**, *italic* and `code`. No nesting, by design.
List<MdRun> parseMarkdownLite(String source) {
  final runs = <MdRun>[];
  var last = 0;
  for (final m in _token.allMatches(source)) {
    if (m.start > last) {
      runs.add((text: source.substring(last, m.start), kind: MdKind.plain));
    }
    if (m.group(1) != null) {
      runs.add((text: m.group(1)!, kind: MdKind.bold));
    } else if (m.group(2) != null) {
      runs.add((text: m.group(2)!, kind: MdKind.italic));
    } else {
      runs.add((text: m.group(3)!, kind: MdKind.code));
    }
    last = m.end;
  }
  if (last < source.length) {
    runs.add((text: source.substring(last), kind: MdKind.plain));
  }
  return runs;
}

/// Wraps the selection (or inserts an empty pair) with [mark], moving the
/// caret inside. Used by the editor toolbar.
TextEditingValue wrapSelection(TextEditingValue v, String mark) {
  final sel = v.selection.isValid
      ? v.selection
      : TextSelection.collapsed(offset: v.text.length);
  final inner = sel.textInside(v.text);
  final text = v.text.replaceRange(sel.start, sel.end, '$mark$inner$mark');
  return TextEditingValue(
    text: text,
    selection: sel.isCollapsed
        ? TextSelection.collapsed(offset: sel.start + mark.length)
        : TextSelection(
            baseOffset: sel.start + mark.length,
            extentOffset: sel.end + mark.length,
          ),
  );
}

/// Renders markdown-lite with per-text direction detection.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.source, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  final String source;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final scheme = Theme.of(context).colorScheme;
    final dir = detectDirection(source) ?? Directionality.of(context);
    return Directionality(
      textDirection: dir,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            for (final r in parseMarkdownLite(source))
              TextSpan(
                text: r.text,
                style: switch (r.kind) {
                  MdKind.plain => null,
                  MdKind.bold => const TextStyle(fontWeight: FontWeight.w700),
                  MdKind.italic => const TextStyle(fontStyle: FontStyle.italic),
                  MdKind.code => TextStyle(
                    fontFamily: monoFamily,
                    fontFamilyFallback: monoFallback,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.08),
                    fontSize: (base.fontSize ?? 16) * 0.92,
                  ),
                },
              ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }
}
