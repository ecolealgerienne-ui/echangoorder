import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../widgets/app_button.dart';
import '../../widgets/screen_placeholder.dart';

/// F09 (détail) — données réelles de la commande (`sale.order` + ses
/// lignes). Le suivi temps réel complet (statuts `stock.picking`
/// synchronisés, notifications push — F08/F11) reste hors scope : seul
/// l'état Odoo de base (`state`) est affiché ici, pas d'étapes
/// préparation/livraison détaillées.
class OrderTrackingScreen extends StatefulWidget {
  final String orderRef;

  const OrderTrackingScreen({super.key, required this.orderRef});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<_OrderDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _detailFuture = _fetchDetail();
    });
  }

  Future<_OrderDetail> _fetchDetail() async {
    final api = context.read<OdooApiClient>();
    final detail = await api.getOrderDetail(orderRef: widget.orderRef);
    final order = detail['order'] as Map<String, dynamic>;
    final lines = (detail['lines'] as List).cast<Map<String, dynamic>>();
    return _OrderDetail(order: order, lines: lines);
  }

  Future<void> _confirmCancel(BuildContext context, int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('screens.OrderTracking.title'.tr()),
        content: Text('${'actions.cancelOrder'.tr()} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('order.keepOrder'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('order.confirmCancel'.tr(), style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<OdooApiClient>().cancelOrder(orderId: orderId);
      if (!context.mounted) return;
      AppMessenger.showInfo(context, 'order.cancelled');
      _load();
    } on AppError catch (e) {
      if (context.mounted) AppMessenger.showError(context, e, onRetry: () => _confirmCancel(context, orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.OrderTracking.title'.tr())),
      body: SafeArea(
        child: FutureBuilder<_OrderDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _load);
            }

            final detail = snapshot.data!;
            final order = detail.order;
            final state = order['state'] as String?;
            final receptionMode = order['x_reception_mode'] as String?;
            final creneau = parseOdooDatetime(order['x_creneau'] as String?);
            final modeLabel = receptionMode == 'home_delivery'
                ? 'checkout.deliveryHome'.tr()
                : receptionMode == 'pickup'
                    ? 'checkout.pickupStore'.tr()
                    : null;
            final statusLabel = state == 'cancel' ? 'order.statusCancelled'.tr() : 'order.statusConfirmed'.tr();

            return ScreenPlaceholder(
              screenKey: 'OrderTracking',
              actions: [
                // F16 — visible uniquement tant que la commande est
                // "Confirmée" (state == 'sale'), pas de suivi
                // stock.picking pour distinguer "préparation commencée".
                if (state == 'sale')
                  PlaceholderAction(
                    label: 'actions.cancelOrder'.tr(),
                    onPressed: () => _confirmCancel(context, order['id'] as int),
                    variant: AppButtonVariant.danger,
                  ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${'common.reference'.tr()} ${widget.orderRef}'),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${state == 'cancel' ? '❌' : '✅'} $statusLabel'),
                  if (modeLabel != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(modeLabel),
                  ],
                  if (creneau != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('🕐 ${creneau.hour.toString().padLeft(2, '0')}h${creneau.minute.toString().padLeft(2, '0')}'),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text('${'cart.total'.tr()} : ${formatPrice(context, order['amount_total'] as num)}'),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${detail.lines.length} ${'checkout.itemsLabel'.tr()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final line in detail.lines)
                    Text('• ${line['name']} x${line['product_uom_qty']}'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderDetail {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> lines;

  const _OrderDetail({required this.order, required this.lines});
}
