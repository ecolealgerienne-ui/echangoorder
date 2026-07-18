import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'About',
      actions: [
        PlaceholderAction(
          label: 'legal.cgu'.tr(),
          onPressed: () => context.push('/profile/legal/cgu'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'legal.privacy'.tr(),
          onPressed: () => context.push('/profile/legal/privacy'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: 'legal.legal'.tr(),
          onPressed: () => context.push('/profile/legal/legal'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
