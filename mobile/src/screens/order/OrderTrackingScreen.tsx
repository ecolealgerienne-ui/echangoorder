import React from 'react';
import { Alert, Text } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { typography } from '../../theme/theme';
import { useComingSoon } from '../../utils/comingSoon';
import type { ProfileStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<ProfileStackParamList, 'OrderTracking'>;

export function OrderTrackingScreen({ route }: Props) {
  const { t } = useTranslation();
  const comingSoon = useComingSoon();
  const { orderRef } = route.params;

  const confirmCancel = () => {
    Alert.alert(
      t('screens.OrderTracking.title'),
      t('actions.cancelOrder') + ' ?',
      [
        { text: t('order.keepOrder'), style: 'cancel' },
        { text: t('order.confirmCancel'), style: 'destructive', onPress: comingSoon },
      ],
    );
  };

  return (
    <ScreenPlaceholder
      screenKey="OrderTracking"
      actions={[{ label: t('actions.cancelOrder'), onPress: confirmCancel, variant: 'danger' }]}
    >
      <Text style={typography.body}>Réf : {orderRef}</Text>
    </ScreenPlaceholder>
  );
}
