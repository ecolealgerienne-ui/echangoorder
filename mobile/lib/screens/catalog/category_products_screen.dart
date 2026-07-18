import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;

  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'CategoryProducts',
      actions: [
        PlaceholderAction(
          label: 'screens.ProductDetail.title'.tr(),
          onPressed: () => context.push('/catalog/product/demo-1'),
        ),
      ],
      child: Text('categoryId: $categoryId'),
    );
  }
}
