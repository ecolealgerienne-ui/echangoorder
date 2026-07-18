import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'Vitrine'>;

export function VitrineScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { hasSeenOnboarding } = useAuth();

  // Parcours specs §2 : clic "Ajouter au panier"/inscription → Onboarding
  // seulement à la première ouverture, sinon direct vers l'auth (F02).
  const goToAuth = () => navigation.navigate(hasSeenOnboarding ? 'AuthWelcome' : 'Onboarding');

  return (
    <ScreenPlaceholder
      screenKey="Vitrine"
      actions={[{ label: t('actions.signUpToOrder'), onPress: goToAuth }]}
    />
  );
}
