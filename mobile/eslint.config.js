const reactNativeConfig = require('@react-native/eslint-config/flat');

module.exports = [
  { ignores: ['android/**', 'ios/**'] },
  ...reactNativeConfig,
];
