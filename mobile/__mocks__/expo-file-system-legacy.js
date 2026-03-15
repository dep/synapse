// Shared mock for expo-file-system and expo-file-system/legacy.
// Tests that need specific behaviour override individual functions with jest.fn().mockResolvedValueOnce(...)

module.exports = {
  documentDirectory: 'file:///mock/documents/',
  EncodingType: {
    UTF8: 'utf8',
    Base64: 'base64',
  },
  readAsStringAsync: jest.fn(() => Promise.resolve('')),
  writeAsStringAsync: jest.fn(() => Promise.resolve()),
  readDirectoryAsync: jest.fn(() => Promise.resolve([])),
  getInfoAsync: jest.fn(() =>
    Promise.resolve({ exists: true, isDirectory: false, size: 100, modificationTime: Date.now() / 1000 })
  ),
  makeDirectoryAsync: jest.fn(() => Promise.resolve()),
  deleteAsync: jest.fn(() => Promise.resolve()),
  copyAsync: jest.fn(() => Promise.resolve()),
};
