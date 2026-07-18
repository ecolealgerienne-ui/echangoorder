import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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
          label: 'actions.cancelOrder'.tr(),
          onPressed: () => _confirmCancel(context),
          variant: AppButtonVariant.danger,
        ),
      ],
      child: Text('Réf : $orderRef'),
    );
  }
}
