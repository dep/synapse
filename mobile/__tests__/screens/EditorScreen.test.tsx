import React from 'react';
import { render, waitFor } from '@testing-library/react-native';
import { ThemeProvider } from '../../src/theme/ThemeContext';
import { EditorScreen } from '../../src/screens/EditorScreen';
import { FileSystemService } from '../../src/services/FileSystemService';
import { GitService } from '../../src/services/gitService';
import { OnboardingStorage } from '../../src/services/onboardingStorage';

jest.mock('../../src/services/FileSystemService', () => ({
  FileSystemService: {
    readFile: jest.fn(),
    writeFile: jest.fn(),
  },
}));

jest.mock('../../src/services/gitService', () => ({
  GitService: {
    sync: jest.fn(),
  },
}));

jest.mock('../../src/services/onboardingStorage', () => ({
  OnboardingStorage: {
    getActiveRepositoryPath: jest.fn(),
  },
}));

jest.mock('@react-navigation/native', () => ({
  useFocusEffect: jest.fn(),
}));

describe('EditorScreen', () => {
  const mockNavigate = jest.fn();
  const mockAddListener = jest.fn(() => jest.fn());

  const renderScreen = () =>
    render(
      <ThemeProvider>
        <EditorScreen
          route={{ key: 'Editor', name: 'Editor', params: { filePath: 'file:///vault/repo/note.md' } } as any}
          navigation={{ navigate: mockNavigate, addListener: mockAddListener } as any}
        />
      </ThemeProvider>
    );

  beforeEach(() => {
    jest.clearAllMocks();
    (FileSystemService.readFile as jest.Mock).mockResolvedValue('# Old note');
    (FileSystemService.writeFile as jest.Mock).mockResolvedValue(undefined);
    (GitService.sync as jest.Mock).mockResolvedValue({ pulled: true, committed: 'sha', pushed: true });
    (OnboardingStorage.getActiveRepositoryPath as jest.Mock).mockResolvedValue('file:///vault/repo');
  });

  it('loads file content on mount', async () => {
    renderScreen();

    await waitFor(() => {
      expect(FileSystemService.readFile).toHaveBeenCalledWith('file:///vault/repo/note.md');
    });
  });
});
