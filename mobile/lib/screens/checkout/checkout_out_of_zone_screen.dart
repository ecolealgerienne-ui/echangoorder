import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/checkout_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class CheckoutOutOfZoneScreen extends StatelessWidget {
  const CheckoutOutOfZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CheckoutOutOfZone',
      actions: [
        PlaceholderAction(
          label: () => 'checkout.pickupStore'.tr(),
          onPressed: () {
            context.read<CheckoutState>().setReceptionMode(ReceptionMode.pickup);
            context.push('/cart/checkout/timeslot');
          },
        ),
        PlaceholderAction(
          label: () => 'checkout.modifyAddress'.tr(),
          onPressed: () => context.pop(),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
