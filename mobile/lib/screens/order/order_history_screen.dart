import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/error_state_view.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<AuthState>().status == SessionStatus.guest;

    // Pas d'historique réel avant Odoo : toujours vide pour l'instant.
    // Message spécifique pour les invités (specs F09 : "Utilisateur invité :
    // message invitant à créer un compte pour accéder à l'historique").
    return Scaffold(
      appBar: AppBar(title: Text('screens.OrderHistory.title'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorStateView(
                icon: Icons.receipt_long_outlined,
                titleKey: 'emptyStates.ordersTitle',
                messageKey: isGuest ? 'emptyStates.ordersGuestMessage' : 'emptyStates.ordersMessage',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                // Point d'entrée démo pour continuer à valider le suivi de
                // commande tant qu'il n'y a pas de vraies commandes (Odoo).
                label: 'screens.OrderTracking.title'.tr(),
                onPressed: () => context.push('/profile/orders/ECH-DEMO-0001'),
                variant: AppButtonVariant.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
