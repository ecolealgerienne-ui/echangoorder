import React from 'react';
import { useTranslation } from 'react-i18next';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';

export function MaintenanceScreen() {
  const { t } = useTranslation();

  // Le "Réessayer" relancera le health-check Odoo (GET /web/health) une fois
  // le backend branché ; pour l'instant, écran statique atteignable pour
  // valider la navigation (F14).
  return (
    <ScreenPlaceholder screenKey="Maintenance" actions={[{ label: t('actions.retry'), onPress: () => {} }]} />
  );
}
