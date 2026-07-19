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

/// F17 — substitution produit. Le signalement de rupture + la suggestion
/// sont saisis manuellement par le préparateur en back-office
/// (`x_substitution_produit` sur `sale.order.line`, voir
/// `models/sale_order.py` + `views/sale_order_views.xml`) : Phase 1 n'a pas
/// de synchronisation stock temps réel. Accessible pour l'instant via un
/// bouton démo dans le suivi de commande (pas de vrai déclenchement par
/// notification push tant que F11 n'existe pas).
class SubstitutionScreen extends StatefulWidget {
  final String orderRef;

  const SubstitutionScreen({super.key, required this.orderRef});

  @override
  State<SubstitutionScreen> createState() => _SubstitutionScreenState();
}

class _SubstitutionScreenState extends State<SubstitutionScreen> {
  late Future<Map<String, dynamic>> _substitutionFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _substitutionFuture = _fetchSubstitution();
    });
  }

  Future<Map<String, dynamic>> _fetchSubstitution() async {
    final api = context.read<OdooApiClient>();
    final orders = await api.searchRead(
      model: 'sale.order',
      domain: [
        ['name', '=', widget.orderRef],
      ],
      fields: const ['name'],
      limit: 1,
    );
    if (orders.isEmpty) {
      throw const AppError(AppError.notFound);
    }
    final substitution = await api.getSubstitution(orderId: orders.first['id'] as int);
    if (substitution['pending'] != true) {
      throw const AppError(AppError.notFound);
    }
    return substitution;
  }

  Future<void> _respond({required bool accept}) async {
    if (_isSubmitting) return;
    final api = context.read<OdooApiClient>();
    final substitution = await _substitutionFuture;
    final lineId = substitution['line_id'] as int;

    setState(() => _isSubmitting = true);
    try {
      if (accept) {
        await api.acceptSubstitution(lineId: lineId);
      } else {
        await api.refuseSubstitution(lineId: lineId);
      }
      if (!mounted) return;
      context.pop();
    } on AppError catch (e) {
      if (mounted) AppMessenger.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('screens.Substitution.title'.tr())),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _substitutionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _load);
            }
            final substitution = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProductRow(
                    labelKey: 'substitution.original',
                    name: substitution['original_name'] as String? ?? '',
                    price: null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ProductRow(
                    labelKey: 'substitution.suggested',
                    name: substitution['substitute_name'] as String? ?? '',
                    price: formatPrice(context, (substitution['substitute_price'] as num?) ?? 0),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'substitution.accept'.tr(),
                    onPressed: _isSubmitting ? null : () => _respond(accept: true),
                  ),
                  AppButton(
                    label: 'substitution.refuse'.tr(),
                    onPressed: _isSubmitting ? null : () => _respond(accept: false),
                    variant: AppButtonVariant.danger,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String labelKey;
  final String name;
  final String? price;

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
          if (price != null) Text(price!),
        ],
      ),
    );
  }
}
