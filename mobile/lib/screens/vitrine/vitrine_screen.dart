import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_grid_tile.dart';
import '../../widgets/screen_placeholder.dart';

/// F00 — vitrine publique (avant inscription), grille des produits
/// sélectionnés en back-office (`x_vitrine_publique`, endpoint public
/// `auth='public'` — voir `controllers/vitrine_controller.py`, aucune
/// session Odoo nécessaire pour cet écran). Le wireframe ne prévoit pas de
/// fiche produit accessible sans compte : taper une tuile ou son bouton
/// "+" déclenche toujours le popup d'inscription.
class VitrineScreen extends StatefulWidget {
  const VitrineScreen({super.key});

  @override
  State<VitrineScreen> createState() => _VitrineScreenState();
}

class _VitrineScreenState extends State<VitrineScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _productsFuture = context.read<OdooApiClient>().getVitrineProducts();
    });
  }

  void _goToAuth() {
    final authState = context.read<AuthState>();
    context.push(authState.hasSeenOnboarding ? '/auth-welcome' : '/onboarding');
  }

  Future<void> _showSignUpPopup() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('vitrine.popupTitle'.tr()),
        content: Text('vitrine.popupBody'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('later'), child: Text('actions.later'.tr())),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('login'), child: Text('actions.logIn'.tr())),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('signup'), child: Text('actions.signUp'.tr())),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'later') return;
    context.push(choice == 'login' ? '/login' : '/register/step1');
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Vitrine',
      showAppBar: false,
      actions: [
        PlaceholderAction(label: () => 'actions.signUpToOrder'.tr(), onPressed: _goToAuth),
      ],
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error =
                snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
            return ErrorStateView.forError(error, onRetry: _load);
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const ErrorStateView(
              icon: Icons.storefront_outlined,
              titleKey: 'emptyStates.productsTitle',
              messageKey: 'emptyStates.productsMessage',
            );
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.72,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => ProductGridTile(
              product: products[index],
              onTap: _showSignUpPopup,
              onAdd: _showSignUpPopup,
            ),
          );
        },
      ),
    );
  }
}
