import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'RegisterStep2'>;

export function RegisterStep2Screen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="RegisterStep2"
      actions={[
        { label: t('common.continue'), onPress: () => navigation.navigate('RegisterStep3') },
        { label: t('common.skip'), onPress: () => navigation.navigate('RegisterStep3'), variant: 'secondary' },
      ]}
    />
  );
}
