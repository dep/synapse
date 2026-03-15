// Define __DEV__ for React Native
global.__DEV__ = true;

// Define __fbBatchedBridgeConfig for React Native
global.__fbBatchedBridgeConfig = {
  remoteModuleConfig: [],
  localModulesConfig: [],
};

// Mock AsyncStorage
jest.mock('@react-native-async-storage/async-storage', () => ({
  setItem: jest.fn(() => Promise.resolve()),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(() => Promise.resolve()),
}));

// Mock react-native
jest.mock('react-native', () => {
  const React = require('react');
  
  const mockComponent = (name) => {
    return React.forwardRef((props, ref) => {
      return React.createElement(name, { ...props, ref });
    });
  };
  
  return {
    View: mockComponent('View'),
    Text: mockComponent('Text'),
    TouchableOpacity: mockComponent('TouchableOpacity'),
    ScrollView: mockComponent('ScrollView'),
    Modal: mockComponent('Modal'),
    TextInput: mockComponent('TextInput'),
    Animated: {
      View: mockComponent('Animated.View'),
      Value: jest.fn((val) => ({
        setValue: jest.fn(),
        _value: val,
      })),
      timing: jest.fn(() => ({
        start: jest.fn((cb) => cb && cb()),
      })),
    },
    StyleSheet: {
      create: jest.fn((styles) => styles),
      flatten: jest.fn((style) => style),
      compose: jest.fn((style1, style2) => [style1, style2]),
      absoluteFill: {
        position: 'absolute',
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
      },
      hairlineWidth: 1,
    },
    Dimensions: {
      get: jest.fn(() => ({ width: 375, height: 812, scale: 2, fontScale: 1 })),
      addEventListener: jest.fn(() => ({ remove: jest.fn() })),
    },
    useColorScheme: jest.fn(() => 'light'),
    PixelRatio: {
      get: jest.fn(() => 2),
      roundToNearestPixel: jest.fn((value) => value),
    },
  };
});

// Mock useColorScheme from the proper path
jest.mock('react-native/Libraries/Utilities/useColorScheme', () => ({
  default: jest.fn(() => 'light'),
}));
