import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../services/odoo_api_client.dart';
import '../state/auth_state.dart';

/// Déconnexion complète : efface le cookie de session côté app ET l'état
/// local (`AuthState`). N'appeler que `AuthState.logout()` seul laisse le
/// cookie de session Odoo valide dans `flutter_secure_storage`, exploitable
/// directement contre l'API en contournant l'app tant qu'il n'a pas expiré
/// côté serveur (bug trouvé à l'audit sécurité du 2026-07-19,
/// `ReauthPinScreen` oubliait `clearSession()`) — centralisé ici pour ne
/// plus dupliquer/oublier les deux appels séparément à chaque écran.
///
/// Pas utilisé par `delete_account_dialog.dart` : le `context` y reste
/// valide après un `await` (dialog non fermé entre-temps en cas d'erreur),
/// mais par prudence ce fichier résout `OdooApiClient`/`AuthState` une
/// fois en haut de la fonction plutôt que de rappeler `context.read`
/// après l'appel réseau — cohérent avec cette fonction, pas besoin de la
/// réutiliser telle quelle ici.
void fullLogout(BuildContext context) {
  context.read<OdooApiClient>().clearSession();
  context.read<AuthState>().logout();
}
