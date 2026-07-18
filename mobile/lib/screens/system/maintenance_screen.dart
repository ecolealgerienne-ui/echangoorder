import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../errors/error_state_view.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Le "Réessayer" relancera le health-check Odoo (GET /web/health) une fois
    // le backend branché ; pour l'instant, écran statique atteignable pour
    // valider la navigation (F14).
    return Scaffold(
      body: SafeArea(
        child: ErrorStateView(
          icon: Icons.build_circle_outlined,
          titleKey: 'screens.Maintenance.title',
          messageKey: 'screens.Maintenance.subtitle',
          retryLabel: 'actions.retry'.tr(),
          onRetry: () {},
        ),
      ),
    );
  }
}
