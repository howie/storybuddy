import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for secure storage.
abstract class SecureStorageKeys {
  static const String authToken = 'auth_token';
  static const String parentId = 'parent_id';
  static const String encryptionKey = 'encryption_key';
  static const String refreshToken = 'refresh_token';
}

/// Service for securely storing sensitive data.
/// On macOS development without code signing, falls back to SharedPreferences.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // Use SharedPreferences on macOS for development (no code signing)
  bool get _useFallback => Platform.isMacOS;

  Future<void> _writeFallback(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _readFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _deleteFallback(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _deleteAllFallback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Auth Token

  /// Stores the authentication token.
  Future<void> setAuthToken(String token) async {
    if (_useFallback) {
      await _writeFallback(SecureStorageKeys.authToken, token);
    } else {
      await _storage.write(key: SecureStorageKeys.authToken, value: token);
    }
  }

  /// Retrieves the authentication token.
  Future<String?> getAuthToken() async {
    if (_useFallback) {
      return _readFallback(SecureStorageKeys.authToken);
    }
    return _storage.read(key: SecureStorageKeys.authToken);
  }

  /// Clears the authentication token.
  Future<void> clearAuthToken() async {
    if (_useFallback) {
      await _deleteFallback(SecureStorageKeys.authToken);
    } else {
      await _storage.delete(key: SecureStorageKeys.authToken);
    }
  }

  // Parent ID

  /// Stores the current parent ID.
  Future<void> setParentId(String parentId) async {
    if (_useFallback) {
      await _writeFallback(SecureStorageKeys.parentId, parentId);
    } else {
      await _storage.write(key: SecureStorageKeys.parentId, value: parentId);
    }
  }

  /// Retrieves the current parent ID.
  Future<String?> getParentId() async {
    if (_useFallback) {
      return _readFallback(SecureStorageKeys.parentId);
    }
    return _storage.read(key: SecureStorageKeys.parentId);
  }

  /// Clears the parent ID.
  Future<void> clearParentId() async {
    if (_useFallback) {
      await _deleteFallback(SecureStorageKeys.parentId);
    } else {
      await _storage.delete(key: SecureStorageKeys.parentId);
    }
  }

  // Encryption Key (for audio cache encryption)

  /// Stores the encryption key for audio file encryption.
  Future<void> setEncryptionKey(String key) async {
    if (_useFallback) {
      await _writeFallback(SecureStorageKeys.encryptionKey, key);
    } else {
      await _storage.write(key: SecureStorageKeys.encryptionKey, value: key);
    }
  }

  /// Retrieves the encryption key.
  Future<String?> getEncryptionKey() async {
    if (_useFallback) {
      return _readFallback(SecureStorageKeys.encryptionKey);
    }
    return _storage.read(key: SecureStorageKeys.encryptionKey);
  }

  // Refresh Token

  /// Stores the refresh token.
  Future<void> setRefreshToken(String token) async {
    if (_useFallback) {
      await _writeFallback(SecureStorageKeys.refreshToken, token);
    } else {
      await _storage.write(key: SecureStorageKeys.refreshToken, value: token);
    }
  }

  /// Retrieves the refresh token.
  Future<String?> getRefreshToken() async {
    if (_useFallback) {
      return _readFallback(SecureStorageKeys.refreshToken);
    }
    return _storage.read(key: SecureStorageKeys.refreshToken);
  }

  /// Clears the refresh token.
  Future<void> clearRefreshToken() async {
    if (_useFallback) {
      await _deleteFallback(SecureStorageKeys.refreshToken);
    } else {
      await _storage.delete(key: SecureStorageKeys.refreshToken);
    }
  }

  // Utility Methods

  /// Clears all stored credentials (for logout).
  Future<void> clearAll() async {
    if (_useFallback) {
      await _deleteAllFallback();
    } else {
      await _storage.deleteAll();
    }
  }

  /// Checks if the user has stored credentials.
  Future<bool> hasCredentials() async {
    final token = await getAuthToken();
    final parentId = await getParentId();
    return token != null && parentId != null;
  }
}

/// Provider for the secure storage service.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
