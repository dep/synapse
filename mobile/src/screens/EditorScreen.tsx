import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  Alert,
  BackHandler,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialIcons } from '@expo/vector-icons';
import Markdown from 'react-native-markdown-display';
import { useTheme } from '../theme/ThemeContext';
import { FileSystemService } from '../services/FileSystemService';
import { GitService } from '../services/gitService';
import { OnboardingStorage } from '../services/onboardingStorage';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import { useFocusEffect } from '@react-navigation/native';

const getRelativePath = (root: string, filePath: string) => {
  const normalizedRoot = root.replace(/\/+$/, '');
  const normalizedFile = filePath.replace(/\/+$/, '');
  if (!normalizedFile.startsWith(normalizedRoot + '/')) {
    return normalizedFile;
  }
  return normalizedFile.slice(normalizedRoot.length + 1);
};

type EditorScreenProps = NativeStackScreenProps<RootStackParamList, 'Editor'>;

// WikiLink rule for markdown-it
const wikiLinkRule = (state: any, silent: boolean) => {
  const start = state.pos;
  const marker = state.src.charCodeAt(start);

  if (marker !== 0x5B /* [ */ || state.src.charCodeAt(start + 1) !== 0x5B /* [ */) {
    return false;
  }

  const end = state.src.indexOf(']]', start + 2);
  if (end === -1) return false;

  const content = state.src.slice(start + 2, end);
  if (!silent) {
    const token = state.push('wiki_link', 'wiki_link', 0);
    token.content = content;
    token.markup = '[[';
    token.info = ']]';
  }

  state.pos = end + 2;
  return true;
};

export function EditorScreen({ route, navigation }: EditorScreenProps) {
  const { filePath } = route.params;
  const { theme, isDark } = useTheme();
  const [content, setContent] = useState('');
  const [originalContent, setOriginalContent] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isPreviewMode, setIsPreviewMode] = useState(false);

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
    setError(null);
    try {
      await FileSystemService.writeFile(filePath, content);
      const repositoryPath = await OnboardingStorage.getActiveRepositoryPath();
      if (repositoryPath) {
        await GitService.sync(repositoryPath, [getRelativePath(repositoryPath, filePath)]);
      }
      setOriginalContent(content);
      setHasChanges(false);
    } catch (err) {
      console.error('Failed to save file:', err);
      setError('Failed to save file or sync repository');
    } finally {
      setIsSaving(false);
    }
  };

  // Handle back navigation with unsaved changes
  const handleBackPress = useCallback(() => {
    if (hasChanges) {
      Alert.alert(
        'Save Changes?',
        'You have unsaved changes. Would you like to save them before leaving?',
        [
          {
            text: 'Cancel',
            style: 'cancel',
            onPress: () => {
              // Do nothing, stay on the screen
            },
          },
          {
            text: "Don't Save",
            style: 'destructive',
            onPress: () => {
              setHasChanges(false);
              navigation.navigate('Home', { openDrawer: true });
            },
          },
          {
            text: 'Save',
            style: 'default',
            onPress: async () => {
              await handleSave();
              navigation.navigate('Home', { openDrawer: true });
            },
          },
        ]
      );
      return true; // Prevent default back action
    }
    return false; // Allow default back action
  }, [hasChanges, navigation, content, originalContent]);

  // Intercept Android back button
  useFocusEffect(
    useCallback(() => {
      const onBackPress = () => {
        if (hasChanges) {
          handleBackPress();
          return true;
        }
        navigation.navigate('Home', { openDrawer: true });
        return true;
      };

      const subscription = BackHandler.addEventListener('hardwareBackPress', onBackPress);

      return () => subscription.remove();
    }, [hasChanges, handleBackPress, navigation])
  );

  // Intercept navigation before leaving
  useEffect(() => {
    const unsubscribe = navigation.addListener('beforeRemove', (e) => {
      if (!hasChanges) {
        return;
      }

      // Prevent default behavior
      e.preventDefault();

      // Show save dialog
      Alert.alert(
        'Save Changes?',
        'You have unsaved changes. Would you like to save them before leaving?',
        [
          {
            text: 'Cancel',
            style: 'cancel',
            onPress: () => {
              // Do nothing, stay on the screen
            },
          },
          {
            text: "Don't Save",
            style: 'destructive',
            onPress: () => {
              navigation.dispatch(e.data.action);
            },
          },
          {
            text: 'Save',
            style: 'default',
            onPress: async () => {
              try {
                await FileSystemService.writeFile(filePath, content);
                const repositoryPath = await OnboardingStorage.getActiveRepositoryPath();
                if (repositoryPath) {
                  await GitService.sync(repositoryPath, [getRelativePath(repositoryPath, filePath)]);
                }
                navigation.dispatch(e.data.action);
              } catch (err) {
                console.error('Failed to save file:', err);
                Alert.alert('Error', 'Failed to save file. Staying on screen.');
              }
            },
          },
        ]
      );
    });

    return unsubscribe;
  }, [navigation, hasChanges, content, filePath, originalContent]);

  const getFileName = () => {
    const parts = filePath.split('/');
    return parts[parts.length - 1] || 'Untitled';
  };

  const handleTogglePreview = () => {
    setIsPreviewMode(!isPreviewMode);
  };

  // Parse wiki links for custom rendering
  const parseWikiLinks = (text: string): string => {
    // Convert [[Target|Display]] or [[Target]] to markdown links
    return text.replace(
      /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g,
      (match, target, display) => {
        const displayText = display || target;
        return `[${displayText}](synapse://wikilink/${encodeURIComponent(target)})`;
      }
    );
  };

  // Markdown styles based on theme
  const markdownStyles = {
    body: {
      color: theme.colors.text,
      fontSize: 16,
      lineHeight: 26,
    },
    heading1: {
      color: theme.colors.text,
      fontSize: 28,
      fontWeight: '700' as const,
      marginBottom: 16,
      marginTop: 24,
    },
    heading2: {
      color: theme.colors.text,
      fontSize: 22,
      fontWeight: '700' as const,
      marginBottom: 12,
      marginTop: 20,
    },
    heading3: {
      color: theme.colors.text,
      fontSize: 18,
      fontWeight: '600' as const,
      marginBottom: 10,
      marginTop: 16,
    },
    heading4: {
      color: theme.colors.text,
      fontSize: 16,
      fontWeight: '600' as const,
      marginBottom: 8,
      marginTop: 12,
    },
    heading5: {
      color: theme.colors.text,
      fontSize: 15,
      fontWeight: '600' as const,
    },
    heading6: {
      color: theme.colors.text,
      fontSize: 14,
      fontWeight: '600' as const,
    },
    strong: {
      fontWeight: '700' as const,
      color: theme.colors.text,
    },
    em: {
      fontStyle: 'italic' as const,
      color: theme.colors.text,
    },
    code_inline: {
      backgroundColor: isDark ? '#2d2d2d' : '#f0f0f0',
      color: isDark ? '#e0e0e0' : '#333',
      fontFamily: 'monospace',
      fontSize: 14,
      paddingHorizontal: 4,
      paddingVertical: 2,
      borderRadius: 4,
    },
    code_block: {
      backgroundColor: isDark ? '#1e1e1e' : '#f5f5f5',
      color: isDark ? '#d4d4d4' : '#333',
      fontFamily: 'monospace',
      fontSize: 14,
      padding: 16,
      borderRadius: 8,
      marginVertical: 12,
    },
    link: {
      color: theme.colors.primary,
      textDecorationLine: 'underline' as const,
    },
    blockquote: {
      backgroundColor: isDark ? '#2d2d2d' : '#f0f0f0',
      borderLeftWidth: 4,
      borderLeftColor: theme.colors.primary,
      paddingLeft: 16,
      paddingVertical: 8,
      marginVertical: 12,
      color: theme.colors.text,
    },
    bullet_list: {
      marginVertical: 8,
    },
    ordered_list: {
      marginVertical: 8,
    },
    list_item: {
      marginVertical: 4,
    },
    paragraph: {
      marginVertical: 8,
    },
  };

  // Custom render rules for wiki links
  const renderRules = {
    link: (node: any, children: any, parent: any, styles: any) => {
      const { href } = node.attributes;
      
      // Check if it's a wiki link
      if (href && href.startsWith('synapse://wikilink/')) {
        return (
          <Text
            key={node.key}
            style={{
              color: '#4A90E2', // Distinct blue color for wiki links
              textDecorationLine: 'underline',
              fontWeight: '500',
            }}
          >
            {children}
          </Text>
        );
      }
      
      // Regular link
      return (
        <Text
          key={node.key}
          style={{
            color: theme.colors.primary,
            textDecorationLine: 'underline',
          }}
        >
          {children}
        </Text>
      );
    },
  };

  if (isLoading) {
    return (
      <View testID="editor-container" style={[styles.container, { backgroundColor: theme.colors.background }]}>
        <ActivityIndicator size="large" color={theme.colors.primary} />
      </View>
    );
  }

  const previewContent = parseWikiLinks(content);

  return (
    <SafeAreaView testID="editor-container" style={[styles.container, { backgroundColor: theme.colors.background }]} edges={['top', 'left', 'right']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: theme.colors.border }]}> 
        {/* Hamburger Menu Button */}
        <TouchableOpacity
          style={styles.menuButton}
          onPress={() => navigation.navigate('Home', { openDrawer: true })}
          testID="hamburger-menu-button"
        >
          <MaterialIcons name="menu" size={28} color={theme.colors.text} />
        </TouchableOpacity>
        
        <Text style={[styles.fileName, { color: theme.colors.text }]} numberOfLines={1}>
          {getFileName()}
        </Text>
        
        {hasChanges && (
          <MaterialIcons name="circle" size={12} color={theme.colors.primary} style={styles.unsavedIndicator} />
        )}

        {/* Preview Toggle Button */}
        <TouchableOpacity
          style={styles.previewToggleButton}
          onPress={handleTogglePreview}
          testID="preview-toggle-button"
        >
          <MaterialIcons 
            name={isPreviewMode ? "edit" : "visibility"} 
            size={24} 
            color={theme.colors.text} 
          />
        </TouchableOpacity>
        
        <TouchableOpacity
          testID="save-button"
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
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <MaterialIcons name="save" size={18} color={theme.colors.background} style={{ marginRight: 4 }} />
              <Text style={[styles.saveButtonText, { color: theme.colors.background }]}>
                Save
              </Text>
            </View>
          )}
        </TouchableOpacity>
      </View>

      {/* Error Message */}
      {error && (
        <View style={[styles.errorContainer, { backgroundColor: theme.colors.error + '20' }]}>
          <Text style={[styles.errorText, { color: theme.colors.error }]}>{error}</Text>
        </View>
      )}

      {/* Editor or Preview */}
      <KeyboardAvoidingView 
        style={styles.keyboardAvoidingView}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        {isPreviewMode ? (
          // Preview Mode
          <ScrollView 
            testID="markdown-preview" 
            style={[styles.content, { backgroundColor: theme.colors.card }]}
            contentContainerStyle={styles.previewContent}
          >
            <Markdown 
              style={markdownStyles}
              rules={renderRules}
            >
              {previewContent}
            </Markdown>
          </ScrollView>
        ) : (
          // Edit Mode
          <ScrollView style={styles.content} keyboardShouldPersistTaps="handled">
            <TextInput
              testID="editor-input"
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
              undoEnabled={true}
            />
          </ScrollView>
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  keyboardAvoidingView: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 12,
    borderBottomWidth: 1,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
  },
  menuButton: {
    padding: 4,
    marginRight: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backButton: {
    paddingRight: 12,
    marginRight: 4,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backButtonText: {
    fontSize: 26,
    fontWeight: '500',
    lineHeight: 28,
  },
  fileName: {
    flex: 1,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: -0.3,
  },
  unsavedIndicator: {
    marginRight: 8,
    fontSize: 14,
  },
  previewToggleButton: {
    padding: 8,
    marginRight: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveButton: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 10,
    minWidth: 60,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  saveButtonText: {
    fontSize: 14,
    fontWeight: '700',
    letterSpacing: -0.2,
  },
  errorContainer: {
    padding: 16,
    margin: 16,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(239, 68, 68, 0.3)',
  },
  errorText: {
    fontSize: 14,
    textAlign: 'center',
    fontWeight: '500',
  },
  content: {
    flex: 1,
    padding: 16,
  },
  previewContent: {
    paddingHorizontal: 8,
  },
  editor: {
    flex: 1,
    minHeight: '100%',
    padding: 20,
    borderRadius: 16,
    fontSize: 16,
    lineHeight: 26,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 3,
  },
});
