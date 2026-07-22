import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    return ScreenPlaceholder(
      screenKey: 'AuthWelcome',
      actions: [
        PlaceholderAction(label: () => 'actions.signUp'.tr(), onPressed: () => context.push('/register/step1')),
        PlaceholderAction(
          label: () => 'actions.logIn'.tr(),
          onPressed: () => context.push('/login'),
          variant: AppButtonVariant.secondary,
        ),
        PlaceholderAction(
          label: () => 'actions.continueAsGuest'.tr(),
          onPressed: authState.continueAsGuest,
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}
