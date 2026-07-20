import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/app_button.dart';

/// F07 — un ou plusieurs produits du panier sont devenus indisponibles à la
/// confirmation (`checkout_controller.py.confirm()`). Décision produit
/// 2026-07 (remplace F17) : c'est toujours le client qui choisit, jamais le
/// préparateur — pour chaque ligne, un des substituts pré-définis par
/// l'admin (`x_substitute_product_ids`) ou la suppression de la ligne.
///
/// Remplace la ligne en supprimant l'ancienne et en ajoutant le substitut
/// (même quantité) via les endpoints panier existants — pas de contrôleur
/// dédié, `cart_controller.py` suffit déjà.
class CheckoutResolveUnavailableScreen extends StatefulWidget {
  final List<Map<String, dynamic>> lines;

  const CheckoutResolveUnavailableScreen({super.key, required this.lines});

  @override
  State<CheckoutResolveUnavailableScreen> createState() => _CheckoutResolveUnavailableScreenState();
}

class _CheckoutResolveUnavailableScreenState extends State<CheckoutResolveUnavailableScreen> {
  // line_id -> id du substitut choisi, ou _removeChoice pour "supprimer".
  static const _removeChoice = -1;
  final Map<int, int> _decisions = {};
  bool _isSubmitting = false;

  bool get _allResolved =>
      widget.lines.every((line) => _decisions.containsKey(line['line_id'] as int));

  Future<void> _apply() async {
    if (_isSubmitting || !_allResolved) return;
    setState(() => _isSubmitting = true);
    final api = context.read<OdooApiClient>();
    try {
      for (final line in widget.lines) {
        final lineId = line['line_id'] as int;
        final decision = _decisions[lineId]!;
        await api.removeCartLine(lineId: lineId);
        if (decision != _removeChoice) {
          final qty = (line['qty'] as num?) ?? 1;
          await api.addToCart(productId: decision, qty: qty);
        }
      }
      if (!mounted) return;
      context.pop(true);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('checkout.resolveUnavailableTitle'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'checkout.resolveUnavailableIntro'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final line in widget.lines)
              _UnavailableLineCard(
                line: line,
                removeChoice: _removeChoice,
                selected: _decisions[line['line_id'] as int],
                onSelect: (value) => setState(() => _decisions[line['line_id'] as int] = value),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'common.continue'.tr(),
              onPressed: (_isSubmitting || !_allResolved) ? null : _apply,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableLineCard extends StatelessWidget {
  final Map<String, dynamic> line;
  final int removeChoice;
  final int? selected;
  final ValueChanged<int> onSelect;

  const _UnavailableLineCard({
    required this.line,
    required this.removeChoice,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final substitutes = (line['substitutes'] as List).cast<Map<String, dynamic>>();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: RadioGroup<int>(
        // RadioGroup centralise groupValue/onChanged pour tous les Radio
        // descendants (individuels dépréciés depuis Flutter 3.32, cf.
        // CheckoutTimeslotScreen) — un groupe par ligne, indépendant des
        // autres lignes de la liste.
        groupValue: selected ?? -2,
        onChanged: (value) => onSelect(value!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line['product_name'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'errors.checkout.out_of_stock'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (substitutes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  'checkout.noSubstituteAvailable'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              for (final substitute in substitutes) _SubstituteChoice(substitute: substitute),
            RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              value: removeChoice,
              title: Text('checkout.removeLine'.tr(), style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubstituteChoice extends StatelessWidget {
  final Map<String, dynamic> substitute;

  const _SubstituteChoice({required this.substitute});

  @override
  Widget build(BuildContext context) {
    final imageBase64 = substitute['image_128'];
    return RadioListTile<int>(
      contentPadding: EdgeInsets.zero,
      value: substitute['id'] as int,
      secondary: SizedBox(
        width: 40,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppLayout.radius / 2),
          child: imageBase64 is String
              ? Image.memory(base64Decode(imageBase64), fit: BoxFit.cover)
              : Container(
                  color: AppColors.background,
                  child: const Icon(Icons.image_not_supported_outlined, size: 18, color: AppColors.textMuted),
                ),
        ),
      ),
      title: Text(substitute['name'] as String? ?? ''),
      subtitle: Text(formatPrice(context, (substitute['list_price'] as num?) ?? 0)),
    );
  }
}
