import React from 'react';
import { Text } from 'react-native';
import { useTranslation } from 'react-i18next';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { HomeStackNavigator } from './HomeStackNavigator';
import { CatalogStackNavigator } from './CatalogStackNavigator';
import { CartStackNavigator } from './CartStackNavigator';
import { ProfileStackNavigator } from './ProfileStackNavigator';
import { colors } from '../theme/theme';
import type { MainTabParamList } from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();

// Définis au niveau module (et non dans screenOptions) pour rester des
// références stables entre les rendus — voir react/no-unstable-nested-components.
const renderHomeIcon = () => <Text>🏠</Text>;
const renderCatalogIcon = () => <Text>📋</Text>;
const renderCartIcon = () => <Text>🛒</Text>;
const renderProfileIcon = () => <Text>👤</Text>;

export function MainTabNavigator() {
  const { t } = useTranslation();

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
      }}
    >
      <Tab.Screen
        name="HomeTab"
        component={HomeStackNavigator}
        options={{ tabBarLabel: t('nav.home'), tabBarIcon: renderHomeIcon }}
      />
      <Tab.Screen
        name="CatalogTab"
        component={CatalogStackNavigator}
        options={{ tabBarLabel: t('nav.catalog'), tabBarIcon: renderCatalogIcon }}
      />
      <Tab.Screen
        name="CartTab"
        component={CartStackNavigator}
        options={{ tabBarLabel: t('nav.cart'), tabBarIcon: renderCartIcon }}
      />
      <Tab.Screen
        name="ProfileTab"
        component={ProfileStackNavigator}
        options={{ tabBarLabel: t('nav.profile'), tabBarIcon: renderProfileIcon }}
      />
    </Tab.Navigator>
  );
}
