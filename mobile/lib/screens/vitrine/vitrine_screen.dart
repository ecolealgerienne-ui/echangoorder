import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class VitrineScreen extends StatelessWidget {
  const VitrineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    // Parcours specs §2 : clic "Ajouter au panier"/inscription → Onboarding
    // seulement à la première ouverture, sinon direct vers l'auth (F02).
    void goToAuth() {
      context.push(authState.hasSeenOnboarding ? '/auth-welcome' : '/onboarding');
    }

    return ScreenPlaceholder(
      screenKey: 'Vitrine',
      showAppBar: false,
      actions: [
        PlaceholderAction(label: 'actions.signUpToOrder'.tr(), onPressed: goToAuth),
      ],
    );
  }
}
