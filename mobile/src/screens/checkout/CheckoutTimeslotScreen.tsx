import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CartStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CartStackParamList, 'CheckoutTimeslot'>;

export function CheckoutTimeslotScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="CheckoutTimeslot"
      actions={[
        { label: t('common.continue'), onPress: () => navigation.navigate('CheckoutSummary') },
      ]}
    />
  );
}
