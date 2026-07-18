import React from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { useTranslation } from 'react-i18next';
import { AppButton } from './AppButton';
import { colors, spacing, typography } from '../theme/theme';

export type PlaceholderAction = {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
};

type Props = {
  /** Clé dans locales/*.json → screens.<screenKey> */
  screenKey: string;
  actions?: PlaceholderAction[];
  children?: React.ReactNode;
};

/**
 * Écran générique utilisé pendant la phase "navigation sans données" :
 * chaque écran réel (F00-F17) importe ce composant pour valider le parcours
 * avant d'être rempli avec sa propre UI + les appels Odoo.
 */
export function ScreenPlaceholder({ screenKey, actions = [], children }: Props) {
  const { t } = useTranslation();

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>{t(`screens.${screenKey}.title`)}</Text>
      <Text style={styles.subtitle}>{t(`screens.${screenKey}.subtitle`)}</Text>
      {children}
      <View style={styles.actions}>
        {actions.map(action => (
          <AppButton key={action.label} {...action} />
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: spacing.lg,
    backgroundColor: colors.background,
  },
  title: {
    ...typography.title,
    color: colors.text,
  },
  subtitle: {
    ...typography.body,
    color: colors.textMuted,
    marginTop: spacing.xs,
    marginBottom: spacing.lg,
  },
  actions: {
    marginTop: spacing.lg,
  },
});
