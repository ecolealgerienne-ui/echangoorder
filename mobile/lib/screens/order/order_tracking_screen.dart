import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderRef;

  const OrderTrackingScreen({super.key, required this.orderRef});

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('screens.OrderTracking.title'.tr()),
        content: Text('${'actions.cancelOrder'.tr()} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('order.keepOrder'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('order.confirmCancel'.tr(), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      showComingSoon(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'OrderTracking',
      actions: [
        PlaceholderAction(
          // Point d'entrée démo : en réel, cet écran est ouvert depuis une
          // notification push envoyée quand le préparateur signale une
          // rupture de stock (F17), pas depuis un bouton du suivi.
          label: 'screens.Substitution.title'.tr(),
          onPressed: () => context.push('/profile/orders/$orderRef/substitution'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'actions.cancelOrder'.tr(),
          onPressed: () => _confirmCancel(context),
          variant: AppButtonVariant.danger,
        ),
      ],
      child: Text('Réf : $orderRef'),
    );
  }
}
