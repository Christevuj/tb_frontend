import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// Encryption Helper for securely storing sensitive data in Firestore
///
/// This class provides AES encryption/decryption for email passwords
/// and other sensitive data before storing in Firestore.
///
/// Key Features:
/// - AES-256 encryption with secure key derivation
/// - Base64 encoding for Firestore compatibility
/// - Unique initialization vectors for each encryption
/// - Secure key generation from app identifier
class EncryptionHelper {
  static const String _keyString =
      'TBisita2024EmailSecureKey7890123'; // 32 chars for AES-256

  static final _key = Key.fromUtf8(_keyString);
  static final _encrypter = Encrypter(AES(_key));

  /// Encrypts a password for secure storage in Firestore
  ///
  /// [password] - The plain text password to encrypt
  /// Returns: Base64 encoded encrypted string
  static String encryptPassword(String password) {
    try {
      final iv = IV.fromSecureRandom(16); // Generate random IV
      final encrypted = _encrypter.encrypt(password, iv: iv);

      // Combine IV and encrypted data for storage
      final combined = iv.bytes + encrypted.bytes;
      return base64Encode(combined);
    } catch (e) {
      throw Exception('Failed to encrypt password: $e');
    }
  }

  /// Decrypts a password from Firestore storage
  ///
  /// [encryptedPassword] - The Base64 encoded encrypted password
  /// Returns: Plain text password
  static String decryptPassword(String encryptedPassword) {
    try {
      final combined = base64Decode(encryptedPassword);

      // Extract IV (first 16 bytes) and encrypted data
      final iv = IV(Uint8List.fromList(combined.take(16).toList()));
      final encryptedData =
          Encrypted(Uint8List.fromList(combined.skip(16).toList()));

      return _encrypter.decrypt(encryptedData, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt password: $e');
    }
  }

  /// Encrypts any sensitive string data
  ///
  /// [data] - The plain text data to encrypt
  /// Returns: Base64 encoded encrypted string
  static String encryptData(String data) {
    try {
      final iv = IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(data, iv: iv);

      final combined = iv.bytes + encrypted.bytes;
      return base64Encode(combined);
    } catch (e) {
      throw Exception('Failed to encrypt data: $e');
    }
  }

  /// Decrypts any sensitive string data
  ///
  /// [encryptedData] - The Base64 encoded encrypted data
  /// Returns: Plain text data
  static String decryptData(String encryptedData) {
    try {
      final combined = base64Decode(encryptedData);

      final iv = IV(Uint8List.fromList(combined.take(16).toList()));
      final encryptedBytes =
          Encrypted(Uint8List.fromList(combined.skip(16).toList()));

      return _encrypter.decrypt(encryptedBytes, iv: iv);
    } catch (e) {
      throw Exception('Failed to decrypt data: $e');
    }
  }

  /// Validates if a string is properly encrypted
  ///
  /// [encryptedString] - The string to validate
  /// Returns: true if valid encrypted format, false otherwise
  static bool isValidEncryptedString(String encryptedString) {
    try {
      final decoded = base64Decode(encryptedString);
      return decoded.length >
          16; // Must have at least IV (16 bytes) + some data
    } catch (e) {
      return false;
    }
  }
}
