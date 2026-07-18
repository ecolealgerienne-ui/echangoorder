import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Cart',
      actions: [
        PlaceholderAction(
          label: 'actions.goToCheckout'.tr(),
          onPressed: () => context.push('/cart/checkout/reception-mode'),
        ),
      ],
    );
  }
}
