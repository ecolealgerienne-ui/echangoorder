import { Alert } from 'react-native';
import { useTranslation } from 'react-i18next';

/**
 * Action non implémentable tant qu'Odoo n'est pas branché (ex: suppression de
 * compte, annulation effective). Affiche un message explicite plutôt qu'un
 * bouton silencieux, le temps de la phase "navigation sans données".
 */
export function useComingSoon() {
  const { t } = useTranslation();
  return () => Alert.alert(t('common.comingSoon'));
}
