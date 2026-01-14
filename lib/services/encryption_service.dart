import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cached public key with expiry time
class CachedPublicKey {
  final SimplePublicKey key;
  final String keyBase64;
  final DateTime cachedAt;
  static const Duration ttl = Duration(hours: 24);
  
  CachedPublicKey(this.key, this.keyBase64) : cachedAt = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// Service for End-to-End Encryption using X25519 key exchange and AES-GCM encryption.
/// 
/// Features:
/// - Automatic key pair generation and secure storage
/// - Public key caching with 24-hour TTL
/// - Graceful fallback to plaintext on encryption failure
/// - Support for both private and group messages
class EncryptionService {
  static const String _privateKeyStorageKey = 'e2e_private_key';
  static const String _publicKeyStorageKey = 'e2e_public_key';
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  final _keyExchangeAlgorithm = X25519();
  final _cipher = AesGcm.with256bits();
  
  SimpleKeyPair? _keyPair;
  bool _isInitialized = false;
  
  // Enhanced cache with TTL support
  final Map<String, CachedPublicKey> _publicKeyCache = {};
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if we have a valid key pair
  bool get hasKeyPair => _keyPair != null;
  
  /// Initialize the service - load existing keys or generate new ones
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent double initialization
    
    try {
      final privateKeyBase64 = await _storage.read(key: _privateKeyStorageKey);
      final publicKeyBase64 = await _storage.read(key: _publicKeyStorageKey);
      
      if (privateKeyBase64 != null && publicKeyBase64 != null) {
        final privateKeyBytes = base64Decode(privateKeyBase64);
        final publicKeyBytes = base64Decode(publicKeyBase64);
        
        _keyPair = SimpleKeyPairData(
          privateKeyBytes, 
          publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
        
        _isInitialized = true;
        if (kDebugMode) print('E2E: Loaded existing key pair');
      } else {
        await generateKeyPair();
      }
    } catch (e) {
      if (kDebugMode) print('E2E: Error loading keys, generating new pair: $e');
      await generateKeyPair();
    }
  }
  
  /// Generate a new key pair and store it securely
  Future<void> generateKeyPair() async {
    try {
      final keyPair = await _keyExchangeAlgorithm.newKeyPair();
      _keyPair = keyPair;
      
      final privateKeyData = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      
      await _storage.write(
        key: _privateKeyStorageKey, 
        value: base64Encode(privateKeyData),
      );
      await _storage.write(
        key: _publicKeyStorageKey, 
        value: base64Encode(publicKey.bytes),
      );
      
      _isInitialized = true;
      if (kDebugMode) print('E2E: Generated and stored new key pair');
    } catch (e) {
      if (kDebugMode) print('E2E: Failed to generate key pair: $e');
      rethrow;
    }
  }
  
  /// Get the current user's public key as base64 string
  Future<String?> getMyPublicKey() async {
    if (_keyPair == null) return null;
    try {
      final publicKey = await _keyPair!.extractPublicKey();
      return base64Encode(publicKey.bytes);
    } catch (e) {
      if (kDebugMode) print('E2E: Failed to extract public key: $e');
      return null;
    }
  }
  
  /// Cache a user's public key with automatic TTL management
  void cachePublicKey(String userId, String publicKeyBase64) {
    if (userId.isEmpty || publicKeyBase64.isEmpty) return;
    
    try {
      final bytes = base64Decode(publicKeyBase64);
      final key = SimplePublicKey(bytes, type: KeyPairType.x25519);
      _publicKeyCache[userId] = CachedPublicKey(key, publicKeyBase64);
    } catch (e) {
      if (kDebugMode) print('E2E: Failed to cache public key for $userId: $e');
    }
  }
  
  /// Get cached public key for a user (returns null if expired)
  String? getCachedPublicKeyBase64(String userId) {
    final cached = _publicKeyCache[userId];
    if (cached == null) return null;
    
    if (cached.isExpired) {
      _publicKeyCache.remove(userId);
      return null;
    }
    
    return cached.keyBase64;
  }
  
  /// Get cached SimplePublicKey for a user
  SimplePublicKey? getCachedPublicKey(String userId) {
    final cached = _publicKeyCache[userId];
    if (cached == null || cached.isExpired) {
      if (cached?.isExpired == true) _publicKeyCache.remove(userId);
      return null;
    }
    return cached.key;
  }
  
  /// Batch cache public keys
  void cacheBulkPublicKeys(Map<String, String> publicKeys) {
    for (final entry in publicKeys.entries) {
      cachePublicKey(entry.key, entry.value);
    }
  }
  
  /// Clear expired keys from cache
  void cleanupExpiredKeys() {
    _publicKeyCache.removeWhere((_, cached) => cached.isExpired);
  }
  
  /// Clear the entire key cache
  void clearCache() {
    _publicKeyCache.clear();
  }
  
  /// Encrypt a message for a specific recipient
  /// Returns a base64-encoded encrypted package containing: nonce + ciphertext + mac
  Future<String?> encrypt(String plaintext, String recipientPublicKeyBase64) async {
    if (_keyPair == null) {
      if (kDebugMode) print('E2E: Cannot encrypt - no key pair');
      return null;
    }
    
    if (plaintext.isEmpty || recipientPublicKeyBase64.isEmpty) {
      return null;
    }
    
    try {
      // Parse recipient's public key
      final recipientPublicKey = SimplePublicKey(
        base64Decode(recipientPublicKeyBase64),
        type: KeyPairType.x25519,
      );
      
      // Derive shared secret using X25519
      final sharedSecretKey = await _keyExchangeAlgorithm.sharedSecretKey(
        keyPair: _keyPair!,
        remotePublicKey: recipientPublicKey,
      );
      
      // Derive AES key from shared secret using HKDF
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final derivedKey = await hkdf.deriveKey(
        secretKey: sharedSecretKey,
        nonce: utf8.encode('chatty-e2e-v1'),
      );
      
      // Encrypt with AES-GCM
      final plaintextBytes = utf8.encode(plaintext);
      final secretBox = await _cipher.encrypt(
        plaintextBytes,
        secretKey: derivedKey,
      );
      
      // Package: nonce (12 bytes) + ciphertext + mac (16 bytes)
      final package = Uint8List(secretBox.nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length);
      package.setRange(0, secretBox.nonce.length, secretBox.nonce);
      package.setRange(secretBox.nonce.length, secretBox.nonce.length + secretBox.cipherText.length, secretBox.cipherText);
      package.setRange(secretBox.nonce.length + secretBox.cipherText.length, package.length, secretBox.mac.bytes);
      
      return base64Encode(package);
    } catch (e) {
      if (kDebugMode) print('E2E: Encryption failed: $e');
      return null;
    }
  }
  
  /// Decrypt a message from a specific sender
  Future<String?> decrypt(String encryptedBase64, String senderPublicKeyBase64) async {
    if (_keyPair == null) {
      if (kDebugMode) print('E2E: Cannot decrypt - no key pair');
      return null;
    }
    
    if (encryptedBase64.isEmpty || senderPublicKeyBase64.isEmpty) {
      return null;
    }
    
    try {
      // Parse sender's public key
      final senderPublicKey = SimplePublicKey(
        base64Decode(senderPublicKeyBase64),
        type: KeyPairType.x25519,
      );
      
      // Derive shared secret using X25519
      final sharedSecretKey = await _keyExchangeAlgorithm.sharedSecretKey(
        keyPair: _keyPair!,
        remotePublicKey: senderPublicKey,
      );
      
      // Derive AES key from shared secret using HKDF
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final derivedKey = await hkdf.deriveKey(
        secretKey: sharedSecretKey,
        nonce: utf8.encode('chatty-e2e-v1'),
      );
      
      // Unpack: nonce (12 bytes) + ciphertext + mac (16 bytes)
      final package = base64Decode(encryptedBase64);
      const nonceLength = 12;
      const macLength = 16;
      
      if (package.length < nonceLength + macLength + 1) {
        throw Exception('Invalid encrypted package length');
      }
      
      final nonce = package.sublist(0, nonceLength);
      final cipherText = package.sublist(nonceLength, package.length - macLength);
      final mac = Mac(package.sublist(package.length - macLength));
      
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      
      // Decrypt with AES-GCM
      final plaintextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: derivedKey,
      );
      
      return utf8.decode(plaintextBytes);
    } catch (e) {
      if (kDebugMode) print('E2E: Decryption failed: $e');
      return null;
    }
  }
  
  /// Clear keys on logout
  Future<void> clearKeys() async {
    _keyPair = null;
    _isInitialized = false;
    _publicKeyCache.clear();
    
    try {
      await _storage.delete(key: _privateKeyStorageKey);
      await _storage.delete(key: _publicKeyStorageKey);
      if (kDebugMode) print('E2E: Cleared all keys');
    } catch (e) {
      if (kDebugMode) print('E2E: Error clearing keys: $e');
    }
  }
}
