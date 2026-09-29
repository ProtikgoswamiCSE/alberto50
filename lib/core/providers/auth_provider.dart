import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _apiClient;
  final AuthApi _authApi;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider({
    required AuthService authService,
    required ApiClient apiClient,
    required AuthApi authApi,
  })  : _authService = authService,
        _apiClient = apiClient,
        _authApi = authApi;

  /// Called at app startup — restores saved session.
  Future<void> tryAutoLogin() async {
    final session = await _authService.loadSession();
    final token = session['token'];
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _apiClient.setToken(token);
    _user = AppUser(
      id: int.tryParse(session['user_id'] ?? '') ?? 0,
      username: session['username'] ?? '',
      email: session['email'] ?? '',
      displayName: session['display_name'] ?? '',
      token: token,
    );
    _status = AuthStatus.authenticated;

    final valid = await _authApi.validateToken();
    if (valid == false) {
      await _authService.clearSession();
      _apiClient.setToken(null);
      _user = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authApi.login(
        username: username,
        password: password,
      );
      final user = AppUser.fromTokenResponse(response);
      _apiClient.setToken(user.token);
      await _authService.saveSession(
        token: user.token,
        userId: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
      );
      _user = user;
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.clearSession();
    _apiClient.setToken(null);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _authApi.register(
        email: email,
        username: username,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      // Automatically log in after registration
      final success = await login(username, password);
      return success;
    } on ApiException catch (e) {
      _error = e.message;
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
