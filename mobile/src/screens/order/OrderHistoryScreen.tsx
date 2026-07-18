import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { ProfileStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<ProfileStackParamList, 'OrderHistory'>;

export function OrderHistoryScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="OrderHistory"
      actions={[
        {
          label: t('screens.OrderTracking.title'),
          onPress: () => navigation.navigate('OrderTracking', { orderRef: 'ECH-DEMO-0001' }),
        },
      ]}
    />
  );
}
