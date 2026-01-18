import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for secure storage using libsecret (GNOME) or KWallet (KDE)
class SecureStorageService {
  SecureStorageService();

  // Flutter secure storage handles libsecret/KWallet automatically on Linux
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    lOptions: LinuxOptions(
      // Uses libsecret on GNOME, KWallet on KDE
    ),
  );

  static const String _keyPrefix = 'craig_o_clean_';

  /// Read a value from secure storage
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: '$_keyPrefix$key');
    } catch (e) {
      // Fall back to null if secure storage fails
      return null;
    }
  }

  /// Write a value to secure storage
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: '$_keyPrefix$key', value: value);
    } catch (e) {
      // Silently fail if secure storage is not available
    }
  }

  /// Delete a value from secure storage
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: '$_keyPrefix$key');
    } catch (e) {
      // Silently fail
    }
  }

  /// Delete all stored values
  Future<void> deleteAll() async {
    try {
      // Read all keys and delete those with our prefix
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_keyPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: '$_keyPrefix$key');
    } catch (e) {
      return false;
    }
  }

  /// Read all stored key-value pairs
  Future<Map<String, String>> readAll() async {
    try {
      final all = await _storage.readAll();
      final result = <String, String>{};

      for (final entry in all.entries) {
        if (entry.key.startsWith(_keyPrefix)) {
          final cleanKey = entry.key.substring(_keyPrefix.length);
          result[cleanKey] = entry.value;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }
}

/// Extension for LinuxOptions since flutter_secure_storage may not have it
class LinuxOptions {
  const LinuxOptions();
}
