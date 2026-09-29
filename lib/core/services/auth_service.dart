import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the login so Back, refresh, and the next app launch stay signed in.
///
/// SharedPreferences is the source of truth. Secure storage is a second copy
/// for Android; on web and some TV boxes that store throws and used to drop
/// the session.
class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _usernameKey = 'username';
  static const _emailKey = 'user_email';
  static const _displayNameKey = 'display_name';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSession({
    required String token,
    required int userId,
    required String username,
    required String email,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId.toString());
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_displayNameKey, displayName);

    try {
      await Future.wait([
        _storage.write(key: _tokenKey, value: token),
        _storage.write(key: _userIdKey, value: userId.toString()),
        _storage.write(key: _usernameKey, value: username),
        _storage.write(key: _emailKey, value: email),
        _storage.write(key: _displayNameKey, value: displayName),
      ]);
    } catch (_) {}
  }

  Future<Map<String, String?>> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readPrefs(prefs);
    if ((saved['token'] ?? '').isNotEmpty) return saved;

    try {
      final values = await Future.wait([
        _storage.read(key: _tokenKey),
        _storage.read(key: _userIdKey),
        _storage.read(key: _usernameKey),
        _storage.read(key: _emailKey),
        _storage.read(key: _displayNameKey),
      ]);
      final token = values[0];
      if (token == null || token.isEmpty) return {};
      await saveSession(
        token: token,
        userId: int.tryParse(values[1] ?? '') ?? 0,
        username: values[2] ?? '',
        email: values[3] ?? '',
        displayName: values[4] ?? '',
      );
      return {
        'token': token,
        'user_id': values[1],
        'username': values[2],
        'email': values[3],
        'display_name': values[4],
      };
    } catch (_) {
      return {};
    }
  }

  Map<String, String?> _readPrefs(SharedPreferences prefs) {
    return {
      'token': prefs.getString(_tokenKey),
      'user_id': prefs.getString(_userIdKey),
      'username': prefs.getString(_usernameKey),
      'email': prefs.getString(_emailKey),
      'display_name': prefs.getString(_displayNameKey),
    };
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
