import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// F13 — pages légales (CGU, confidentialité, mentions légales, cookies).
/// Contenu statique embarqué dans l'app (specs Expert Odoo : "aucun appel
/// API"). **Texte provisoire** (`legal.draftNotice`) : rédigé pour ne pas
/// laisser les écrans vides, à faire valider par un juriste avant
/// soumission aux stores — voir status-V1.md § Points de vigilance.
class LegalDocumentScreen extends StatelessWidget {
  final String docType;

  const LegalDocumentScreen({super.key, required this.docType});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColorTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('legal.$docType'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(AppLayout.radius),
                ),
                child: Text(
                  'legal.draftNotice'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('legal.docs.$docType'.tr(), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'legal.version'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
              Text(
                'legal.updatedOn'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
