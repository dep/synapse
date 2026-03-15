import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  Animated,
  Dimensions,
  ScrollView,
  TextInput,
} from 'react-native';
import { useTheme } from '../theme/ThemeContext';
import { FileSystemService, FileNode } from '../services/FileSystemService';

interface FileDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  onFileSelect: (path: string) => void;
  onNewNote: () => void;
  vaultPath: string;
  activeFilePath?: string;
}

type ViewMode = 'tree' | 'flat';

export function FileDrawer({
  isOpen: initialIsOpen,
  onClose,
  onFileSelect,
  onNewNote,
  vaultPath,
  activeFilePath,
}: FileDrawerProps) {
  const { theme } = useTheme();
  const [isOpen, setIsOpen] = useState(initialIsOpen);
  const [viewMode, setViewMode] = useState<ViewMode>('tree');
  const [files, setFiles] = useState<FileNode[]>([]);
  const [flatFiles, setFlatFiles] = useState<FileNode[]>([]);
  const [expandedFolders, setExpandedFolders] = useState<Set<string>>(new Set());
  const [isLoading, setIsLoading] = useState(false);
  const slideAnim = useState(new Animated.Value(-Dimensions.get('window').width * 0.8))[0];

  // Sync with parent isOpen prop
  useEffect(() => {
    setIsOpen(initialIsOpen);
  }, [initialIsOpen]);

  // Animate drawer
  useEffect(() => {
    if (isOpen) {
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 250,
        useNativeDriver: true,
      }).start();
      loadFiles();
    } else {
      Animated.timing(slideAnim, {
        toValue: -Dimensions.get('window').width * 0.8,
        duration: 250,
        useNativeDriver: true,
      }).start();
    }
  }, [isOpen]);

  const loadFiles = useCallback(async () => {
    setIsLoading(true);
    try {
      const treeFiles = await FileSystemService.listFiles(vaultPath);
      const flatFileList = await FileSystemService.getFlatFileList(vaultPath);
      setFiles(treeFiles);
      setFlatFiles(flatFileList);
    } catch (error) {
      console.error('Failed to load files:', error);
    } finally {
      setIsLoading(false);
    }
  }, [vaultPath]);

  const openDrawer = () => {
    setIsOpen(true);
  };

  const closeDrawer = () => {
    setIsOpen(false);
    onClose();
  };

  const handleFileSelect = (path: string) => {
    onFileSelect(path);
    closeDrawer();
  };

  const toggleFolder = (path: string) => {
    setExpandedFolders(prev => {
      const newSet = new Set(prev);
      if (newSet.has(path)) {
        newSet.delete(path);
      } else {
        newSet.add(path);
      }
      return newSet;
    });
  };

  const toggleViewMode = () => {
    setViewMode(prev => (prev === 'tree' ? 'flat' : 'tree'));
  };

  const renderFileItem = (node: FileNode, level: number = 0) => {
    const isActive = node.path === activeFilePath;
    const isExpanded = expandedFolders.has(node.path);

    if (node.isDirectory) {
      return (
        <View key={node.path}>
          <TouchableOpacity
            style={[
              styles.folderItem,
              { paddingLeft: 16 + level * 16 },
            ]}
            onPress={() => toggleFolder(node.path)}
          >
            <Text style={[styles.folderIcon, { color: theme.colors.text }]}>
              {isExpanded ? '📂' : '📁'}
            </Text>
            <Text
              style={[styles.folderName, { color: theme.colors.text }]}
              numberOfLines={1}
            >
              {node.name}
            </Text>
          </TouchableOpacity>
          {isExpanded && node.children && (
            <View>
              {node.children.map(child => renderFileItem(child, level + 1))}
            </View>
          )}
        </View>
      );
    }

    return (
      <TouchableOpacity
        key={node.path}
        style={[
          styles.fileItem,
          { paddingLeft: 16 + level * 16 },
          isActive && { backgroundColor: theme.colors.primary + '20' },
        ]}
        onPress={() => handleFileSelect(node.path)}
        testID={isActive ? 'file-item-active' : undefined}
      >
        <Text style={[styles.fileIcon, { color: theme.colors.text }]}>📝</Text>
        <Text
          style={[
            styles.fileName,
            { color: theme.colors.text },
            isActive && { color: theme.colors.primary, fontWeight: '600' },
          ]}
          numberOfLines={1}
        >
          {node.name}
        </Text>
      </TouchableOpacity>
    );
  };

  const renderFlatList = () => {
    return flatFiles.map(node => (
      <TouchableOpacity
        key={node.path}
        style={[
          styles.fileItem,
          node.path === activeFilePath && { backgroundColor: theme.colors.primary + '20' },
        ]}
        onPress={() => handleFileSelect(node.path)}
        testID={node.path === activeFilePath ? 'file-item-active' : undefined}
      >
        <Text style={[styles.fileIcon, { color: theme.colors.text }]}>📝</Text>
        <Text
          style={[
            styles.fileName,
            { color: theme.colors.text },
            node.path === activeFilePath && { color: theme.colors.primary, fontWeight: '600' },
          ]}
          numberOfLines={1}
        >
          {node.name}
        </Text>
      </TouchableOpacity>
    ));
  };

  return (
    <>
      {/* Hamburger Button */}
      <TouchableOpacity
        style={styles.hamburgerButton}
        onPress={openDrawer}
        testID="hamburger-button"
      >
        <View style={styles.hamburgerIcon}>
          <View style={[styles.hamburgerLine, { backgroundColor: theme.colors.text }]} />
          <View style={[styles.hamburgerLine, { backgroundColor: theme.colors.text }]} />
          <View style={[styles.hamburgerLine, { backgroundColor: theme.colors.text }]} />
        </View>
      </TouchableOpacity>

      {/* Drawer Modal */}
      <Modal
        visible={isOpen}
        transparent={true}
        animationType="none"
        onRequestClose={closeDrawer}
      >
        <View style={styles.modalContainer}>
          {/* Overlay */}
          <TouchableOpacity
            style={styles.overlay}
            onPress={closeDrawer}
            testID="drawer-overlay"
          />

          {/* Drawer Content */}
          <Animated.View
            style={[
              styles.drawer,
              {
                backgroundColor: theme.colors.card,
                transform: [{ translateX: slideAnim }],
              },
            ]}
            testID="file-drawer"
          >
            {/* Header */}
            <View style={[styles.header, { borderBottomColor: theme.colors.border }]}>
              <Text style={[styles.headerTitle, { color: theme.colors.text }]}>
                Files
              </Text>
              <View style={styles.headerButtons}>
                <TouchableOpacity
                  style={styles.viewToggleButton}
                  onPress={toggleViewMode}
                  testID="view-toggle-button"
                >
                  <Text style={[styles.viewToggleText, { color: theme.colors.primary }]}>
                    {viewMode === 'tree' ? '📂' : '📋'}
                  </Text>
                </TouchableOpacity>
              </View>
            </View>

            {/* New Note Button */}
            <TouchableOpacity
              style={[styles.newNoteButton, { backgroundColor: theme.colors.primary }]}
              onPress={onNewNote}
              testID="new-note-button"
            >
              <Text style={[styles.newNoteText, { color: theme.colors.background }]}>
                + New Note
              </Text>
            </TouchableOpacity>

            {/* File List */}
            <ScrollView style={styles.fileList}>
              {isLoading ? (
                <Text style={[styles.loadingText, { color: theme.colors.text }]}>
                  Loading...
                </Text>
              ) : viewMode === 'tree' ? (
                files.map(node => renderFileItem(node))
              ) : (
                renderFlatList()
              )}
            </ScrollView>
          </Animated.View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  hamburgerButton: {
    padding: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  hamburgerIcon: {
    width: 24,
    height: 18,
    justifyContent: 'space-between',
  },
  hamburgerLine: {
    height: 2,
    borderRadius: 1,
    width: '100%',
  },
  modalContainer: {
    flex: 1,
    flexDirection: 'row',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  drawer: {
    width: Dimensions.get('window').width * 0.8,
    height: '100%',
    shadowColor: '#000',
    shadowOffset: { width: 2, height: 0 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 5,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  headerButtons: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  viewToggleButton: {
    padding: 8,
  },
  viewToggleText: {
    fontSize: 20,
  },
  newNoteButton: {
    margin: 16,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  newNoteText: {
    fontSize: 16,
    fontWeight: '600',
  },
  fileList: {
    flex: 1,
  },
  folderItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingRight: 16,
  },
  folderIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  folderName: {
    fontSize: 15,
    fontWeight: '500',
  },
  fileItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 10,
    paddingRight: 16,
  },
  fileIcon: {
    fontSize: 16,
    marginRight: 8,
  },
  fileName: {
    fontSize: 15,
  },
  loadingText: {
    textAlign: 'center',
    padding: 20,
    fontSize: 16,
  },
});
