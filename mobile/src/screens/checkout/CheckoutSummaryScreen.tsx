import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'CheckoutSummary'>;

export function CheckoutSummaryScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="CheckoutSummary"
      actions={[
        {
          label: t('actions.confirmOrder'),
          onPress: () => navigation.navigate('OrderConfirmation', { orderRef: 'ECH-DEMO-0001' }),
        },
      ]}
    />
  );
}
