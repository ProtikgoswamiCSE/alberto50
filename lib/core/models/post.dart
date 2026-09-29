class WpPost {
  final int id;
  final String title;
  final String excerpt;
  final String content;
  final String link;
  final String? featuredImageUrl;
  final String? authorName;
  final DateTime? date;
  final String status; // 'publish', 'private', etc.
  /// Raw meta fields from WordPress REST API (requires `meta` in REST fields).
  /// PMPro exposes 'pmpro_require_membership' here if configured.
  final Map<String, dynamic> meta;

  final String? videoUrl;

  const WpPost({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.link,
    this.featuredImageUrl,
    this.videoUrl,
    this.authorName,
    this.date,
    required this.status,
    this.meta = const {},
  });

  factory WpPost.fromJson(Map<String, dynamic> json) {
    String rendered(dynamic field) {
      if (field == null) return '';
      if (field is Map) return field['rendered'] as String? ?? '';
      return field.toString();
    }

    // Featured image, then the first real <img> in the post HTML.
    String? imageUrl;
    final embedded = json['_embedded'];
    if (embedded is Map) {
      final media = embedded['wp:featuredmedia'];
      if (media is List && media.isNotEmpty && media.first is Map) {
        imageUrl = _imageFromMedia(Map<String, dynamic>.from(media.first as Map));
      }
    }
    final htmlContent = rendered(json['content']);
    imageUrl ??= _imageFromHtml(htmlContent);

    String? authorName;
    if (embedded is Map) {
      final authors = embedded['author'];
      if (authors is List && authors.isNotEmpty) {
        authorName = (authors.first as Map?)?['name'] as String?;
      }
    }

    // Parse meta — WordPress REST exposes this as a map when registered
    final metaRaw = json['meta'];
    final Map<String, dynamic> meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : const {};

    // Extract exact video URL from API response fields or content HTML (no mocks)
    String? extractVideoUrl() {
      // 1. Direct API field
      if (json['video_url'] != null && json['video_url'].toString().isNotEmpty) {
        return json['video_url'].toString();
      }
      // 2. Meta fields
      for (final key in ['video_url', 'movie_url', 'trailer_url', 'embed_url', 'video_link']) {
        if (meta[key] != null && meta[key].toString().isNotEmpty) {
          return meta[key].toString();
        }
      }
      // 3. Extract iframe src or video src from rendered content HTML
      final iframeRegExp = RegExp('src=["\'](http[^"\']+)["\']');
      final match = iframeRegExp.firstMatch(htmlContent);
      if (match != null) {
        return match.group(1);
      }
      return null;
    }

    final videoUrl = extractVideoUrl();

    return WpPost(
      id: json['id'] as int? ?? 0,
      title: rendered(json['title']),
      excerpt: _stripHtml(rendered(json['excerpt'])),
      content: rendered(json['content']),
      link: json['link'] as String? ?? '',
      featuredImageUrl: imageUrl,
      videoUrl: videoUrl,
      authorName: authorName,
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      status: json['status'] as String? ?? 'publish',
      meta: meta,
    );
  }

  /// True if the post content is freely accessible (no membership required).
  /// PMPro sets 'pmpro_require_membership' meta to a level ID when restricted.
  /// If that meta field is absent or 0, the post is accessible to all.
  bool get isAccessible {
    if (status != 'publish') return false;
    // If pmpro restriction meta is present and non-zero → members only
    final restricted = meta['pmpro_require_membership'];
    if (restricted != null &&
        restricted.toString().isNotEmpty &&
        restricted.toString() != '0') {
      return false;
    }
    return true;
  }

  static String? _httpUrl(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    return null;
  }

  static String? _imageFromMedia(Map<String, dynamic> media) {
    final sizes = (media['media_details'] as Map?)?['sizes'];
    if (sizes is Map) {
      for (final key in [
        'large',
        'medium_large',
        'wowtube_classic',
        'full',
        'medium',
        'thumbnail',
      ]) {
        final entry = sizes[key];
        if (entry is Map) {
          final url = _httpUrl(entry['source_url']);
          if (url != null) return url;
        }
      }
    }
    return _httpUrl(media['source_url']);
  }

  static String? _imageFromHtml(String html) {
    final img = RegExp(
      '<img[^>]+src=["\'](https?://[^"\']+)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    final fromImg = _httpUrl(img?.group(1));
    if (fromImg != null) return fromImg;
    final file = RegExp(
      'https?://[^"\'\\s>]+\\.(?:jpg|jpeg|png|webp|gif)',
      caseSensitive: false,
    ).firstMatch(html);
    return _httpUrl(file?.group(0));
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
