import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pied de liste affiché tant que d'autres résultats sont disponibles (voir
/// `utils/pagination.dart`) — chargement à la demande plutôt qu'un
/// défilement infini automatique.
class LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const LoadMoreButton({super.key, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : OutlinedButton(onPressed: onPressed, child: Text('actions.loadMore'.tr())),
      ),
    );
  }
}
