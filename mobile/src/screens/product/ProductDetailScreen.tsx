import React from 'react';
import { Text } from 'react-native';
import type { RouteProp } from '@react-navigation/native';
import type { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { typography } from '../../theme/theme';
import type { HomeStackParamList } from '../../navigation/types';

type Props = {
  route: RouteProp<HomeStackParamList, 'ProductDetail'>;
  navigation: NativeStackNavigationProp<HomeStackParamList, 'ProductDetail'>;
};

export function ProductDetailScreen({ route }: Props) {
  return (
    <ScreenPlaceholder screenKey="ProductDetail">
      <Text style={typography.body}>productId: {route.params.productId}</Text>
    </ScreenPlaceholder>
  );
}
