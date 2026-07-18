import React from 'react';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useLanguage } from '../../state/LanguageContext';

export function LanguageSettingsScreen() {
  const { language, setLanguage } = useLanguage();

  return (
    <ScreenPlaceholder
      screenKey="LanguageSettings"
      actions={[
        { label: 'Français', onPress: () => setLanguage('fr'), variant: language === 'fr' ? 'primary' : 'secondary' },
        { label: 'العربية', onPress: () => setLanguage('ar'), variant: language === 'ar' ? 'primary' : 'secondary' },
      ]}
    />
  );
}
