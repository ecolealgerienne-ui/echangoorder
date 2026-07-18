import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Catalog',
      actions: [
        PlaceholderAction(
          label: 'screens.CategoryProducts.title'.tr(),
          onPressed: () => context.push('/catalog/category/demo-cat'),
        ),
        PlaceholderAction(
          label: 'screens.Search.title'.tr(),
          onPressed: () => context.push('/catalog/search'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
