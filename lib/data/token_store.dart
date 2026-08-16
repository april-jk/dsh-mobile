import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readEmail();
  Future<void> write(AuthTokens tokens, {required String email});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'dsh_access_token';
  static const _refreshKey = 'dsh_refresh_token';
  static const _emailKey = 'dsh_account_email';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readEmail() => _storage.read(key: _emailKey);

  @override
  Future<void> write(AuthTokens tokens, {required String email}) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: tokens.accessToken),
      _storage.write(key: _refreshKey, value: tokens.refreshToken),
      _storage.write(key: _emailKey, value: email),
    ]);
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}

class MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;
  String? email;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    email = null;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> write(AuthTokens tokens, {required String email}) async {
    accessToken = tokens.accessToken;
    refreshToken = tokens.refreshToken;
    this.email = email;
  }
}
