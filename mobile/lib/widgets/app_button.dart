import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(label, textAlign: TextAlign.center),
    );

    final tokens = AppColorTokens.of(context);
    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(onPressed: onPressed, child: child),
      AppButtonVariant.secondary => OutlinedButton(onPressed: onPressed, child: child),
      AppButtonVariant.danger => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.danger,
            foregroundColor: tokens.surface,
            minimumSize: const Size.fromHeight(AppLayout.minTouchHeight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radius)),
          ),
          onPressed: onPressed,
          child: child,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: PressableScale(enabled: onPressed != null, child: button),
    );
  }
}
