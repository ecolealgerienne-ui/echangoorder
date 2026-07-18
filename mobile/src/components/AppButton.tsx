import React from 'react';
import { Pressable, StyleSheet, Text } from 'react-native';
import { colors, layout, spacing, typography } from '../theme/theme';

type Props = {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'danger';
  testID?: string;
};

export function AppButton({ label, onPress, variant = 'primary', testID }: Props) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      testID={testID}
      onPress={onPress}
      style={({ pressed }) => [
        styles.base,
        variantStyles[variant],
        pressed && styles.pressed,
      ]}
    >
      <Text style={[styles.label, variant === 'secondary' && styles.labelSecondary]}>
        {label}
      </Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    minHeight: layout.minTouchHeight,
    borderRadius: layout.radius,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
    marginTop: spacing.sm,
  },
  pressed: {
    opacity: 0.8,
  },
  label: {
    ...typography.subtitle,
    color: colors.background,
  },
  labelSecondary: {
    color: colors.primary,
  },
});

const variantStyles = StyleSheet.create({
  primary: { backgroundColor: colors.primary },
  secondary: { backgroundColor: colors.background, borderWidth: 1, borderColor: colors.primary },
  danger: { backgroundColor: colors.danger },
});
