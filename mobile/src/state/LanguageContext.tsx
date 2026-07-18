import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';
import { I18nManager } from 'react-native';
import RNRestart from 'react-native-restart';
import i18n, { AppLanguage, RTL_LANGUAGES } from '../i18n';

type LanguageContextValue = {
  language: AppLanguage;
  isRTL: boolean;
  // Applique la langue et redémarre l'app si la direction (LTR/RTL) change,
  // seul moyen fiable de remirrorer tout le layout natif (specs §4.3).
  setLanguage: (language: AppLanguage) => void;
};

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = useState<AppLanguage>('fr');

  const setLanguage = useCallback((next: AppLanguage) => {
    const nextIsRTL = RTL_LANGUAGES.includes(next);
    i18n.changeLanguage(next);
    setLanguageState(next);

    if (I18nManager.isRTL !== nextIsRTL) {
      I18nManager.allowRTL(nextIsRTL);
      I18nManager.forceRTL(nextIsRTL);
      RNRestart.restart();
    }
  }, []);

  const value = useMemo(
    () => ({ language, isRTL: I18nManager.isRTL, setLanguage }),
    [language, setLanguage],
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return ctx;
}
