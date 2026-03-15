import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import { useTheme } from '../theme/ThemeContext';
import { FileSystemService } from '../services/FileSystemService';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/AppNavigator';

type EditorScreenProps = NativeStackScreenProps<RootStackParamList, 'Editor'>;

export function EditorScreen({ route, navigation }: EditorScreenProps) {
  const { filePath } = route.params;
  const { theme } = useTheme();
  const [content, setContent] = useState('');
  const [originalContent, setOriginalContent] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadFile();
  }, [filePath]);

  const loadFile = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const fileContent = await FileSystemService.readFile(filePath);
      setContent(fileContent);
      setOriginalContent(fileContent);
      setHasChanges(false);
    } catch (err) {
      console.error('Failed to load file:', err);
      setError('Failed to load file');
    } finally {
      setIsLoading(false);
    }
  };

  const handleContentChange = (newContent: string) => {
    setContent(newContent);
    setHasChanges(newContent !== originalContent);
  };

  const handleSave = async () => {
    if (!hasChanges) return;

    setIsSaving(true);
    try {
      await FileSystemService.writeFile(filePath, content);
      setOriginalContent(content);
      setHasChanges(false);
    } catch (err) {
      console.error('Failed to save file:', err);
      setError('Failed to save file');
    } finally {
      setIsSaving(false);
    }
  };

  const getFileName = () => {
    const parts = filePath.split('/');
    return parts[parts.length - 1] || 'Untitled';
  };

  if (isLoading) {
    return (
      <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
        <ActivityIndicator size="large" color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: theme.colors.border }]}>
        <Text style={[styles.fileName, { color: theme.colors.text }]} numberOfLines={1}>
          {getFileName()}
        </Text>
        {hasChanges && (
          <Text style={[styles.unsavedIndicator, { color: theme.colors.primary }]}>
            ●
          </Text>
        )}
        <TouchableOpacity
          style={[
            styles.saveButton,
            { backgroundColor: hasChanges ? theme.colors.primary : theme.colors.border },
          ]}
          onPress={handleSave}
          disabled={!hasChanges || isSaving}
        >
          {isSaving ? (
            <ActivityIndicator size="small" color={theme.colors.background} />
          ) : (
            <Text style={[styles.saveButtonText, { color: theme.colors.background }]}>
              Save
            </Text>
          )}
        </TouchableOpacity>
      </View>

      {/* Error Message */}
      {error && (
        <View style={[styles.errorContainer, { backgroundColor: theme.colors.error + '20' }]}>
          <Text style={[styles.errorText, { color: theme.colors.error }]}>{error}</Text>
        </View>
      )}

      {/* Editor */}
      <ScrollView style={styles.content}>
        <TextInput
          style={[
            styles.editor,
            {
              color: theme.colors.text,
              backgroundColor: theme.colors.card,
            },
          ]}
          multiline
          value={content}
          onChangeText={handleContentChange}
          placeholder="Start typing..."
          placeholderTextColor={theme.colors.text + '60'}
          textAlignVertical="top"
          autoCapitalize="none"
          autoCorrect={false}
          spellCheck={false}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
  },
  fileName: {
    flex: 1,
    fontSize: 18,
    fontWeight: '600',
  },
  unsavedIndicator: {
    marginRight: 12,
    fontSize: 12,
  },
  saveButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    minWidth: 70,
    alignItems: 'center',
  },
  saveButtonText: {
    fontSize: 14,
    fontWeight: '600',
  },
  errorContainer: {
    padding: 12,
    margin: 16,
    borderRadius: 8,
  },
  errorText: {
    fontSize: 14,
    textAlign: 'center',
  },
  content: {
    flex: 1,
    padding: 16,
  },
  editor: {
    flex: 1,
    minHeight: 400,
    padding: 16,
    borderRadius: 8,
    fontSize: 16,
    lineHeight: 24,
  },
});
