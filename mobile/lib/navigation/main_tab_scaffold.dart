import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Coquille des 4 onglets (Accueil/Catalogue/Panier/Profil), chacun gardant
/// sa propre pile de navigation — équivalent du bottom tab navigator RN.
class MainTabScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainTabScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
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
          NavigationDestination(icon: const Text('📋'), label: 'nav.catalog'.tr()),
          NavigationDestination(icon: const Text('🛒'), label: 'nav.cart'.tr()),
          NavigationDestination(icon: const Text('👤'), label: 'nav.profile'.tr()),
        ],
      ),
    );
  }
}
