import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafePop on BuildContext {
  /// Pops when there is a page to return to; otherwise (deep link, web
  /// refresh) navigates to [fallback] instead of throwing.
  void popOrGo([String fallback = '/garage']) => canPop() ? pop() : go(fallback);
}
