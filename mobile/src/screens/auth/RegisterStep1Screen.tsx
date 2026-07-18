import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'RegisterStep1'>;

export function RegisterStep1Screen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="RegisterStep1"
      actions={[
        { label: t('common.continue'), onPress: () => navigation.navigate('RegisterStep2') },
      ]}
    />
  );
}
