import React from 'react';
import { Text } from 'react-native';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { typography } from '../../theme/theme';
import type { ProfileStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<ProfileStackParamList, 'LegalDocument'>;

export function LegalDocumentScreen({ route }: Props) {
  const { t } = useTranslation();
  const { docType } = route.params;

  return (
    <ScreenPlaceholder screenKey="LegalDocument">
      <Text style={typography.subtitle}>{t(`legal.${docType}`)}</Text>
    </ScreenPlaceholder>
  );
}
