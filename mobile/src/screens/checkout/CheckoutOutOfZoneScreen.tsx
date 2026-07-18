import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'CheckoutOutOfZone'>;

export function CheckoutOutOfZoneScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="CheckoutOutOfZone"
      actions={[
        { label: t('checkout.pickupStore'), onPress: () => navigation.navigate('CheckoutTimeslot') },
        {
          label: t('checkout.modifyAddress'),
          onPress: () => navigation.navigate('CheckoutAddress'),
          variant: 'secondary',
        },
      ]}
    />
  );
}
