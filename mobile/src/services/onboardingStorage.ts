import AsyncStorage from '@react-native-async-storage/async-storage';

const ONBOARDING_COMPLETED_KEY = 'onboarding_completed';
const ACTIVE_REPOSITORY_PATH_KEY = 'active_repository_path';

export class OnboardingStorage {
  static async hasCompletedOnboarding(): Promise<boolean> {
    const value = await AsyncStorage.getItem(ONBOARDING_COMPLETED_KEY);
    return value === 'true';
  }

  static async setOnboardingCompleted(): Promise<void> {
    await AsyncStorage.setItem(ONBOARDING_COMPLETED_KEY, 'true');
  }

  static async clearOnboardingState(): Promise<void> {
    await AsyncStorage.removeItem(ONBOARDING_COMPLETED_KEY);
  }

  static async getActiveRepositoryPath(): Promise<string | null> {
    return await AsyncStorage.getItem(ACTIVE_REPOSITORY_PATH_KEY);
  }

  static async setActiveRepositoryPath(path: string): Promise<void> {
    await AsyncStorage.setItem(ACTIVE_REPOSITORY_PATH_KEY, path);
  }

  static async clearActiveRepositoryPath(): Promise<void> {
    await AsyncStorage.removeItem(ACTIVE_REPOSITORY_PATH_KEY);
  }
}
