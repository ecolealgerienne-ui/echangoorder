import 'package:flutter/material.dart';
import '../../widgets/screen_placeholder.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return ScreenPlaceholder(
      screenKey: 'ProductDetail',
      child: Text('productId: $productId'),
    );
  }
}
