import 'package:flutter/foundation.dart';
import '../api/membership_api.dart';
import '../models/membership_level.dart';
import '../models/order.dart';

class MembershipProvider extends ChangeNotifier {
  final MembershipApi _api;

  MembershipLevel? _currentLevel;
  List<MembershipLevel> _allLevels = [];
  List<MemberOrder> _orders = [];
  Map<String, dynamic>? _meData;
  bool _loadingLevel = false;
  bool _loadingLevels = false;
  bool _loadingOrders = false;
  String? _error;

  MembershipLevel? get currentLevel => _currentLevel;
  List<MembershipLevel> get allLevels => _allLevels;
  List<MemberOrder> get orders => _orders;
  Map<String, dynamic>? get meData => _meData;
  bool get loadingLevel => _loadingLevel;
  bool get loadingLevels => _loadingLevels;
  bool get loadingOrders => _loadingOrders;
  String? get error => _error;
  bool get hasMembership => _currentLevel != null && _currentLevel!.id > 0;

  MembershipProvider(this._api);

  Future<void> loadAll() async {
    await Future.wait([loadMe(), loadAllLevels(), loadOrders()]);
  }

  Future<void> loadMe() async {
    _loadingLevel = true;
    notifyListeners();
    try {
      _meData = await _api.getMe();
      final levelData = _meData?['membership_level'];
      if (levelData is Map) {
        _currentLevel =
            MembershipLevel.fromJson(Map<String, dynamic>.from(levelData));
      } else {
        _currentLevel = null;
      }
    } catch (e) {
      _error = e.toString();
      _currentLevel = null;
    } finally {
      _loadingLevel = false;
      notifyListeners();
    }
  }

  Future<void> loadAllLevels() async {
    _loadingLevels = true;
    notifyListeners();
    try {
      final loaded = (await _api.getMembershipLevels())
          .where((level) => level.allowsSignup && level.id > 0)
          .toList();
      _allLevels = loaded.isEmpty ? MembershipLevel.sitePlans : loaded;
      if (loaded.isNotEmpty) _error = null;
    } catch (e) {
      _allLevels = MembershipLevel.sitePlans;
      _error = e.toString();
    } finally {
      _loadingLevels = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    _loadingOrders = true;
    notifyListeners();
    try {
      _orders = await _api.getRecentOrders();
    } catch (e) {
      _orders = [];
    } finally {
      _loadingOrders = false;
      notifyListeners();
    }
  }

  void reset() {
    _currentLevel = null;
    _allLevels = [];
    _orders = [];
    _meData = null;
    _error = null;
    notifyListeners();
  }
}
