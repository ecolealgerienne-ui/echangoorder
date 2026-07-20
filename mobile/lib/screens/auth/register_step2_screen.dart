import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep2Screen extends StatelessWidget {
  final String phone;
  final String name;
  final String lang;

  const RegisterStep2Screen({super.key, required this.phone, required this.name, required this.lang});

  void _continue(BuildContext context) => context.push(
        '/register/step3',
        extra: {'phone': phone, 'name': name, 'lang': lang},
      );

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'RegisterStep2',
      actions: [
        PlaceholderAction(
          label: 'actions.useGpsLocation'.tr(),
          onPressed: () => requestLocationPermission(context),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(label: 'common.continue'.tr(), onPressed: () => _continue(context)),
        PlaceholderAction(
          label: 'common.skip'.tr(),
          onPressed: () => _continue(context),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
