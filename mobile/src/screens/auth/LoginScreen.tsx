import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'Login'>;

export function LoginScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { loginAsUser } = useAuth();

  return (
    <ScreenPlaceholder
      screenKey="Login"
      actions={[
        { label: t('actions.logIn'), onPress: loginAsUser },
        { label: t('actions.forgotPin'), onPress: () => navigation.navigate('ForgotPin'), variant: 'secondary' },
      ]}
    />
  );
}
