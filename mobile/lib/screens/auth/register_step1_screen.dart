import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep1Screen extends StatelessWidget {
  const RegisterStep1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'RegisterStep1',
      actions: [
        PlaceholderAction(label: 'common.continue'.tr(), onPressed: () => context.push('/register/step2')),
      ],
    );
  }
}
