import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';

/// Coquille des 2 onglets (Accueil/Profil), chacun gardant sa propre pile
/// de navigation — équivalent du bottom tab navigator RN. L'onglet
/// Catalogue a été retiré (2026-07-20, demande utilisateur) : son rôle est
/// repris par le bandeau catégories de l'Accueil (filtre la grille sur
/// place), voir `screens/home/home_screen.dart`. L'onglet Panier a été
/// retiré à son tour (même date, décision produit explicite) : remplacé
/// par [CartBar], une barre flottante persistante au-dessus de la barre de
/// navigation, qui ouvre le panier en feuille (`navigation/cart_sheet.dart`)
/// plutôt que de dédier un onglet entier — voir `docs/design_direction.md`
/// § Phase D.
class MainTabScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainTabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CartBar(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            indicatorColor: AppColors.surface,
            destinations: [
              NavigationDestination(icon: const Text('🏠'), label: 'nav.home'.tr()),
              NavigationDestination(icon: const Text('👤'), label: 'nav.profile'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}
