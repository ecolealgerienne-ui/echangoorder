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
  bool _isConfirming = false;

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    final checkout = context.read<CheckoutState>();
    final mode = checkout.receptionMode;
    final slot = checkout.slotStart;
    if (mode == null || slot == null) return;

    setState(() => _isConfirming = true);
    try {
      final result = await context.read<OdooApiClient>().confirmOrder(
            receptionMode: mode == ReceptionMode.delivery ? 'home_delivery' : 'pickup',
            slotStart: slot,
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
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: _confirm);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
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
                '📦 ${cart.itemCount} ${'checkout.itemsLabel'.tr()} — ${cart.amountTotal.toStringAsFixed(2)} €',
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
