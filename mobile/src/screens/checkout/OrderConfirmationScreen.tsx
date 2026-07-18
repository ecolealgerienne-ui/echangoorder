import React from 'react';
import { Text } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { typography } from '../../theme/theme';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'OrderConfirmation'>;

export function OrderConfirmationScreen({ route, navigation }: Props) {
  const { t } = useTranslation();
  const { orderRef } = route.params;

  // Navigation inter-onglets (Panier -> Profil/Accueil) : passe par le navigator
  // parent (tabs), non typé finement ici pour rester simple pendant la phase
  // "navigation sans données".
  const parent = navigation.getParent();

  return (
    <ScreenPlaceholder
      screenKey="OrderConfirmation"
      actions={[
        {
          label: t('actions.trackOrder'),
          onPress: () =>
            (parent as any)?.navigate('ProfileTab', { screen: 'OrderTracking', params: { orderRef } }),
        },
        {
          label: t('actions.backHome'),
          onPress: () => (parent as any)?.navigate('HomeTab', { screen: 'Home' }),
          variant: 'secondary',
        },
      ]}
    >
      <Text style={typography.body}>Réf : {orderRef}</Text>
    </ScreenPlaceholder>
  );
}
