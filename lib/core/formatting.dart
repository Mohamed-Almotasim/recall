/// Replaces Arabic-Indic digits with Western digits so dates match the
/// numbers elsewhere in the UI (which are always Western).
String latinDigits(String s) => s.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
  final c = m[0]!.codeUnitAt(0);
  return String.fromCharCode(0x30 + (c >= 0x06F0 ? c - 0x06F0 : c - 0x0660));
});

/// Monospace stack that also resolves on platforms without a 'monospace' alias.
const monoFamily = 'monospace';
const monoFallback = ['Consolas', 'Menlo', 'Courier New', 'Roboto Mono'];
