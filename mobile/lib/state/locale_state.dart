import 'package:flutter/foundation.dart';

/// Répercute manuellement un changement de langue à travers l'app.
///
/// Bug trouvé par l'utilisateur (2026-07-20) : `context.setLocale()`
/// (easy_localization) ne reconstruit pas les pages déjà montées dans la
/// barre de navigation à onglets — `StatefulShellRoute` garde chaque
/// onglet vivant via un `IndexedStack`, hors de portée effective du
/// mécanisme de dépendance interne d'easy_localization dans ce contexte :
/// la barre du bas ne se mettait à jour qu'après un changement d'onglet,
/// et les boutons de Profil restaient bloqués dans l'ancienne langue tant
/// qu'aucune navigation ne forçait un rebuild.
///
/// Plutôt que de recharger toute l'app (perte de la pile de navigation en
/// cours), ce `ChangeNotifier` — mécanisme déjà fiable partout ailleurs
/// dans l'app (`CartState`, `AuthState`...) — force un rebuild ciblé des
/// écrans concernés via `context.watch<LocaleState>()` : `ScreenPlaceholder`,
/// `MainTabScaffold`, `HomeScreen`.
class LocaleState extends ChangeNotifier {
  void notifyLocaleChanged() => notifyListeners();
}
