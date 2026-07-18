import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'CheckoutAddress'>;

export function CheckoutAddressScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="CheckoutAddress"
      actions={[
        { label: t('common.continue'), onPress: () => navigation.navigate('CheckoutTimeslot') },
        {
          label: t('screens.CheckoutOutOfZone.title'),
          onPress: () => navigation.navigate('CheckoutOutOfZone'),
          variant: 'secondary',
        },
      ]}
    />
  );
}
