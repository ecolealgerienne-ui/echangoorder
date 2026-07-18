import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/screen_placeholder.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  void _share() {
    // Lien placeholder — format et domaine réels à définir avec le choix de
    // techno deep link (Branch.io / Firebase Dynamic Links, cf. status-V1.md).
    final link = 'https://echanorder.app/produit/$productId';
    Share.share('${'share.intro'.tr()}\n$link');
  }

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'ProductDetail',
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          onPressed: _share,
        ),
      ],
      child: Text('productId: $productId'),
    );
  }
}
