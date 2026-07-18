import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { CatalogScreen } from '../screens/catalog/CatalogScreen';
import { CategoryProductsScreen } from '../screens/catalog/CategoryProductsScreen';
import { SearchScreen } from '../screens/catalog/SearchScreen';
import { ProductDetailScreen } from '../screens/product/ProductDetailScreen';
import type { CatalogStackParamList } from './types';

const Stack = createNativeStackNavigator<CatalogStackParamList>();

export function CatalogStackNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerBackButtonDisplayMode: 'minimal' }}>
      <Stack.Screen name="Catalog" component={CatalogScreen} />
      <Stack.Screen name="CategoryProducts" component={CategoryProductsScreen} />
      <Stack.Screen name="Search" component={SearchScreen} />
      {/* ProductDetailScreen est typé sur HomeStackParamList ; même shape de params ici. */}
      <Stack.Screen name="ProductDetail" component={ProductDetailScreen as any} options={{ title: '' }} />
    </Stack.Navigator>
  );
}
