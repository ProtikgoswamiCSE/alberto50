import 'package:flutter/foundation.dart';
import '../api/posts_api.dart';
import '../models/post.dart';

class PostsProvider extends ChangeNotifier {
  final PostsApi _api;

  List<WpPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  List<WpPost> get posts => _posts;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  PostsProvider(this._api);

  Future<void> loadPosts({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) {
      _posts = [];
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await _api.getPosts(page: _page, perPage: 10);
      if (newPosts.length < 10) _hasMore = false;
      _posts = [..._posts, ...newPosts];
      _page++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<WpPost?> getPostDetail(int id) async {
    try {
      return await _api.getPost(id);
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _posts = [];
    _page = 1;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
}
