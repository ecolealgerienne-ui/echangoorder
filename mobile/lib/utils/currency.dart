import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../state/currency_state.dart';

/// Raccourci pour `context.watch<CurrencyState>().format(amount)`, utilisé
/// partout où un prix est affiché (voir `state/currency_state.dart`).
String formatPrice(BuildContext context, num amount) {
  return context.watch<CurrencyState>().format(amount);
}
