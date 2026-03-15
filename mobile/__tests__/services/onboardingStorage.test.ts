import AsyncStorage from '@react-native-async-storage/async-storage';
import { OnboardingStorage } from '../../src/services/onboardingStorage';

// Mock AsyncStorage
jest.mock('@react-native-async-storage/async-storage', () => ({
  setItem: jest.fn(() => Promise.resolve()),
  getItem: jest.fn(() => Promise.resolve(null)),
  removeItem: jest.fn(() => Promise.resolve()),
}));

describe('OnboardingStorage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('hasCompletedOnboarding', () => {
    it('should return false when no onboarding state is stored', async () => {
      (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce(null);

      const result = await OnboardingStorage.hasCompletedOnboarding();

      expect(result).toBe(false);
      expect(AsyncStorage.getItem).toHaveBeenCalledWith('onboarding_completed');
    });

    it('should return true when onboarding is marked as completed', async () => {
      (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce('true');

      const result = await OnboardingStorage.hasCompletedOnboarding();

      expect(result).toBe(true);
    });
  });

  describe('setOnboardingCompleted', () => {
    it('should persist onboarding completed state', async () => {
      await OnboardingStorage.setOnboardingCompleted();

      expect(AsyncStorage.setItem).toHaveBeenCalledWith('onboarding_completed', 'true');
    });
  });

  describe('clearOnboardingState', () => {
    it('should remove onboarding state from storage', async () => {
      await OnboardingStorage.clearOnboardingState();

      expect(AsyncStorage.removeItem).toHaveBeenCalledWith('onboarding_completed');
    });
  });

  describe('active repository path', () => {
    it('should persist active repository path', async () => {
      await OnboardingStorage.setActiveRepositoryPath('file:///mock/documents/vault/repo');

      expect(AsyncStorage.setItem).toHaveBeenCalledWith(
        'active_repository_path',
        'file:///mock/documents/vault/repo'
      );
    });

    it('should retrieve active repository path', async () => {
      (AsyncStorage.getItem as jest.Mock).mockResolvedValueOnce('file:///mock/documents/vault/repo');

      const result = await OnboardingStorage.getActiveRepositoryPath();

      expect(result).toBe('file:///mock/documents/vault/repo');
      expect(AsyncStorage.getItem).toHaveBeenCalledWith('active_repository_path');
    });

    it('should clear active repository path', async () => {
      await OnboardingStorage.clearActiveRepositoryPath();

      expect(AsyncStorage.removeItem).toHaveBeenCalledWith('active_repository_path');
    });
  });
});
