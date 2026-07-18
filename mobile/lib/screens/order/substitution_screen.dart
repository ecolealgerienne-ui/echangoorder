import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/coming_soon.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

class SubstitutionScreen extends StatelessWidget {
  final String orderRef;

  const SubstitutionScreen({super.key, required this.orderRef});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'Substitution',
      actions: [
        PlaceholderAction(
          label: 'substitution.accept'.tr(),
          onPressed: () {
            showComingSoon(context);
            context.pop();
          },
        ),
        PlaceholderAction(
          label: 'substitution.refuse'.tr(),
          onPressed: () {
            showComingSoon(context);
            context.pop();
          },
          variant: AppButtonVariant.danger,
        ),
      ],
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProductRow(labelKey: 'substitution.original', name: 'Lait entier 1L', price: '1.20€'),
          SizedBox(height: AppSpacing.md),
          _ProductRow(labelKey: 'substitution.suggested', name: 'Lait demi-écrémé 1L', price: '1.10€'),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String labelKey;
  final String name;
  final String price;

  const _ProductRow({required this.labelKey, required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labelKey.tr(), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          Text(price),
        ],
      ),
    );
  }
}
