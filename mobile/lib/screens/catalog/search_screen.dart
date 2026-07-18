import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../errors/error_state_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pas de recherche réelle avant Odoo : état "aucun résultat" par défaut.
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: false,
          decoration: InputDecoration(
            hintText: '${'screens.Search.title'.tr()}...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: ErrorStateView(
                icon: Icons.search_off,
                titleKey: 'emptyStates.searchTitle',
                messageKey: 'emptyStates.searchMessage',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                // Point d'entrée démo pour valider la navigation fiche
                // produit tant qu'il n'y a pas de vrais résultats (Odoo).
                label: 'screens.ProductDetail.title'.tr(),
                onPressed: () => context.push('/catalog/product/demo-1'),
                variant: AppButtonVariant.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
