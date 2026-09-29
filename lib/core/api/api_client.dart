import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Central HTTP client that injects the JWT Bearer token on every request.
class ApiClient {
  static const String _baseUrl = 'https://albertru50.doptortechllc.com/wp-json';

  String? _token;

  /// Called when the server returns 401 (token expired / invalid).
  /// Set this in main.dart to trigger auto-logout.
  void Function()? onUnauthorized;

  void setToken(String? token) => _token = token;

  Map<String, String> _headers({bool jsonBody = false, bool auth = true}) {
    return {
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
      if (auth && _token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (params == null) return uri;
    return uri.replace(
      queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    final res = await http.get(_uri(path, params), headers: _headers());
    return _handle(res);
  }

  /// Public GET with no auth header. Membership plans are public, and the
  /// site's preflight response has no CORS headers, so Authorization blocks
  /// the browser from reading them.
  Future<dynamic> getPublic(String path, {Map<String, dynamic>? params}) async {
    final res = await http.get(
      _uri(path, params),
      headers: _headers(auth: false),
    );
    return _handle(res, unauthorizedMeansLogout: false);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body ?? {}),
    );
    return _handle(res);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final res = await http.put(
      _uri(path),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body ?? {}),
    );
    return _handle(res);
  }

  dynamic _handle(http.Response res, {bool unauthorizedMeansLogout = true}) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      if (unauthorizedMeansLogout &&
          _token != null &&
          _token!.isNotEmpty) {
        onUnauthorized?.call();
      }
      final msg = _extractMessage(res) ?? 'Session expired. Please log in again.';
      throw ApiException(msg, statusCode: res.statusCode);
    }
    if (res.body.isEmpty) return null;
    final data = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final msg = data is Map ? (data['message'] ?? 'Unknown error') : 'Error';
    throw ApiException(msg.toString(), statusCode: res.statusCode);
  }

  String? _extractMessage(http.Response res) {
    try {
      if (res.body.isEmpty) return null;
      final data = jsonDecode(res.body);
      if (data is Map) return data['message'] as String?;
    } catch (_) {}
    return null;
  }
}
