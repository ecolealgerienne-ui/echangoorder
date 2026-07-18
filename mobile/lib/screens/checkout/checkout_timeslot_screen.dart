import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class CheckoutTimeslotScreen extends StatelessWidget {
  const CheckoutTimeslotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CheckoutTimeslot',
      actions: [
        PlaceholderAction(
          label: 'common.continue'.tr(),
          onPressed: () => context.push('/cart/checkout/summary'),
        ),
      ],
    );
  }
}
