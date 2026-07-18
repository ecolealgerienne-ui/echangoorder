import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'Cart'>;

export function CartScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="Cart"
      actions={[
        { label: t('actions.goToCheckout'), onPress: () => navigation.navigate('CheckoutReceptionMode') },
      ]}
    />
  );
}
