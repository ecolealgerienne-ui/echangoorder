import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CatalogStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CatalogStackParamList, 'Search'>;

export function SearchScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="Search"
      actions={[
        {
          label: t('screens.ProductDetail.title'),
          onPress: () => navigation.navigate('ProductDetail', { productId: 'demo-1' }),
        },
      ]}
    />
  );
}
