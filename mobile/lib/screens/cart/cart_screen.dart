import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../state/checkout_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

/// F06 — Panier : reflète le devis Odoo (`sale.order` brouillon) du
/// client connecté, voir `state/cart_state.dart`. Pas encore de panier
/// invité (nécessiterait un partner temporaire Odoo, décision produit
/// ouverte — cf. status-V1.md § Points de vigilance) : un invité voit
/// l'état vide existant, pas d'appel API.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    final isAuthenticated = context.read<AuthState>().status == SessionStatus.authenticated;
    if (isAuthenticated) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<CartState>().refresh();
    } on AppError catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQuantity(CartLine line, num qty) async {
    try {
      await context.read<CartState>().updateQuantity(lineId: line.lineId, qty: qty);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: () => _updateQuantity(line, qty));
    }
  }

  Future<void> _removeLine(CartLine line) async {
    try {
      await context.read<CartState>().removeLine(lineId: line.lineId);
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: () => _removeLine(line));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthState>().status == SessionStatus.authenticated;
    final cart = context.watch<CartState>();
    final title = cart.itemCount > 0
        ? '${'screens.Cart.title'.tr()} (${cart.itemCount})'
        : 'screens.Cart.title'.tr();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: !isAuthenticated
            ? _emptyState(context)
            : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorStateView.forError(_error!, onRetry: _load)
                    : cart.isEmpty
                        ? _emptyState(context)
                        : _cartContent(context, cart),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: ErrorStateView(
            icon: Icons.shopping_cart_outlined,
            titleKey: 'emptyStates.cartTitle',
            messageKey: 'emptyStates.cartMessage',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            label: 'actions.browseCatalog'.tr(),
            onPressed: () => context.go('/catalog'),
          ),
        ),
      ],
    );
  }

  Widget _cartContent(BuildContext context, CartState cart) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: cart.lines.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _CartLineTile(
              line: cart.lines[index],
              onIncrement: (line) => _updateQuantity(line, line.qty + 1),
              onDecrement: (line) => line.qty > 1 ? _updateQuantity(line, line.qty - 1) : null,
              onRemove: _removeLine,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AmountRow(label: 'cart.subtotal'.tr(), amount: cart.amountSubtotal),
              if (cart.discount != 0) ...[
                const SizedBox(height: AppSpacing.xs),
                _AmountRow(
                  label: 'checkout.discountLabel'.tr(),
                  amount: cart.discount,
                  color: AppColors.promo,
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              _AmountRow(label: 'cart.total'.tr(), amount: cart.amountTotal, emphasize: true),
              // Qualité clients — compte pas encore validé par un
              // modérateur (ou rejeté) : averti dès le panier plutôt qu'au
              // bout du tunnel checkout, où la vérification définitive est
              // de toute façon refaite côté serveur.
              if (cart.verificationState != null && cart.verificationState != 'verified') ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppMessenger.messageFor(AppError(
                    cart.verificationState == 'rejected'
                        ? AppError.authAccountRejected
                        : AppError.authAccountPendingVerification,
                  )),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'actions.goToCheckout'.tr(),
                onPressed: (cart.verificationState != null && cart.verificationState != 'verified')
                    ? null
                    : () {
                        // Repart d'un état propre à chaque entrée dans le tunnel
                        // (pas de résidu d'un essai précédent abandonné).
                        context.read<CheckoutState>().reset();
                        context.push('/cart/checkout/reception-mode');
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool emphasize;
  final Color? color;

  const _AmountRow({required this.label, required this.amount, this.emphasize = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = (emphasize
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted))
        ?.copyWith(color: color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${amount.toStringAsFixed(2)} €', style: style),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  final void Function(CartLine) onIncrement;
  final void Function(CartLine) onDecrement;
  final void Function(CartLine) onRemove;

  const _CartLineTile({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final qtyLabel = line.uom == null || line.uom!.isEmpty ? '${line.qty}' : '${line.qty} ${line.uom}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppLayout.radius),
          ),
          child: line.imageBase64 != null
              ? Image.memory(base64Decode(line.imageBase64!), fit: BoxFit.cover)
              : const Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '${line.unitPrice.toStringAsFixed(2)} €${line.uom == null || line.uom!.isEmpty ? '' : ' / ${line.uom}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  IconButton(
                    onPressed: line.qty > 1 ? () => onDecrement(line) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(qtyLabel, style: Theme.of(context).textTheme.bodyMedium),
                  IconButton(
                    onPressed: () => onIncrement(line),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => onRemove(line),
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
