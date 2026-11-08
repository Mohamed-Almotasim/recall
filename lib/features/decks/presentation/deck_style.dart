import 'package:flutter/material.dart';

const deckIcons = <String, IconData>{
  'book': Icons.menu_book_outlined,
  'code': Icons.code,
  'translate': Icons.translate,
  'public': Icons.public,
  'science': Icons.science_outlined,
  'music': Icons.music_note_outlined,
  'history': Icons.history_edu_outlined,
  'calculate': Icons.calculate_outlined,
  'palette': Icons.palette_outlined,
  'health': Icons.favorite_border,
};

IconData deckIcon(String key) => deckIcons[key] ?? Icons.menu_book_outlined;

/// Muted deck colours. None are purple.
const deckColors = <int>[
  0xFF1F6F5C,
  0xFF3D5A80,
  0xFF884E00,
  0xFF9C4A3C,
  0xFF5F7A3A,
  0xFF4A4F57,
];
