import '../api/api_client.dart';
import '../models/post.dart';

class PostsApi {
  final ApiClient _client;
  const PostsApi(this._client);

  /// GET wp/v2/movies with pagination and optional search.
  Future<List<WpPost>> getPosts({
    int page = 1,
    int perPage = 10,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      '_embed': 1, // includes featured media + author
    };
    if (search != null && search.isNotEmpty) params['search'] = search;

    final data = await _client.get('/wp/v2/movies', params: params);
    final list = data as List;
    return list
        .map((e) => WpPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// GET wp/v2/movies/{id}
  Future<WpPost> getPost(int id) async {
    final data = await _client.get('/wp/v2/movies/$id', params: {'_embed': 1});
    return WpPost.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// GET wp/v2/pages — for static pages if needed.
  Future<List<WpPost>> getPages({int page = 1, int perPage = 10}) async {
    final data = await _client.get('/wp/v2/pages', params: {
      'page': page,
      'per_page': perPage,
      '_embed': 1,
    });
    final list = data as List;
    return list
        .map((e) => WpPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
