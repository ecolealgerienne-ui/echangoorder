import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { ProfileScreen } from '../screens/profile/ProfileScreen';
import { AddressesScreen } from '../screens/profile/AddressesScreen';
import { MyLocationScreen } from '../screens/profile/MyLocationScreen';
import { ChangePinScreen } from '../screens/profile/ChangePinScreen';
import { NotificationSettingsScreen } from '../screens/profile/NotificationSettingsScreen';
import { LanguageSettingsScreen } from '../screens/profile/LanguageSettingsScreen';
import { OrderHistoryScreen } from '../screens/order/OrderHistoryScreen';
import { OrderTrackingScreen } from '../screens/order/OrderTrackingScreen';
import { AboutScreen } from '../screens/legal/AboutScreen';
import { LegalDocumentScreen } from '../screens/legal/LegalDocumentScreen';
import type { ProfileStackParamList } from './types';

const Stack = createNativeStackNavigator<ProfileStackParamList>();

export function ProfileStackNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerBackButtonDisplayMode: 'minimal' }}>
      <Stack.Screen name="Profile" component={ProfileScreen} />
      <Stack.Screen name="Addresses" component={AddressesScreen} />
      <Stack.Screen name="MyLocation" component={MyLocationScreen} />
      <Stack.Screen name="ChangePin" component={ChangePinScreen} />
      <Stack.Screen name="NotificationSettings" component={NotificationSettingsScreen} />
      <Stack.Screen name="LanguageSettings" component={LanguageSettingsScreen} />
      <Stack.Screen name="OrderHistory" component={OrderHistoryScreen} />
      <Stack.Screen name="OrderTracking" component={OrderTrackingScreen} />
      <Stack.Screen name="About" component={AboutScreen} />
      <Stack.Screen name="LegalDocument" component={LegalDocumentScreen} />
    </Stack.Navigator>
  );
}
