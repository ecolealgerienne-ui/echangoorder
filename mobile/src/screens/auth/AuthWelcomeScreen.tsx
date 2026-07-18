import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'AuthWelcome'>;

export function AuthWelcomeScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { continueAsGuest } = useAuth();

  return (
    <ScreenPlaceholder
      screenKey="AuthWelcome"
      actions={[
        { label: t('actions.signUp'), onPress: () => navigation.navigate('RegisterStep1') },
        { label: t('actions.logIn'), onPress: () => navigation.navigate('Login'), variant: 'secondary' },
        { label: t('actions.continueAsGuest'), onPress: continueAsGuest, variant: 'secondary' },
      ]}
    />
  );
}
