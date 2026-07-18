import React from 'react';
import { useTranslation } from 'react-i18next';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
import { ScreenPlaceholder } from '../../components/ScreenPlaceholder';
import { useAuth } from '../../state/AuthContext';
import { useComingSoon } from '../../utils/comingSoon';
import type { ProfileStackParamList } from '../../navigation/types';

type Props = NativeStackScreenProps<ProfileStackParamList, 'Profile'>;

export function ProfileScreen({ navigation }: Props) {
  const { t } = useTranslation();
  const { logout } = useAuth();
  const comingSoon = useComingSoon();

  return (
    <ScreenPlaceholder
      screenKey="Profile"
      actions={[
        { label: t('screens.Addresses.title'), onPress: () => navigation.navigate('Addresses'), variant: 'secondary' },
        { label: t('screens.MyLocation.title'), onPress: () => navigation.navigate('MyLocation'), variant: 'secondary' },
        { label: t('screens.ChangePin.title'), onPress: () => navigation.navigate('ChangePin'), variant: 'secondary' },
        { label: t('screens.NotificationSettings.title'), onPress: () => navigation.navigate('NotificationSettings'), variant: 'secondary' },
        { label: t('screens.LanguageSettings.title'), onPress: () => navigation.navigate('LanguageSettings'), variant: 'secondary' },
        { label: t('screens.OrderHistory.title'), onPress: () => navigation.navigate('OrderHistory') },
        { label: t('screens.About.title'), onPress: () => navigation.navigate('About'), variant: 'secondary' },
        { label: t('actions.logout'), onPress: logout, variant: 'secondary' },
        { label: t('actions.deleteAccount'), onPress: comingSoon, variant: 'danger' },
      ]}
    />
  );
}
