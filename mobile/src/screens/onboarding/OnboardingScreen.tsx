import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import type { PublicStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<PublicStackParamList, 'Onboarding'>;

export function OnboardingScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { completeOnboarding } = useAuth();

  const finish = () => {
    completeOnboarding();
    navigation.replace('AuthWelcome');
  };

  return (
    <ScreenPlaceholder
      screenKey="Onboarding"
      actions={[
        { label: t('common.skip'), onPress: finish, variant: 'secondary' },
        { label: t('common.next'), onPress: finish },
      ]}
    />
  );
}
