import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { CartScreen } from '../screens/cart/CartScreen';
import { CheckoutReceptionModeScreen } from '../screens/checkout/CheckoutReceptionModeScreen';
import { CheckoutAddressScreen } from '../screens/checkout/CheckoutAddressScreen';
import { CheckoutOutOfZoneScreen } from '../screens/checkout/CheckoutOutOfZoneScreen';
import { CheckoutTimeslotScreen } from '../screens/checkout/CheckoutTimeslotScreen';
import { CheckoutSummaryScreen } from '../screens/checkout/CheckoutSummaryScreen';
import { OrderConfirmationScreen } from '../screens/checkout/OrderConfirmationScreen';
import type { CartStackParamList } from './types';

const Stack = createNativeStackNavigator<CartStackParamList>();

export function CartStackNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerBackButtonDisplayMode: 'minimal' }}>
      <Stack.Screen name="Cart" component={CartScreen} />
      <Stack.Screen name="CheckoutReceptionMode" component={CheckoutReceptionModeScreen} />
      <Stack.Screen name="CheckoutAddress" component={CheckoutAddressScreen} />
      <Stack.Screen name="CheckoutOutOfZone" component={CheckoutOutOfZoneScreen} />
      <Stack.Screen name="CheckoutTimeslot" component={CheckoutTimeslotScreen} />
      <Stack.Screen name="CheckoutSummary" component={CheckoutSummaryScreen} />
      <Stack.Screen
        name="OrderConfirmation"
        component={OrderConfirmationScreen}
        options={{ headerShown: false, gestureEnabled: false }}
      />
    </Stack.Navigator>
  );
}
