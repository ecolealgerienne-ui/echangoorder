import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { VitrineScreen } from '../screens/vitrine/VitrineScreen';
import { OnboardingScreen } from '../screens/onboarding/OnboardingScreen';
import { AuthWelcomeScreen } from '../screens/auth/AuthWelcomeScreen';
import { RegisterStep1Screen } from '../screens/auth/RegisterStep1Screen';
import { RegisterStep2Screen } from '../screens/auth/RegisterStep2Screen';
import { RegisterStep3Screen } from '../screens/auth/RegisterStep3Screen';
import { LoginScreen } from '../screens/auth/LoginScreen';
import { ForgotPinScreen } from '../screens/auth/ForgotPinScreen';
import type { PublicStackParamList } from './types';

const Stack = createNativeStackNavigator<PublicStackParamList>();

export function PublicStackNavigator() {
  return (
    <Stack.Navigator
      initialRouteName="Vitrine"
      screenOptions={{ headerBackButtonDisplayMode: 'minimal' }}
    >
      <Stack.Screen name="Vitrine" component={VitrineScreen} options={{ headerShown: false }} />
      <Stack.Screen name="Onboarding" component={OnboardingScreen} />
      <Stack.Screen name="AuthWelcome" component={AuthWelcomeScreen} options={{ title: '' }} />
      <Stack.Screen name="RegisterStep1" component={RegisterStep1Screen} />
      <Stack.Screen name="RegisterStep2" component={RegisterStep2Screen} />
      <Stack.Screen name="RegisterStep3" component={RegisterStep3Screen} />
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="ForgotPin" component={ForgotPinScreen} />
    </Stack.Navigator>
  );
}
