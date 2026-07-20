// Import explicite (préfixé) de dart:ui pour TextDirection : easy_localization
// exporte aussi un symbole TextDirection (utilisé pour le sens de la locale),
// qui entre en conflit avec dart:ui.TextDirection (celui de Directionality)
// dans les fichiers qui importent les deux — cf. RTL du chevron ci-dessous.
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loader.dart';

/// F04 — Catalogue : catégories dérivées des produits réellement visibles
/// (`formatted_read_group` sur `product.template` par `categ_id`), pas
/// d'un `search_read` direct sur `product.category` — celui-ci ferait
/// remonter aussi les catégories techniques par défaut d'Odoo (Dépenses,
/// Achats...) qui n'ont aucun produit vendable dedans.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    final api = context.read<OdooApiClient>();
    setState(() {
      _categoriesFuture = api.readGroup(
        model: 'product.template',
        domain: const [
          ['sale_ok', '=', true],
        ],
        groupBy: const ['categ_id'],
      );
    });
  }

  Future<void> _handleRefresh() async {
    _loadCategories();
    try {
      await _categoriesFuture;
    } catch (_) {
      // Déjà affiché par le FutureBuilder (snapshot.hasError).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('screens.Catalog.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'screens.Search.title'.tr(),
            onPressed: () => context.push('/catalog/search'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _CategoryListSkeleton();
              }
              if (snapshot.hasError) {
                final error =
                    snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
                return ErrorStateView.forError(error, onRetry: _loadCategories);
              }
              final groups = snapshot.data!;
              if (groups.isEmpty) {
                return const ErrorStateView(
                  icon: Icons.category_outlined,
                  titleKey: 'emptyStates.categoriesTitle',
                  messageKey: 'emptyStates.categoriesMessage',
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: groups.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  // categ_id remonte comme [id, "Nom affiché"] (many2one).
                  final categField = groups[index]['categ_id'] as List<dynamic>?;
                  if (categField == null) return const SizedBox.shrink();
                  final categId = categField[0] as int;
                  final categName = categField[1] as String;
                  final count = groups[index]['__count'] as int? ?? 0;
                  return ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(categName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$count', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 4),
                        Icon(
                          Directionality.of(context) == ui.TextDirection.rtl
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                        ),
                      ],
                    ),
                    onTap: () => context.push('/catalog/category/$categId', extra: categName),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Squelette chatoyant pendant le chargement des catégories (direction
/// Casbah, phase C) — remplace le spinner générique, silhouette proche du
/// `ListTile` réel pour un rendu plus lisible pendant l'attente.
class _CategoryListSkeleton extends StatelessWidget {
  const _CategoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            ShimmerBox(width: 24, height: 24, borderRadius: BorderRadius.all(Radius.circular(6))),
            SizedBox(width: AppSpacing.md),
            Expanded(child: ShimmerBox(width: double.infinity, height: 16)),
            SizedBox(width: AppSpacing.md),
            ShimmerBox(width: 28, height: 16),
          ],
        ),
      ),
    );
  }
}
