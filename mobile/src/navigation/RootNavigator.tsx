import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { PublicStackNavigator } from './PublicStackNavigator';
import { MainTabNavigator } from './MainTabNavigator';
import { MaintenanceScreen } from '../screens/system/MaintenanceScreen';
import { useAuth } from '../state/AuthContext';
import type { RootStackParamList } from './types';

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  const { status } = useAuth();
  const isAuthenticated = status !== 'unauthenticated';

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {isAuthenticated ? (
          <Stack.Screen name="Main" component={MainTabNavigator} />
        ) : (
          <Stack.Screen name="Public" component={PublicStackNavigator} />
        )}
        {/* Affiché quand le health-check Odoo (GET /web/health) échoue, une fois branché */}
        <Stack.Screen name="Maintenance" component={MaintenanceScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
