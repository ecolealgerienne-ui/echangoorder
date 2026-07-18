/**
 * Echango Order — App mobile client
 * @format
 */

import React from 'react';
import { StatusBar, useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import './src/i18n';
import { AuthProvider } from './src/state/AuthContext';
import { LanguageProvider } from './src/state/LanguageContext';
import { RootNavigator } from './src/navigation/RootNavigator';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <LanguageProvider>
        <AuthProvider>
          <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
          <RootNavigator />
        </AuthProvider>
      </LanguageProvider>
    </SafeAreaProvider>
  );
}

export default App;
