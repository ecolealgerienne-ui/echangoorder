import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { ProfileStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<ProfileStackParamList, 'About'>;

export function AboutScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="About"
      actions={[
        { label: t('legal.cgu'), onPress: () => navigation.navigate('LegalDocument', { docType: 'cgu' }), variant: 'secondary' },
        { label: t('legal.privacy'), onPress: () => navigation.navigate('LegalDocument', { docType: 'privacy' }), variant: 'secondary' },
        { label: t('legal.legal'), onPress: () => navigation.navigate('LegalDocument', { docType: 'legal' }), variant: 'secondary' },
      ]}
    />
  );
}
