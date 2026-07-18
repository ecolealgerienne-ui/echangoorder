import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'CheckoutReceptionMode'>;

export function CheckoutReceptionModeScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="CheckoutReceptionMode"
      actions={[
        { label: t('checkout.deliveryHome'), onPress: () => navigation.navigate('CheckoutAddress') },
        { label: t('checkout.pickupStore'), onPress: () => navigation.navigate('CheckoutTimeslot'), variant: 'secondary' },
      ]}
    />
  );
}
