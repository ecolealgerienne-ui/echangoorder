import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Search',
      actions: [
        PlaceholderAction(
          label: 'screens.ProductDetail.title'.tr(),
          onPressed: () => context.push('/catalog/product/demo-1'),
        ),
      ],
    );
  }
}
