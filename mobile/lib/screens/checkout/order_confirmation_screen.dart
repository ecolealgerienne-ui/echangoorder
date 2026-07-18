import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String orderRef;

  const OrderConfirmationScreen({super.key, required this.orderRef});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ScreenPlaceholder(
        screenKey: 'OrderConfirmation',
        showAppBar: false,
        actions: [
          PlaceholderAction(
            label: 'actions.trackOrder'.tr(),
            // Navigation inter-onglets (Panier -> Profil), simple avec go_router :
            // pas besoin de passer par le navigator parent comme en React Native.
            onPressed: () => context.go('/profile/orders/$orderRef'),
          ),
          PlaceholderAction(
            label: 'actions.backHome'.tr(),
            onPressed: () => context.go('/home'),
            variant: AppButtonVariant.secondary,
          ),
        ],
        child: Text('Réf : $orderRef'),
      ),
    );
  }
}
