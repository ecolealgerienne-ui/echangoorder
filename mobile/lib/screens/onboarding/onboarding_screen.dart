import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthState>();

    void finish() {
      authState.completeOnboarding();
      context.go('/auth-welcome');
    }

    return ScreenPlaceholder(
      screenKey: 'Onboarding',
      actions: [
        PlaceholderAction(label: 'common.skip'.tr(), onPressed: finish, variant: AppButtonVariant.secondary),
        PlaceholderAction(label: 'common.next'.tr(), onPressed: finish),
      ],
    );
  }
}
