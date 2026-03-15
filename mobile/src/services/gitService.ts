import git from 'isomorphic-git';
import * as FileSystem from 'expo-file-system/legacy';
import AsyncStorage from '@react-native-async-storage/async-storage';

const getDocumentDirectory = () => FileSystem.documentDirectory || 'file:///';

const toExpoUri = (inputPath: string): string => {
  if (!inputPath) {
    return inputPath;
  }

  if (inputPath.startsWith('file:///')) {
    return inputPath;
  }

  if (inputPath.startsWith('file://')) {
    return `file:///${inputPath.slice('file://'.length).replace(/^\/+/, '')}`;
  }

  if (inputPath.startsWith('file:/')) {
    return `file:///${inputPath.slice('file:/'.length).replace(/^\/+/, '')}`;
  }

  if (inputPath.startsWith('/')) {
    return `file://${inputPath}`;
  }

  const docDir = getDocumentDirectory().replace(/\/+$/, '');
  return `${docDir}/${inputPath.replace(/^\/+/, '')}`;
};

const createFsError = (code: string, syscall: string, targetPath: string) => {
  const error = new Error(`${code}: no such file or directory, ${syscall} '${targetPath}'`) as Error & {
    code: string;
    errno: number;
    syscall: string;
    path: string;
  };

  error.code = code;
  error.errno = -2;
  error.syscall = syscall;
  error.path = targetPath;

  return error;
};

const getParentPath = (targetPath: string) => {
  const normalizedPath = targetPath.replace(/\/+$/, '');
  const lastSlashIndex = normalizedPath.lastIndexOf('/');

  if (lastSlashIndex <= 'file:///'.length - 1) {
    return null;
  }

  return normalizedPath.slice(0, lastSlashIndex);
};

const ensureParentDirectory = async (targetPath: string) => {
  const parentPath = getParentPath(targetPath);

  if (!parentPath) {
    return;
  }

  await FileSystem.makeDirectoryAsync(toExpoUri(parentPath), {
    intermediates: true,
  });
};

// Collect an async iterable body into a single Uint8Array
const collectBody = async (
  body?: Iterable<Uint8Array> | AsyncIterable<Uint8Array>
): Promise<Uint8Array> => {
  if (!body) return new Uint8Array(0);
  const chunks: Uint8Array[] = [];
  for await (const chunk of body as AsyncIterable<Uint8Array>) {
    chunks.push(chunk);
  }
  const totalLength = chunks.reduce((n, c) => n + c.byteLength, 0);
  const merged = new Uint8Array(totalLength);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return merged;
};

// Wrap bytes in an async iterable that isomorphic-git's StreamReader can consume.
// isomorphic-git calls Buffer.from(value) on every yielded chunk; the single-arg
// Buffer.from(uint8Array) form is reliably supported in React Native / Hermes.
// We deliberately avoid Buffer.from(arrayBuffer, byteOffset, length) which is
// broken in some React Native Buffer polyfills.
const bytesToAsyncIterable = (bytes: Uint8Array) => {
  const CHUNK = 65536;
  let offset = 0;
  return {
    [Symbol.asyncIterator]() {
      return this;
    },
    async next(): Promise<{ done: boolean; value: Uint8Array | undefined }> {
      if (offset >= bytes.byteLength) {
        return { done: true, value: undefined };
      }
      const end = Math.min(offset + CHUNK, bytes.byteLength);
      // subarray() returns a view into the same owned buffer — no copy needed.
      // We already own `bytes` (it was copied fresh in the http adapter), so
      // this view is safe for as long as the iterator lives.
      const chunk = bytes.subarray(offset, end);
      offset = end;
      return { done: false, value: chunk };
    },
    async return(): Promise<{ done: boolean; value: undefined }> {
      offset = bytes.byteLength;
      return { done: true, value: undefined };
    },
  };
};

const http = {
  async request({
    url,
    method = 'GET',
    headers = {},
    body,
  }: {
    url: string;
    method?: string;
    headers?: Record<string, string>;
    body?: Iterable<Uint8Array> | AsyncIterable<Uint8Array>;
  }) {
    // Materialise request body before sending (streaming POST not supported in RN fetch)
    const requestBytes = await collectBody(body);
    const requestBody = requestBytes.byteLength > 0 ? requestBytes : undefined;

    const response = await fetch(url, { method, headers, body: requestBody });

    const responseHeaders: Record<string, string> = {};
    response.headers.forEach((v: string, k: string) => {
      responseHeaders[k] = v;
    });

    const arrayBuf = await response.arrayBuffer();

    // Copy bytes into a brand-new ArrayBuffer that is fully owned by us.
    // Hermes may return a neutered/transferred ArrayBuffer from fetch's
    // arrayBuffer() call; wrapping it in a fresh copy prevents Buffer.from()
    // inside isomorphic-git's StreamReader from throwing on a detached buffer.
    const srcBytes = new Uint8Array(arrayBuf);
    const bodyBytes = new Uint8Array(srcBytes.byteLength);
    bodyBytes.set(srcBytes);

    console.log('[git-http]', method, url, '->', response.status,
      'body bytes:', bodyBytes.byteLength,
      'ct:', responseHeaders['content-type']);

    return {
      url: response.url || url,
      method,
      statusCode: response.status,
      statusMessage: response.statusText,
      headers: responseHeaders,
      body: bytesToAsyncIterable(bodyBytes),
    };
  },
};

// Node.js fs-compatible adapter for expo-file-system
// This allows isomorphic-git to work with Expo's FileSystem API
const fs = {
  promises: {
    async readFile(filepath: string, options?: { encoding?: string }): Promise<string | Uint8Array> {
      const content = await FileSystem.readAsStringAsync(toExpoUri(filepath), {
        encoding: FileSystem.EncodingType.UTF8,
      });
      return options?.encoding === 'utf8' ? content : new TextEncoder().encode(content);
    },

    async writeFile(filepath: string, data: string | Uint8Array, options?: { encoding?: string }): Promise<void> {
      let content: string;
      if (data instanceof Uint8Array) {
        content = new TextDecoder().decode(data);
      } else {
        content = data;
      }
      await ensureParentDirectory(filepath);
      await FileSystem.writeAsStringAsync(toExpoUri(filepath), content, {
        encoding: FileSystem.EncodingType.UTF8,
      });
    },

    async mkdir(dirpath: string, options?: { recursive?: boolean }): Promise<void> {
      await FileSystem.makeDirectoryAsync(toExpoUri(dirpath), {
        intermediates: options?.recursive ?? false 
      });
    },

    async rmdir(dirpath: string): Promise<void> {
      await FileSystem.deleteAsync(toExpoUri(dirpath), { idempotent: true });
    },

    async readdir(dirpath: string): Promise<string[]> {
      return await FileSystem.readDirectoryAsync(toExpoUri(dirpath));
    },

    async unlink(filepath: string): Promise<void> {
      await FileSystem.deleteAsync(toExpoUri(filepath), { idempotent: true });
    },

    async rename(oldpath: string, newpath: string): Promise<void> {
      // Expo doesn't have a direct rename, so we copy and delete
      await ensureParentDirectory(newpath);
      await FileSystem.copyAsync({ from: toExpoUri(oldpath), to: toExpoUri(newpath) });
      await FileSystem.deleteAsync(toExpoUri(oldpath), { idempotent: true });
    },

    async stat(filepath: string): Promise<{
      type: string;
      mode: number;
      size: number;
      ino: number;
      mtimeMs: number;
      ctimeMs: number;
      uid: number;
      gid: number;
      dev: number;
      isFile: () => boolean;
      isDirectory: () => boolean;
      isSymbolicLink: () => boolean;
    }> {
      const info = await FileSystem.getInfoAsync(toExpoUri(filepath));
      if (!info.exists) {
        throw createFsError('ENOENT', 'stat', filepath);
      }
      
      const size = info.size || 0;
      const mtimeMs = info.modificationTime ? info.modificationTime * 1000 : Date.now();
      
      return {
        type: info.isDirectory ? 'directory' : 'file',
        mode: 0o644,
        size,
        ino: 0,
        mtimeMs,
        ctimeMs: mtimeMs,
        uid: 0,
        gid: 0,
        dev: 0,
        isFile: () => !info.isDirectory,
        isDirectory: () => info.isDirectory,
        isSymbolicLink: () => false,
      };
    },

    async lstat(filepath: string): Promise<ReturnType<typeof fs.promises.stat>> {
      return await fs.promises.stat(filepath);
    },

    symlink(): never {
      throw new Error('Symlinks not supported in Expo FileSystem');
    },

    readlink(): never {
      throw new Error('Symlinks not supported in Expo FileSystem');
    },
  },
};

export enum GitErrorType {
  AUTH_FAILURE = 'AUTH_FAILURE',
  NETWORK_ERROR = 'NETWORK_ERROR',
  CONFLICT = 'CONFLICT',
  NOT_A_REPOSITORY = 'NOT_A_REPOSITORY',
  UNKNOWN = 'UNKNOWN',
}

export class GitError extends Error {
  type: GitErrorType;
  originalError?: Error;

  constructor(message: string, type: GitErrorType, originalError?: Error) {
    super(message);
    this.name = 'GitError';
    this.type = type;
    this.originalError = originalError;
  }
}

interface GitCredentials {
  username: string;
  token: string;
}

interface CredentialsMap {
  [repoUrl: string]: GitCredentials;
}

interface StatusResult {
  modified: string[];
  deleted: string[];
  added: string[];
  hasChanges: boolean;
}

interface SyncResult {
  pulled: boolean;
  committed: string | null;
  pushed: boolean;
}

const CREDENTIALS_KEY = 'git_credentials';

function getGitErrorType(error: Error): GitErrorType {
  const message = error.message.toLowerCase();
  
  if (message.includes('401') || message.includes('unauthorized') || message.includes('auth')) {
    return GitErrorType.AUTH_FAILURE;
  }
  if (message.includes('network') || message.includes('fetch') || message.includes('connection')) {
    return GitErrorType.NETWORK_ERROR;
  }
  if (message.includes('conflict') || message.includes('merge')) {
    return GitErrorType.CONFLICT;
  }
  if (message.includes('not a git repository')) {
    return GitErrorType.NOT_A_REPOSITORY;
  }
  
  return GitErrorType.UNKNOWN;
}

export class GitService {
  private static instance: GitService | null = null;

  private constructor() {}

  static getInstance(): GitService {
    if (!GitService.instance) {
      GitService.instance = new GitService();
    }
    return GitService.instance;
  }

  static clearInstance(): void {
    GitService.instance = null;
  }

  private static async getAuthCallback(url: string): Promise<git.AuthCallback | undefined> {
    const credentials = await GitService.getCredentials(url);
    if (!credentials) {
      return undefined;
    }

    return () => ({
      username: credentials.username,
      password: credentials.token,
    });
  }

  private handleError(error: Error, operation: string): never {
    const errorType = getGitErrorType(error);
    const message = `${operation} failed: ${error.message}`;
    throw new GitError(message, errorType, error);
  }

  // Authentication Methods
  static async setCredentials(repoUrl: string, username: string, token: string): Promise<void> {
    const existingData = await AsyncStorage.getItem(CREDENTIALS_KEY);
    const credentials: CredentialsMap = existingData ? JSON.parse(existingData) : {};
    
    credentials[repoUrl] = { username, token };
    
    await AsyncStorage.setItem(CREDENTIALS_KEY, JSON.stringify(credentials));
  }

  static async getCredentials(repoUrl: string): Promise<GitCredentials | null> {
    const data = await AsyncStorage.getItem(CREDENTIALS_KEY);
    if (!data) {
      return null;
    }

    const credentials: CredentialsMap = JSON.parse(data);
    return credentials[repoUrl] || null;
  }

  static async clearCredentials(): Promise<void> {
    await AsyncStorage.removeItem(CREDENTIALS_KEY);
  }

  // Git Operations
  async clone(
    url: string,
    dir: string,
    onProgress?: git.ProgressCallback
  ): Promise<void> {
    try {
      await git.clone({
        fs,
        http,
        dir,
        url,
        onProgress,
        singleBranch: true,
        depth: 1,
        onAuth: await GitService.getAuthCallback(url),
      });
    } catch (error) {
      const err = error as any;
      console.log('[clone-error] message:', err?.message);
      console.log('[clone-error] caller:', err?.caller);
      console.log('[clone-error] stack:', err?.stack?.split('\n').slice(0, 8).join('\n'));
      this.handleError(err as Error, 'Clone');
    }
  }

  async pull(dir: string): Promise<void> {
    try {
      const remoteUrl = await this.getRemoteUrl(dir);
      
      await git.pull({
        fs,
        http,
        dir,
        fastForwardOnly: false,
        singleBranch: true,
        onAuth: await GitService.getAuthCallback(remoteUrl),
      });
    } catch (error) {
      this.handleError(error as Error, 'Pull');
    }
  }

  async commit(dir: string): Promise<string | null> {
    try {
      const status = await git.statusMatrix({ fs, dir });
      
      let hasChanges = false;
      const modifiedFiles: string[] = [];
      const deletedFiles: string[] = [];
      
      for (const [filepath, headStatus, workdirStatus, stageStatus] of status) {
        if (workdirStatus !== stageStatus) {
          hasChanges = true;
          
          if (workdirStatus === 0) {
            deletedFiles.push(filepath);
            await git.remove({ fs, dir, filepath });
          } else {
            modifiedFiles.push(filepath);
            await git.add({ fs, dir, filepath });
          }
        }
      }
      
      if (!hasChanges) {
        return null;
      }
      
      const timestamp = new Date().toISOString();
      const message = `Synapse mobile sync — ${timestamp}`;
      
      const sha = await git.commit({
        fs,
        dir,
        message,
        author: {
          name: 'Synapse Mobile',
          email: 'mobile@synapse.local',
        },
      });
      
      return sha;
    } catch (error) {
      this.handleError(error as Error, 'Commit');
    }
  }

  async push(dir: string): Promise<void> {
    try {
      const remoteUrl = await this.getRemoteUrl(dir);
      const currentBranch = await git.currentBranch({ fs, dir, fullname: false });
      
      await git.push({
        fs,
        http,
        dir,
        remote: 'origin',
        ref: currentBranch || 'main',
        onAuth: await GitService.getAuthCallback(remoteUrl),
      });
    } catch (error) {
      this.handleError(error as Error, 'Push');
    }
  }

  async sync(dir: string): Promise<SyncResult> {
    let pulled = false;
    let committed: string | null = null;
    let pushed = false;
    
    try {
      await this.pull(dir);
      pulled = true;
    } catch (error) {
      console.warn('Pull failed during sync:', error);
    }
    
    committed = await this.commit(dir);
    
    if (committed) {
      try {
        await this.push(dir);
        pushed = true;
      } catch (error) {
        console.warn('Push failed during sync:', error);
      }
    }
    
    return { pulled, committed, pushed };
  }

  // Helper Methods
  async getStatus(dir: string): Promise<StatusResult> {
    try {
      const status = await git.statusMatrix({ fs, dir });
      
      const modified: string[] = [];
      const deleted: string[] = [];
      const added: string[] = [];
      
      for (const [filepath, headStatus, workdirStatus, stageStatus] of status) {
        if (workdirStatus !== stageStatus) {
          if (headStatus === 0) {
            added.push(filepath);
          } else if (workdirStatus === 0) {
            deleted.push(filepath);
          } else {
            modified.push(filepath);
          }
        }
      }
      
      return {
        modified,
        deleted,
        added,
        hasChanges: modified.length > 0 || deleted.length > 0 || added.length > 0,
      };
    } catch (error) {
      this.handleError(error as Error, 'Get status');
    }
  }

  async hasChanges(dir: string): Promise<boolean> {
    const status = await this.getStatus(dir);
    return status.hasChanges;
  }

  async isRepository(dir: string): Promise<boolean> {
    try {
      await git.currentBranch({ fs, dir, fullname: false });
      return true;
    } catch {
      return false;
    }
  }

  private async getRemoteUrl(dir: string): Promise<string> {
    try {
      const remote = await git.getConfig({ fs, dir, path: 'remote.origin.url' });
      return remote?.value || '';
    } catch {
      return '';
    }
  }

  // Static wrappers for convenience
  static async clone(
    url: string,
    dir: string,
    onProgress?: git.ProgressCallback
  ): Promise<void> {
    return GitService.getInstance().clone(url, dir, onProgress);
  }

  static async pull(dir: string): Promise<void> {
    return GitService.getInstance().pull(dir);
  }

  static async commit(dir: string): Promise<string | null> {
    return GitService.getInstance().commit(dir);
  }

  static async push(dir: string): Promise<void> {
    return GitService.getInstance().push(dir);
  }

  static async sync(dir: string): Promise<SyncResult> {
    return GitService.getInstance().sync(dir);
  }

  static async getStatus(dir: string): Promise<StatusResult> {
    return GitService.getInstance().getStatus(dir);
  }

  static async hasChanges(dir: string): Promise<boolean> {
    return GitService.getInstance().hasChanges(dir);
  }

  static async isRepository(dir: string): Promise<boolean> {
    return GitService.getInstance().isRepository(dir);
  }
}
