import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/app_messenger.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency.dart';
import '../../utils/order_status.dart';
import '../../utils/pagination.dart';
import '../../widgets/app_button.dart';
import '../../widgets/load_more_button.dart';

/// F09 — historique des commandes du client connecté. `sale.order` est
/// déjà lisible par le portail (règle standard, restreinte à ses propres
/// commandes) — pas de contrôleur custom nécessaire pour la lecture, juste
/// pour le reorder (mutation panier, voir `cart_controller.py`).
///
/// **Simplification assumée** : le bouton "Commander à nouveau" est
/// affiché pour toute commande confirmée (`state == 'sale'`), pas
/// seulement les commandes "Livrées" — le suivi réel de la livraison
/// (`stock.picking`) n'est pas encore synchronisé (F08 complet, différé).
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _ordersFuture;
  final List<Map<String, dynamic>> _extraOrders = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  // Cf. home_screen.dart : détecte qu'un rechargement complet a démarré
  // pendant l'appel réseau de _loadMore() (race condition trouvée à
  // l'audit technique du 2026-07-19).
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthState>().status == SessionStatus.authenticated) {
      _load();
    }
  }

  void _load() {
    _loadGeneration++;
    _extraOrders.clear();
    _offset = 0;
    _hasMore = true;
    setState(() {
      _ordersFuture = _fetchOrders(offset: 0);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchOrders({required int offset}) async {
    final orders = await context.read<OdooApiClient>().listOrders(offset: offset, limit: kListPageSize);
    _hasMore = orders.length == kListPageSize;
    _offset = offset + orders.length;
    return orders;
  }

  Future<void> _handleRefresh() async {
    _load();
    try {
      await _ordersFuture;
    } catch (_) {
      // Déjà affiché par le FutureBuilder (snapshot.hasError).
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchOrders(offset: _offset);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _extraOrders.addAll(more));
    } on AppError catch (e) {
      if (mounted && generation == _loadGeneration) AppMessenger.showError(context, e, onRetry: _loadMore);
    } finally {
      if (mounted && generation == _loadGeneration) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _reorder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('order.reorderTitle'.tr()),
        content: Text('order.reorderMessage'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('common.cancel'.tr())),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('actions.addToCart'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final unavailable = await context.read<CartState>().reorder(orderId: order['id'] as int);
      if (!mounted) return;
      if (unavailable.isNotEmpty) {
        AppMessenger.showInfo(context, 'order.reorderUnavailableWarning');
      }
      context.go('/cart');
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e, onRetry: () => _reorder(order));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<AuthState>().status == SessionStatus.guest;

    return Scaffold(
      appBar: AppBar(title: Text('screens.OrderHistory.title'.tr())),
      body: SafeArea(
        child: isGuest || _ordersFuture == null
            ? _emptyState(context, isGuest: isGuest)
            : RefreshIndicator(
                onRefresh: _handleRefresh,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ordersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error is AppError
                          ? snapshot.error as AppError
                          : const AppError(AppError.unknown);
                      return ErrorStateView.forError(error, onRetry: _load);
                    }
                    final orders = [...snapshot.data!, ..._extraOrders];
                    if (orders.isEmpty) {
                      return _emptyState(context, isGuest: false);
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: orders.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        if (index == orders.length) {
                          return LoadMoreButton(isLoading: _isLoadingMore, onPressed: _loadMore);
                        }
                        return _OrderCard(
                          order: orders[index],
                          onTap: () => context.push('/profile/orders/${orders[index]['name']}'),
                          onReorder: () => _reorder(orders[index]),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, {required bool isGuest}) {
    return ErrorStateView(
      icon: Icons.receipt_long_outlined,
      titleKey: 'emptyStates.ordersTitle',
      messageKey: isGuest ? 'emptyStates.ordersGuestMessage' : 'emptyStates.ordersMessage',
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final VoidCallback onReorder;

  const _OrderCard({required this.order, required this.onTap, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final name = order['name'] as String? ?? '';
    final amount = (order['amount_total'] as num?)?.toDouble() ?? 0;
    final state = order['state'] as String?;
    final date = parseOdooDatetime(order['date_order'] as String?);
    final isConfirmed = state == 'sale';
    final statusLabel = switch (state) {
      'cancel' => 'order.statusCancelled'.tr(),
      // F08 — en attente de prise en charge par un opérateur (voir
      // CLAUDE.md § Statuts de commande) : pas encore de stock.picking à
      // ce stade, prepStatusLabel() ne renverrait rien d'utile.
      'sent' => 'order.statusPendingReview'.tr(),
      _ => prepStatusLabel(order) ?? 'order.statusConfirmed'.tr(),
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (date != null)
                Text(
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpacing.xs),
              Text('${formatPrice(context, amount)}  ${state == 'cancel' ? '❌' : '✅'} $statusLabel'),
              if (isConfirmed) ...[
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'actions.reorder'.tr(),
                  onPressed: onReorder,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
