import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'RegisterStep3'>;

export function RegisterStep3Screen(_props: Props) {
  const { t } = useTranslation();
  const { loginAsUser } = useAuth();

  return (
    <ScreenPlaceholder
      screenKey="RegisterStep3"
      actions={[{ label: t('common.confirm'), onPress: loginAsUser }]}
    />
  );
}
