import 'package:flutter/painting.dart';

/// Direction of the first strong character, or null when there is none.
TextDirection? detectDirection(String text) {
  for (final r in text.runes) {
    if (_isRtl(r)) return TextDirection.rtl;
    if (_isLtrLetter(r)) return TextDirection.ltr;
  }
  return null;
}

bool _isRtl(int r) =>
    (r >= 0x0590 && r <= 0x08FF) ||
    (r >= 0xFB1D && r <= 0xFDFF) ||
    (r >= 0xFE70 && r <= 0xFEFF);

bool _isLtrLetter(int r) =>
    (r >= 0x41 && r <= 0x5A) ||
    (r >= 0x61 && r <= 0x7A) ||
    (r >= 0xC0 && r <= 0x24F) ||
    (r >= 0x370 && r <= 0x58F);
