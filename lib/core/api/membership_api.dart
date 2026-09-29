import '../api/api_client.dart';
import '../models/membership_level.dart';
import '../models/order.dart';

class MembershipApi {
  final ApiClient _client;
  const MembershipApi(this._client);

  /// GET pmpro/v1/me — current user's membership info.
  Future<Map<String, dynamic>> getMe() async {
    final data = await _client.get('/pmpro/v1/me');
    return Map<String, dynamic>.from(data as Map);
  }

  /// GET pmpro/v1/membership_levels — Free and Premium, public catalog.
  Future<List<MembershipLevel>> getMembershipLevels() async {
    final data = await _client.getPublic('/pmpro/v1/membership_levels');
    final levels = _parseLevels(data);
    levels.sort((a, b) => a.id.compareTo(b.id));
    return levels;
  }

  List<MembershipLevel> _parseLevels(dynamic data) {
    final raw = <dynamic>[];
    if (data is List) {
      raw.addAll(data);
    } else if (data is Map) {
      final nested = data['data'];
      if (nested is Map || nested is List) {
        return _parseLevels(nested);
      }
      raw.addAll(data.values);
    }

    final levels = <MembershipLevel>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final level = MembershipLevel.fromJson(Map<String, dynamic>.from(item));
      if (level.id <= 0 || level.name.isEmpty) continue;
      levels.add(level);
    }
    return levels;
  }

  /// GET pmpro/v1/get_membership_level_for_user?user_id=...
  Future<MembershipLevel?> getLevelForUser(int userId) async {
    try {
      final data = await _client.get(
        '/pmpro/v1/get_membership_level_for_user',
        params: {'user_id': userId},
      );
      if (data == null) return null;
      return MembershipLevel.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  /// GET pmpro/v1/recent_orders — recent orders for current user.
  Future<List<MemberOrder>> getRecentOrders() async {
    try {
      final data = await _client.get('/pmpro/v1/recent_orders');
      if (data == null) return [];
      final list = data as List;
      return list
          .map((e) => MemberOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// POST pmpro/v1/change_membership_level — change/assign level.
  Future<void> changeMembershipLevel({
    required int userId,
    required int levelId,
  }) async {
    await _client.post(
      '/pmpro/v1/change_membership_level',
      body: {'user_id': userId, 'level_id': levelId},
    );
  }
}
