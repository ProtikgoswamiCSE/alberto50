import '../api/api_client.dart';

class AuthApi {
  final ApiClient _client;
  const AuthApi(this._client);

  /// POST jwt-auth/v1/token — returns the full token response map.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final data = await _client.post(
      '/jwt-auth/v1/token',
      body: {'username': username, 'password': password},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Register new user using public WordPress / PMPro registration endpoints.
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      // 1. Primary: Standard WordPress REST API user creation
      final data = await _client.post(
        '/wp/v2/users',
        body: {
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'name': '$firstName $lastName'.trim(),
        },
      );
      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      // 2. Fallback: PMPro change_membership_level with level_id 0 / 1
      final data = await _client.post(
        '/pmpro/v1/change_membership_level',
        body: {
          'create_user': true,
          'user_login': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'level_id': 0,
        },
      );
      return Map<String, dynamic>.from(data as Map);
    }
  }

  /// POST jwt-auth/v1/token/validate.
  ///
  /// `true` valid, `false` rejected (401/403), `null` network or other error.
  /// A network miss must not sign the user out.
  Future<bool?> validateToken() async {
    try {
      await _client.post('/jwt-auth/v1/token/validate');
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) return false;
      return null;
    } catch (_) {
      return null;
    }
  }
}
