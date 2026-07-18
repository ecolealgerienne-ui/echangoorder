import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    return ScreenPlaceholder(
      screenKey: 'Login',
      actions: [
        PlaceholderAction(label: 'actions.logIn'.tr(), onPressed: authState.loginAsUser),
        PlaceholderAction(
          label: 'actions.forgotPin'.tr(),
          onPressed: () => context.push('/forgot-pin'),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
