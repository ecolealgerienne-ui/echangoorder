import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Retour tactile discret (légère réduction d'échelle au toucher) pour les
/// contrôles d'action — bouton principal, ajout au panier (direction
/// Casbah, voir `docs/design_direction.md`).
///
/// Utilise [Listener] plutôt que [GestureDetector] : il observe les
/// événements de pointeur sans participer à l'arène de gestes, donc aucun
/// risque de conflit avec le `onPressed`/`onTap` du widget enveloppé (qui
/// reste seul responsable de l'action). Respecte le réglage d'accessibilité
/// système "réduire les animations" ([MediaQuery.disableAnimations]).
class PressableScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PressableScale({super.key, required this.child, this.enabled = true});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || !widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.96 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
