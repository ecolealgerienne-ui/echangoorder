import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';

/// Coquille des 3 onglets (Accueil/Panier/Profil), chacun gardant sa propre
/// pile de navigation — équivalent du bottom tab navigator RN. L'onglet
/// Catalogue a été retiré (2026-07-20, demande utilisateur) : son rôle est
/// repris par le bandeau catégories de l'Accueil (filtre la grille sur
/// place), voir `screens/home/home_screen.dart`.
class MainTabScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainTabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final itemCount = context.watch<CartState>().itemCount;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        indicatorColor: AppColors.surface,
        destinations: [
          NavigationDestination(icon: const Text('🏠'), label: 'nav.home'.tr()),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: itemCount > 0,
              label: Text('$itemCount'),
              child: const Text('🛒'),
            ),
            label: 'nav.cart'.tr(),
          ),
          NavigationDestination(icon: const Text('👤'), label: 'nav.profile'.tr()),
        ],
      ),
    );
  }
}
