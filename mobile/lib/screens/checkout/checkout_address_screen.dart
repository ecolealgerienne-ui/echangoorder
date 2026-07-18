import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class CheckoutAddressScreen extends StatelessWidget {
  const CheckoutAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CheckoutAddress',
      actions: [
        PlaceholderAction(
          label: 'common.continue'.tr(),
          onPressed: () => context.push('/cart/checkout/timeslot'),
        ),
        PlaceholderAction(
          label: 'screens.CheckoutOutOfZone.title'.tr(),
          onPressed: () => context.push('/cart/checkout/out-of-zone'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
