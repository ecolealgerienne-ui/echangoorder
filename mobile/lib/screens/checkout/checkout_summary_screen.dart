import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class CheckoutSummaryScreen extends StatelessWidget {
  const CheckoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CheckoutSummary',
      actions: [
        PlaceholderAction(
          label: 'actions.confirmOrder'.tr(),
          onPressed: () => context.push('/cart/checkout/confirmation/ECH-DEMO-0001'),
        ),
      ],
    );
  }
}
