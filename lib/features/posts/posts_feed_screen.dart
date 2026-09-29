import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/post.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/providers/membership_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/tv_focusable_card.dart';
import '../../shared/widgets/tv_scroll_handler.dart';
import 'post_detail_screen.dart';


class PostsFeedScreen extends StatefulWidget {
  final bool isTV;
  const PostsFeedScreen({super.key, this.isTV = false});

  @override
  State<PostsFeedScreen> createState() => _PostsFeedScreenState();
}

class _PostsFeedScreenState extends State<PostsFeedScreen> {
  final _scrollCtrl = ScrollController();
  // Separate scroll controllers for the two horizontal rows.
  final _trendingScrollCtrl = ScrollController();
  final _popularScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _trendingScrollCtrl.dispose();
    _popularScrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvScrollHandler(
      controller: _scrollCtrl,
      isTV: widget.isTV,
      backPops: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Consumer2<PostsProvider, MembershipProvider>(
          builder: (context, posts, membership, _) {
            return CustomScrollView(
              controller: _scrollCtrl,
                scrollCacheExtent: ScrollCacheExtent.pixels(widget.isTV ? 4000 : 400),
              slivers: [
                _buildAppBar(),
                ..._contentSlivers(posts, membership),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      // On TV a floating bar slides back over the content whenever D-pad focus
      // scrolls upward, covering the top of the hero banner and its focus ring.
      // Let it scroll away instead so nothing overlaps the banner.
      floating: !widget.isTV,
      snap: !widget.isTV,
      backgroundColor: AppTheme.bgDark.withValues(alpha: 0.9),
      expandedHeight: widget.isTV ? 80 : 65,
      title: Padding(
        padding: EdgeInsets.only(left: widget.isTV ? 20 : 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 22,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Text(
              'HORROR MOVIES',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: widget.isTV ? 26 : 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    PostsProvider posts,
    MembershipProvider membership,
  ) {
    if (posts.loading && posts.posts.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.all(widget.isTV ? 40 : 20),
          sliver: SliverToBoxAdapter(child: _shimmerLayout()),
        ),
      ];
    }

    if (posts.error != null && posts.posts.isEmpty) {
      return [SliverFillRemaining(child: _errorState(posts))];
    }

    if (posts.posts.isEmpty) {
      return const [
        SliverFillRemaining(
          child: Center(
            child: Text(
              'No horror movies found.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),
        ),
      ];
    }

    final featuredMovie = posts.posts.first;
    final remainingPosts =
        posts.posts.length > 1 ? posts.posts.sublist(1) : <WpPost>[];
    final trendingMovies = remainingPosts.take(6).toList();
    final popularMovies = remainingPosts.skip(3).toList();
    final hasMembership = membership.hasMembership;

    return [
      SliverToBoxAdapter(
        child: _buildHeroBillboard(featuredMovie, hasMembership),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
      if (trendingMovies.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _buildCategoryHeader(
            'TRENDING MOVIES',
            Icons.local_fire_department_rounded,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: _buildHorizontalMovieRow(
            trendingMovies,
            hasMembership,
            _trendingScrollCtrl,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
      if (popularMovies.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _buildCategoryHeader(
            'EXCLUSIVES & SHORTS',
            Icons.movie_filter_rounded,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: _buildHorizontalMovieRow(
            popularMovies,
            hasMembership,
            _popularScrollCtrl,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(
        child: _buildCategoryHeader(
          'ALL MOVIES & POSTS',
          Icons.grid_view_rounded,
          horizontalPadding: widget.isTV ? 56 : 28,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      if (widget.isTV)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(56, 0, 56, 12),
          sliver: SliverToBoxAdapter(
            child: _buildTvMovieGrid(posts.posts, hasMembership),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildPosterCard(posts.posts[i], hasMembership),
              childCount: posts.posts.length,
            ),
          ),
        ),
      if (posts.hasMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          ),
        )
      else
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'You\'ve reached the end of the night.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          ),
        ),
    ];
  }

  // ─── Hero Movie Billboard ──────────────────────────────────────────────────
  Widget _buildHeroBillboard(WpPost movie, bool hasMembership) {
    final locked = !movie.isAccessible && !hasMembership;
    final padding = widget.isTV ? 40.0 : 16.0;
    // Top padding keeps the focus ring + any scale inside the viewport;
    // CustomScrollView otherwise clips the Featured banner at the top.
    final topPad = widget.isTV ? 20.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, topPad, padding, 4),
      child: TvFocusableCard(
        onTap: () => _openPost(movie, locked),
        borderRadius: BorderRadius.circular(20),
        // Full-width hero: avoid 1.05 scale clipping the top focus border.
        scaleOnFocus: false,
        // On TV, autofocus the hero billboard so the remote lands here first.
        autofocus: widget.isTV,
        child: Container(
          height: widget.isTV ? 380 : 260,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.bgCard,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PosterImage(
                url: movie.featuredImageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),

              // Horror Vignette Gradient Overlays
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xBB0A0A0A),
                      Colors.transparent,
                      Color(0xFA0A0A0A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.95],
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xEE0A0A0A),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.8],
                  ),
                ),
              ),

              // Content Overlay
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tag Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEATURED MOVIE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded,
                                    size: 11, color: Colors.black),
                                SizedBox(width: 4),
                                Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Movie Title
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: widget.isTV ? 30 : 22,
                            color: Colors.white,
                            height: 1.15,
                            shadows: [
                              const Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Movie Excerpt / Description
                    Text(
                      movie.excerpt,
                      maxLines: widget.isTV ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: widget.isTV ? 14 : 12,
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 14),

                    ExcludeFocus(
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(130, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => _openPost(movie, locked),
                            icon: Icon(
                              locked
                                  ? Icons.lock_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: Text(
                              locked ? 'Unlock Movie' : 'Watch Now',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildCategoryHeader(
    String title,
    IconData icon, {
    double? horizontalPadding,
  }) {
    final padding = horizontalPadding ?? (widget.isTV ? 56.0 : 16.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: widget.isTV ? 20 : 15,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  // ─── Horizontal Streaming Movie Row ────────────────────────────────────────
  Widget _buildHorizontalMovieRow(
    List<WpPost> movies,
    bool hasMembership,
    ScrollController rowScrollCtrl,
  ) {
    if (widget.isTV) {
      // A real grid, not a sideways scroller. Mi TV D-pad can focus
      // every card: right is the next card, down is the card below.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56),
        child: _buildTvMovieGrid(movies, hasMembership),
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.builder(
        controller: rowScrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: movies.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _buildPosterCard(movies[i], hasMembership),
          );
        },
      ),
    );
  }

  /// Four equal columns, every card built, so Right is 1 → 2 → 3 → 4
  /// and Down stays in the same column.
  Widget _buildTvMovieGrid(List<WpPost> movies, bool hasMembership) {
    const columns = 4;
    const gap = 18.0;
    const rowHeight = 248.0;
    final rows = <Widget>[];
    for (var i = 0; i < movies.length; i += columns) {
      final slice = movies.skip(i).take(columns).toList();
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Expanded(
                    child: c < slice.length
                        ? _buildPosterCard(
                            slice[c],
                            hasMembership,
                            fillWidth: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ─── Movie Poster Card (Vertical Poster Style) ─────────────────────────────
  Widget _buildPosterCard(
    WpPost movie,
    bool hasMembership, {
    bool fillWidth = false,
  }) {
    final locked = !movie.isAccessible && !hasMembership;
    final width = widget.isTV ? 160.0 : 130.0;

    final card = TvFocusableCard(
        onTap: () => _openPost(movie, locked),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster Image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(url: movie.featuredImageUrl),

                  // Bottom Shadow Overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),

                  // Lock Badge
                  if (locked)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black87,
                          child: Icon(Icons.lock_rounded,
                              color: AppTheme.gold, size: 18),
                        ),
                      ),
                    ),

                  // Play Icon Overlay
                  if (!locked)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Title & Subtitle
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: widget.isTV ? 13 : 12,
                          height: 1.2,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
    if (fillWidth) return card;
    return SizedBox(width: width, child: card);
  }

  // ─── Loading Shimmer ───────────────────────────────────────────────────────
  Widget _shimmerLayout() {
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCard,
      highlightColor: AppTheme.bgElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner shimmer
          Container(
            height: widget.isTV ? 380 : 240,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 28),
          // Row title shimmer
          Container(
            width: 160,
            height: 20,
            color: AppTheme.bgCard,
          ),
          const SizedBox(height: 14),
          // Horizontal posters shimmer
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) => Container(
                width: 130,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error State ───────────────────────────────────────────────────────────
  Widget _errorState(PostsProvider posts) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppTheme.textMuted, size: 52),
          const SizedBox(height: 16),
          Text('Failed to load movies',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 40),
            ),
            onPressed: () => posts.loadPosts(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _openPost(WpPost post, bool locked) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PostDetailScreen(post: post, isLocked: locked),
    ));
  }
}
