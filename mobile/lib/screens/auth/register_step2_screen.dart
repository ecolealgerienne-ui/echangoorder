import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep2Screen extends StatelessWidget {
  const RegisterStep2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'RegisterStep2',
      actions: [
        PlaceholderAction(label: 'common.continue'.tr(), onPressed: () => context.push('/register/step3')),
        PlaceholderAction(
          label: 'common.skip'.tr(),
          onPressed: () => context.push('/register/step3'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
