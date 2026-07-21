import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/locale_state.dart';
import '../widgets/cart_bar.dart';

/// Coquille des 2 onglets (Accueil/Profil), chacun gardant sa propre pile
/// de navigation. L'onglet Catalogue a été retiré (2026-07-20, demande
/// utilisateur) : son rôle est repris par le bandeau catégories de
/// l'Accueil (filtre la grille sur place), voir `screens/home/home_screen.dart`.
/// L'onglet Panier a été retiré à son tour (même date, décision produit
/// explicite) : remplacé par [CartBar], une barre flottante persistante en
/// bas d'écran, qui ouvre le panier en feuille
/// (`navigation/cart_sheet.dart`) plutôt que de dédier un onglet entier —
/// voir `docs/design_direction.md` § Phase D.
///
/// La barre de navigation à onglets (2026-07-21, demande utilisateur) a
/// elle-même été retirée : avec seulement 2 destinations restantes
/// (Accueil/Profil), une `NavigationBar` en bas — en plus de [CartBar]
/// juste au-dessus — empilait beaucoup de chrome vertical pour peu de
/// valeur. Remplacée par une `AppBar` commune aux deux onglets (titre =
/// nom de l'app, bouton icône unique qui bascule vers l'autre onglet) —
/// perd la visibilité permanente des 2 destinations, jugé acceptable vu
/// qu'il n'y en a que 2.
class MainTabScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainTabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Force un rebuild au changement de langue (bug trouvé par
    // l'utilisateur, 2026-07-20) — voir `state/locale_state.dart`.
    context.watch<LocaleState>();
    final onHome = navigationShell.currentIndex == 0;

    return Scaffold(
      appBar: AppBar(
        // Espace réservé pour un futur logo (demande utilisateur,
        // 2026-07-21) : ajouter une `Image.asset` avant ce `Text` dans un
        // `Row` le jour où l'asset existe (`mobile/assets/images/`, à créer
        // + déclarer dans `pubspec.yaml`), sans autre changement de
        // structure nécessaire ici.
        title: Text('common.appName'.tr()),
        actions: [
          IconButton(
            icon: Icon(onHome ? Icons.person_outline : Icons.storefront_outlined),
            tooltip: (onHome ? 'nav.profile' : 'nav.home').tr(),
            onPressed: () => navigationShell.goBranch(
              onHome ? 1 : 0,
              initialLocation: false,
            ),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: const CartBar(),
    );
  }
}
