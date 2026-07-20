import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../services/odoo_api_client.dart';
import '../../state/cart_state.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../utils/timeslots.dart';
import '../../widgets/app_button.dart';

/// F07 — étape 4 : récapitulatif + confirmation réelle de la commande
/// (`/echango/checkout/confirm`, `action_confirm` sur le devis).
class CheckoutSummaryScreen extends StatefulWidget {
  const CheckoutSummaryScreen({super.key});

  @override
  State<CheckoutSummaryScreen> createState() => _CheckoutSummaryScreenState();
}

class _CheckoutSummaryScreenState extends State<CheckoutSummaryScreen> {
  final _promoController = TextEditingController();
  bool _isConfirming = false;
  bool _isApplyingPromo = false;
  String? _appliedPromoCode;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _applyPromo() async {
    if (_isApplyingPromo) return;
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isApplyingPromo = true);
    try {
      await context.read<CartState>().applyPromoCode(code: code);
      if (!mounted) return;
      setState(() => _appliedPromoCode = code);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    } finally {
      if (mounted) setState(() => _isApplyingPromo = false);
    }
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      await _attemptConfirm();
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  /// Logique de confirmation sans le garde-fou anti double-soumission
  /// (porté par [_confirm]) : se rappelle elle-même après résolution des
  /// produits indisponibles (voir plus bas), ce qui serait bloqué par le
  /// garde-fou si celui-ci vivait ici — `_isConfirming` reste vrai pendant
  /// toute la boucle résolution/nouvelle tentative, pas seulement le
  /// premier essai.
  Future<void> _attemptConfirm() async {
    final checkout = context.read<CheckoutState>();
    final mode = checkout.receptionMode;
    final slot = checkout.slotStart;
    if (mode == null || slot == null) return;

    try {
      final result = await context.read<OdooApiClient>().confirmOrder(
            receptionMode: mode == ReceptionMode.delivery ? 'home_delivery' : 'pickup',
            slotStart: slot,
            addressId: mode == ReceptionMode.delivery ? checkout.addressId : null,
            street: mode == ReceptionMode.delivery ? checkout.street : null,
            city: mode == ReceptionMode.delivery ? checkout.city : null,
            zipCode: mode == ReceptionMode.delivery ? checkout.zipCode : null,
            notes: mode == ReceptionMode.delivery ? checkout.notes : null,
          );
      if (!mounted) return;
      await context.read<CartState>().refresh();
      if (!mounted) return;
      context.read<CheckoutState>().reset();
      context.go('/cart/checkout/confirmation/${result['order_ref']}', extra: result);
    } on CartUnavailableProductsError catch (e) {
      // Doit être attrapé avant `on AppError` (dont elle hérite) : porte la
      // liste structurée des lignes/substituts jusqu'à l'écran de
      // résolution plutôt qu'un simple message d'erreur (décision produit
      // 2026-07, remplace F17 — voir CLAUDE.md § Produits de substitution).
      if (!mounted) return;
      final resolved = await context.push<bool>('/cart/checkout/resolve-unavailable', extra: e.lines);
      if (resolved == true && mounted) {
        await context.read<CartState>().refresh();
        if (mounted) await _attemptConfirm();
      }
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _confirm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();
    final checkout = context.watch<CheckoutState>();
    final mode = checkout.receptionMode;
    final slot = checkout.slotStart;

    return Scaffold(
      appBar: AppBar(title: Text('screens.CheckoutSummary.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '📦 ${cart.itemCount} ${'checkout.itemsLabel'.tr()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (mode != null) Text(mode == ReceptionMode.delivery ? 'checkout.deliveryHome'.tr() : 'checkout.pickupStore'.tr()),
              if (mode == ReceptionMode.delivery) ...[
                const SizedBox(height: AppSpacing.xs),
                Text('${checkout.street}, ${checkout.city} ${checkout.zipCode}'),
              ],
              if (slot != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '🕐 ${_isToday(slot) ? 'checkout.today'.tr() : 'checkout.tomorrow'.tr()} '
                  '${formatSlotRange(slot, slot.add(const Duration(hours: 2)))}',
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text('checkout.paymentOnDelivery'.tr()),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promoController,
                      decoration: InputDecoration(
                        labelText: 'checkout.promoCodeLabel'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: _isApplyingPromo ? null : _applyPromo,
                    child: Text('common.confirm'.tr()),
                  ),
                ],
              ),
              if (_appliedPromoCode != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${'checkout.promoAppliedPrefix'.tr()} $_appliedPromoCode',
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('cart.subtotal'.tr()),
                  Text(formatPrice(context, cart.amountSubtotal)),
                ],
              ),
              if (cart.discount != 0) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('checkout.discountLabel'.tr()),
                    Text(formatPrice(context, cart.discount), style: const TextStyle(color: AppColors.promo)),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('cart.total'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  Text(formatPrice(context, cart.amountTotal), style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const Spacer(),
              AppButton(
                label: 'actions.confirmOrder'.tr(),
                onPressed: (_isConfirming || mode == null || slot == null) ? null : _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
