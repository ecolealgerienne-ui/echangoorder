import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class ForgotPinScreen extends StatelessWidget {
  const ForgotPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'ForgotPin',
      actions: [
        PlaceholderAction(
          label: 'common.back'.tr(),
          onPressed: () => context.pop(),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
