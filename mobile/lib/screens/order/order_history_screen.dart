import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'OrderHistory',
      actions: [
        PlaceholderAction(
          label: 'screens.OrderTracking.title'.tr(),
          onPressed: () => context.push('/profile/orders/ECH-DEMO-0001'),
        ),
      ],
    );
  }
}
