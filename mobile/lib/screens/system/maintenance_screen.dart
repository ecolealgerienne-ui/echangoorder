import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../widgets/screen_placeholder.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Le "Réessayer" relancera le health-check Odoo (GET /web/health) une fois
    // le backend branché ; pour l'instant, écran statique atteignable pour
    // valider la navigation (F14).
    return ScreenPlaceholder(
      screenKey: 'Maintenance',
      showAppBar: false,
      actions: [
        PlaceholderAction(label: 'actions.retry'.tr(), onPressed: () {}),
      ],
    );
  }
}
