import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafeBack on BuildContext {
  /// Pops when possible, otherwise runs [fallback] (deep-link entry).
  void popOr(void Function() fallback) => canPop() ? pop() : fallback();
}
