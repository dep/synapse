module.exports = {
  setupFilesAfterEnv: ['./jest-setup.js'],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/android/',
    '/ios/',
  ],
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-navigation|react-native-screens|react-native-safe-area-context|@react-native-async-storage|expo-file-system)/)',
  ],
  moduleNameMapper: {
    // Stub out expo-file-system and its legacy sub-path for all tests.
    // Individual test files that need specific behaviour mock it explicitly.
    'expo-file-system/legacy': '<rootDir>/__mocks__/expo-file-system-legacy.js',
    'expo-file-system': '<rootDir>/__mocks__/expo-file-system-legacy.js',
  },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  testMatch: ['**/__tests__/**/*.test.{ts,tsx}', '**/?(*.)+(spec|test).{ts,tsx}'],
  transform: {
    '^.+\.(js|jsx|ts|tsx)$': ['babel-jest', { presets: ['@react-native/babel-preset'] }],
  },
};
