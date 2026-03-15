import { registerRootComponent } from 'expo';
import { Buffer } from 'buffer';
import process from 'process';

import App from './App';

if (!(globalThis as typeof globalThis & { Buffer?: typeof Buffer }).Buffer) {
  (globalThis as typeof globalThis & { Buffer?: typeof Buffer }).Buffer = Buffer;
}

if (!(globalThis as typeof globalThis & { process?: typeof process }).process) {
  (globalThis as typeof globalThis & { process?: typeof process }).process = process;
}

// registerRootComponent calls AppRegistry.registerComponent('main', () => App);
// It also ensures that whether you load the app in Expo Go or in a native build,
// the environment is set up appropriately
registerRootComponent(App);
