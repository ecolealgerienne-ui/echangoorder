// Design tokens — voir CLAUDE.md § Exigences transversales (accessibilité, performance)
export const colors = {
  background: '#FFFFFF',
  surface: '#F5F6F8',
  primary: '#1F8A55',
  primaryDark: '#166B41',
  text: '#171A1F',
  textMuted: '#5B6270',
  border: '#E1E4E9',
  danger: '#D64545',
  success: '#1F8A55',
  disabled: '#C7CBD1',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
};

// Accessibilité : police min 14px, boutons min 44px de hauteur (specs §4.2)
export const typography = {
  title: { fontSize: 22, fontWeight: '700' as const },
  subtitle: { fontSize: 16, fontWeight: '600' as const },
  body: { fontSize: 14, fontWeight: '400' as const },
  caption: { fontSize: 12, fontWeight: '400' as const },
};

export const layout = {
  minTouchHeight: 44,
  radius: 12,
};
