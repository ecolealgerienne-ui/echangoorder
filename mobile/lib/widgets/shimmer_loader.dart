import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rectangle chatoyant ("shimmer") — remplace les `CircularProgressIndicator`
/// dans les écrans de liste (direction Casbah, voir
/// `docs/design_direction.md`) : donne un aperçu de la mise en page à venir
/// plutôt qu'un spinner neutre, gain de vitesse perçue. Câblage dans les
/// écrans (Accueil/Catalogue) prévu en phase C — ce widget est le seul
/// ajout de la phase B (composants partagés).
///
/// Respecte le réglage d'accessibilité système "réduire les animations" —
/// affiche un aplat statique dans ce cas plutôt que l'animation de balayage.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppLayout.radius)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final base = AppColors.border;

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: widget.borderRadius),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final sweep = -1.5 + 3.0 * _controller.value;
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              gradient: LinearGradient(
                colors: [base, AppColors.surface, base],
                stops: const [0.35, 0.5, 0.65],
                begin: Alignment(sweep - 0.6, 0),
                end: Alignment(sweep + 0.6, 0),
              ),
            ),
            child: SizedBox(width: widget.width, height: widget.height),
          ),
        );
      },
    );
  }
}
