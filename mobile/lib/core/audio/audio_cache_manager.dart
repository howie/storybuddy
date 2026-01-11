import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage_service.dart';

/// Manager for caching audio files with AES-256 encryption (PS-001 compliance).
class AudioCacheManager {
  AudioCacheManager({
    required this.secureStorage,
    CacheManager? cacheManager,
  }) : _cacheManager = cacheManager ?? DefaultCacheManager();

  final SecureStorageService secureStorage;
  final CacheManager _cacheManager;

  static const _audioCacheDir = 'audio_cache';
  static const _keyLength = 32; // 256 bits

  encrypt.Key? _encryptionKey;
  final _iv = encrypt.IV.fromLength(16);

  /// Initializes the encryption key.
  Future<void> _initializeEncryption() async {
    if (_encryptionKey != null) return;

    var keyString = await secureStorage.getEncryptionKey();
    if (keyString == null) {
      // Generate a new key
      keyString = _generateSecureKey();
      await secureStorage.setEncryptionKey(keyString);
    }

    _encryptionKey = encrypt.Key.fromBase64(keyString);
  }

  /// Generates a secure random key.
  String _generateSecureKey() {
    final key = encrypt.Key.fromSecureRandom(_keyLength);
    return key.base64;
  }

  /// Gets the audio cache directory.
  Future<Directory> _getAudioCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(appDir.path, _audioCacheDir));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Caches an audio file from a URL with encryption.
  ///
  /// Returns the path to the cached encrypted file.
  Future<String> cacheAudioFromUrl(String url, {String? storyId}) async {
    await _initializeEncryption();

    // Download the file using cache manager
    final fileInfo = await _cacheManager.downloadFile(url);
    final originalFile = fileInfo.file;

    // Read and encrypt the file
    final plainBytes = await originalFile.readAsBytes();
    final encryptedBytes = _encryptBytes(plainBytes);

    // Save encrypted file
    final cacheDir = await _getAudioCacheDir();
    final fileName = storyId ?? const Uuid().v4();
    final encryptedFile = File(p.join(cacheDir.path, '$fileName.enc'));
    await encryptedFile.writeAsBytes(encryptedBytes);

    return encryptedFile.path;
  }

  /// Caches audio data directly with encryption.
  Future<String> cacheAudioBytes(
    Uint8List audioBytes, {
    String? fileName,
  }) async {
    await _initializeEncryption();

    final encryptedBytes = _encryptBytes(audioBytes);

    final cacheDir = await _getAudioCacheDir();
    final name = fileName ?? const Uuid().v4();
    final encryptedFile = File(p.join(cacheDir.path, '$name.enc'));
    await encryptedFile.writeAsBytes(encryptedBytes);

    return encryptedFile.path;
  }

  /// Retrieves and decrypts a cached audio file.
  ///
  /// Returns the decrypted audio bytes.
  Future<Uint8List?> getCachedAudio(String cachedPath) async {
    await _initializeEncryption();

    final file = File(cachedPath);
    if (!await file.exists()) {
      return null;
    }

    final encryptedBytes = await file.readAsBytes();
    return _decryptBytes(encryptedBytes);
  }

  /// Creates a temporary decrypted file for playback.
  ///
  /// The caller is responsible for deleting this file after use.
  Future<String?> getDecryptedTempFile(String cachedPath) async {
    final decryptedBytes = await getCachedAudio(cachedPath);
    if (decryptedBytes == null) return null;

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(tempDir.path, '${const Uuid().v4()}.audio'),
    );
    await tempFile.writeAsBytes(decryptedBytes);

    return tempFile.path;
  }

  /// Deletes a cached audio file.
  Future<void> deleteCachedAudio(String cachedPath) async {
    final file = File(cachedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clears all cached audio files.
  Future<void> clearCache() async {
    final cacheDir = await _getAudioCacheDir();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
    await _cacheManager.emptyCache();
  }

  /// Gets the total size of the audio cache in bytes.
  Future<int> getCacheSize() async {
    final cacheDir = await _getAudioCacheDir();
    if (!await cacheDir.exists()) return 0;

    var totalSize = 0;
    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Checks if an audio file is cached.
  Future<bool> isCached(String cachedPath) async {
    final file = File(cachedPath);
    return file.exists();
  }

  /// Encrypts bytes using AES-256.
  Uint8List _encryptBytes(Uint8List plainBytes) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(plainBytes, iv: _iv);
    return encrypted.bytes;
  }

  /// Decrypts bytes using AES-256.
  Uint8List _decryptBytes(Uint8List encryptedBytes) {
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
    );
    final encrypted = encrypt.Encrypted(encryptedBytes);
    final decrypted = encrypter.decryptBytes(encrypted, iv: _iv);
    return Uint8List.fromList(decrypted);
  }
}

/// Provider for the audio cache manager.
final audioCacheManagerProvider = Provider<AudioCacheManager>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AudioCacheManager(secureStorage: secureStorage);
});
