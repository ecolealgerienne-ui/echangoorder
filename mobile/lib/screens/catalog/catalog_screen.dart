import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../errors/app_error.dart';
import '../../errors/error_state_view.dart';
import '../../services/odoo_api_client.dart';

/// F04 — Catalogue : liste des catégories (`product.category`), tap →
/// grille de produits filtrée par catégorie.
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
      _categoriesFuture = api.searchRead(
        model: 'product.category',
        fields: const ['name'],
        limit: 100,
      );
    });
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
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error =
                  snapshot.error is AppError ? snapshot.error as AppError : const AppError(AppError.unknown);
              return ErrorStateView.forError(error, onRetry: _loadCategories);
            }
            final categories = snapshot.data!;
            if (categories.isEmpty) {
              return const ErrorStateView(
                icon: Icons.category_outlined,
                titleKey: 'emptyStates.categoriesTitle',
                messageKey: 'emptyStates.categoriesMessage',
              );
            }
            return ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                final name = category['name'] as String? ?? '';
                return ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/catalog/category/${category['id']}', extra: name),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
