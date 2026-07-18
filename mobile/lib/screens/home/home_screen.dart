import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Home',
      actions: [
        PlaceholderAction(
          label: 'screens.ProductDetail.title'.tr(),
          onPressed: () => context.push('/home/product/demo-1'),
        ),
      ],
    );
  }
}
