import 'package:flutter/foundation.dart';
import '../services/odoo_api_client.dart';

/// Devise réellement configurée sur la société Odoo (`res.company.currency_id`),
/// récupérée une fois au démarrage de l'app (voir `main.dart`) plutôt que le
/// "€" auparavant en dur dans chaque écran affichant un prix. `€ 0` en
/// valeurs par défaut le temps du premier appel (ou en cas d'échec réseau,
/// non bloquant — un prix reste lisible même sans le bon symbole).
class CurrencyState extends ChangeNotifier {
  CurrencyState(this._api);

  final OdooApiClient _api;
  String _symbol = '€';
  String _position = 'after';

  String format(num amount) {
    final value = amount.toStringAsFixed(2);
    return _position == 'before' ? '$_symbol$value' : '$value $_symbol';
  }

  Future<void> refresh() async {
    final currency = await _api.getCurrency();
    _symbol = currency['symbol'] ?? _symbol;
    _position = currency['position'] ?? _position;
    notifyListeners();
  }
}
