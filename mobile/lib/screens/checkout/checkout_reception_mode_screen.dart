import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class CheckoutReceptionModeScreen extends StatelessWidget {
  const CheckoutReceptionModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CheckoutReceptionMode',
      actions: [
        PlaceholderAction(
          label: 'checkout.deliveryHome'.tr(),
          onPressed: () => context.push('/cart/checkout/address'),
        ),
        PlaceholderAction(
          label: 'checkout.pickupStore'.tr(),
          onPressed: () => context.push('/cart/checkout/timeslot'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
