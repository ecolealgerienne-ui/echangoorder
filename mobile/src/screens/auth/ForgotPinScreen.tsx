import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'ForgotPin'>;

export function ForgotPinScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="ForgotPin"
      actions={[{ label: t('common.back'), onPress: () => navigation.navigate('Login'), variant: 'secondary' }]}
    />
  );
}
