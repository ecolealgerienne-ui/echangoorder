import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../widgets/screen_placeholder.dart';

class RegisterStep3Screen extends StatelessWidget {
  const RegisterStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    return ScreenPlaceholder(
      screenKey: 'RegisterStep3',
      actions: [
        PlaceholderAction(label: 'common.confirm'.tr(), onPressed: authState.loginAsUser),
      ],
    );
  }
}
