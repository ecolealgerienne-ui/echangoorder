import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../errors/error_state_view.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Pas de gestion de panier réelle avant Odoo : le panier est donc
    // toujours vide pour l'instant (specs : "Panier vide géré avec message
    // + lien vers catalogue").
    return Scaffold(
      appBar: AppBar(title: Text('screens.Cart.title'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: ErrorStateView(
                icon: Icons.shopping_cart_outlined,
                titleKey: 'emptyStates.cartTitle',
                messageKey: 'emptyStates.cartMessage',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: 'actions.browseCatalog'.tr(),
                    onPressed: () => context.go('/catalog'),
                  ),
                  // Point d'entrée démo pour continuer à valider le flux
                  // checkout tant qu'il n'y a pas de vrai panier (Odoo).
                  AppButton(
                    label: 'actions.goToCheckout'.tr(),
                    onPressed: () => context.push('/cart/checkout/reception-mode'),
                    variant: AppButtonVariant.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
