import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import type { CatalogStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<CatalogStackParamList, 'Catalog'>;

export function CatalogScreen({ navigation }: Props) {
  const { t } = useTranslation();

  return (
    <ScreenPlaceholder
      screenKey="Catalog"
      actions={[
        {
          label: t('screens.CategoryProducts.title'),
          onPress: () => navigation.navigate('CategoryProducts', { categoryId: 'demo-cat' }),
        },
        {
          label: t('screens.Search.title'),
          onPress: () => navigation.navigate('Search'),
          variant: 'secondary',
        },
      ]}
    />
  );
}
