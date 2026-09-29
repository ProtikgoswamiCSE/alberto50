import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/post.dart';
import '../../core/services/platform_service.dart';
import '../../core/services/remote_keys.dart';
import '../../core/services/tv_player_remote.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/locked_content_banner.dart';
import '../../shared/widgets/poster_image.dart';
import '../../shared/widgets/in_app_webview_screen.dart';
import '../../shared/widgets/tv_transport_bar.dart';

class PostDetailScreen extends StatefulWidget {
  final WpPost post;
  final bool isLocked;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.isLocked = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  YoutubePlayerController? _ytController;
  VideoPlayerController? _videoPlayerController;
  bool _isVideoLoading = false;
  bool _isBuffering = false;
  String? _videoError;
  DateTime? _lastRemoteActionAt;
  bool _initInFlight = false;
  bool _playWhenReady = false;

  /// Per-candidate cap. Two candidates worst case, so the spinner is bounded.
  static const _initTimeout = Duration(seconds: 12);
  static const _resolveTimeout = Duration(seconds: 6);
  static const _maxPlaybackAttempts = 2;

  final _scrollCtrl = ScrollController();
  final _backFocus = FocusNode();
  final _playFocus = FocusNode();
  final _back10mFocus = FocusNode();
  final _back10sFocus = FocusNode();
  final _fwd10sFocus = FocusNode();
  final _fwd10mFocus = FocusNode();
  final _muteFocus = FocusNode();
  final _fullscreenFocus = FocusNode();
  bool _muted = false;
  bool _fullscreen = false;
  bool _chrome = true;
  bool _chromeArmed = false;
  Timer? _chromeTimer;

  List<FocusNode> get _transportFocus => [
        _back10mFocus,
        _back10sFocus,
        _playFocus,
        _fwd10sFocus,
        _fwd10mFocus,
        _muteFocus,
        _fullscreenFocus,
      ];

  @override
  void initState() {
    super.initState();
    TvPlayerRemote.register(_onPlayerRemote);
    _initPlayer();
  }

  /// Returns true if [url] is an embed page / web player (Rumble, Vimeo, Dailymotion,
  /// generic iframes, etc.) rather than a direct streamable file (mp4, m3u8, webm).
  /// These URLs cannot be played by video_player/ExoPlayer and will crash.
  bool _isEmbedUrl(String url) {
    final lower = url.toLowerCase();
    // Well-known embed patterns
    if (lower.contains('rumble.com/embed') ||
        lower.contains('vimeo.com/video') ||
        lower.contains('dailymotion.com/embed') ||
        lower.contains('player.twitch.tv') ||
        lower.contains('bitchute.com/embed') ||
        lower.contains('odysee.com/\$/embed') ||
        lower.contains('facebook.com/plugins/video') ||
        lower.contains('/embed/') ||
        lower.contains('iframe')) {
      return true;
    }
    // Only allow extensions that ExoPlayer can handle
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      final directExts = ['.mp4', '.m3u8', '.webm', '.mkv', '.ts', '.mov', '.avi', '.flv'];
      // If URL has a file extension and it's NOT a known direct type → treat as embed
      final hasExt = directExts.any((e) => path.endsWith(e));
      final hasAnyExt = path.contains('.');
      if (hasAnyExt && !hasExt) return true;
    }
    return false;
  }

  /// Rumble progressive MP4 URLs in start-up-speed order.
  /// Mid-ladder first; a 1080p file takes far longer to start on a TV box.
  List<String> _rumbleMp4Urls(Map<String, dynamic> mp4) {
    String? urlOf(dynamic entry) {
      if (entry is Map) {
        final url = entry['url'];
        if (url is String && url.isNotEmpty) return url;
      }
      return null;
    }

    final ordered = <String>[];
    for (final q in ['720', '480', '360', '240', '1080']) {
      final url = urlOf(mp4[q]);
      if (url != null && !ordered.contains(url)) ordered.add(url);
    }
    final rest = mp4.keys.toList()
      ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    for (final q in rest) {
      final url = urlOf(mp4[q]);
      if (url != null && !ordered.contains(url)) ordered.add(url);
    }
    return ordered;
  }

  /// Direct stream candidates for an embed page URL, best first.
  ///
  /// HLS is listed first because adaptive playback starts fastest, but the
  /// progressive MP4s stay in the list so a rejected stream (for example an
  /// HLS URL the CDN refuses) falls back instead of stranding the spinner.
  Future<List<String>> _resolveEmbedCandidates(String embedUrl) async {
    final candidates = <String>[];
    void add(String? url) {
      if (url == null || url.isEmpty) return;
      if (!candidates.contains(url)) candidates.add(url);
    }

    try {
      // ── Rumble ─────────────────────────────────────────────────────────
      if (embedUrl.contains('rumble.com/embed')) {
        final uri = Uri.parse(embedUrl);
        // Path is like /embed/v7bq638/ — extract the video ID segment
        final seg = uri.pathSegments
            .firstWhere((s) => s.startsWith('v') && s.length > 2, orElse: () => '');
        if (seg.isNotEmpty) {
          final apiUrl =
              'https://rumble.com/embedJS/u3/?request=video&ver=2&v=$seg';
          final res = await http
              .get(Uri.parse(apiUrl), headers: {'Accept': 'application/json'})
              .timeout(_resolveTimeout);
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            add(data['u']?['hls']?['url'] as String?);
            final mp4 = data['ua']?['mp4'] as Map<String, dynamic>?;
            if (mp4 != null) _rumbleMp4Urls(mp4).forEach(add);
          }
        }
        // No second HTML scrape for Rumble — that added another blocking
        // round trip before playback could start.
        return candidates;
      }

      // ── Generic fallback: fetch page HTML and grep for video URLs ───────
      final res = await http
          .get(
            Uri.parse(embedUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Android TV; Linux) AppleWebKit/537.36',
            },
          )
          .timeout(_resolveTimeout);
      if (res.statusCode == 200) {
        final body = res.body;
        final patterns = [
          RegExp(r'https?://[^"\s]+\.m3u8[^"\s]*', caseSensitive: false),
          RegExp(r'https?://[^"\s]+\.mp4[^"\s]*', caseSensitive: false),
          RegExp(r'https?://[^"\s]+\.webm[^"\s]*', caseSensitive: false),
        ];
        for (final pattern in patterns) {
          add(pattern.firstMatch(body)?.group(0));
        }
      }
    } catch (e) {
      debugPrint('[PostDetail] Embed resolve failed: $e');
    }
    return candidates;
  }

  void _onVideoTick() {
    final vpc = _videoPlayerController;
    if (vpc == null || !mounted) return;
    if (vpc.value.hasError) {
      // A mid-stream failure must not leave the spinner up forever.
      if (_videoError == null) {
        _videoError = 'Video failed to load. Check the connection and retry.';
        _isBuffering = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _dropFailedVideo());
      }
      return;
    }
    final playing = vpc.value.isPlaying;
    final atStart = vpc.value.position <= const Duration(milliseconds: 250);
    final buffering = vpc.value.isBuffering || (playing && atStart);
    if (buffering != _isBuffering) {
      setState(() => _isBuffering = buffering);
    }
  }

  Future<void> _dropFailedVideo() async {
    final vpc = _videoPlayerController;
    if (vpc == null) return;
    _videoPlayerController = null;
    vpc.removeListener(_onVideoTick);
    // Rebuild first so the transport bar stops listening to this controller.
    if (mounted) setState(() {});
    await vpc.dispose();
  }

  /// Initializes [url] and only publishes the controller once it is ready,
  /// so the transport bar never appears before the player can seek or play.
  Future<void> _attachVideo(String url) async {
    final previous = _videoPlayerController;
    _videoPlayerController = null;
    previous?.removeListener(_onVideoTick);
    await previous?.dispose();

    final vpc = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await vpc.initialize().timeout(_initTimeout);
    } catch (_) {
      await vpc.dispose();
      rethrow;
    }
    if (!mounted) {
      await vpc.dispose();
      return;
    }
    await vpc.setLooping(false);
    if (_muted) await vpc.setVolume(0);
    vpc.addListener(_onVideoTick);
    _videoPlayerController = vpc;

    // Play was pressed while this was still loading — honour it now.
    final startNow = _playWhenReady;
    _playWhenReady = false;
    setState(() => _isBuffering = startNow);
    if (startNow) await vpc.play();
  }

  Future<void> _initPlayer() async {
    // One initialization at a time: repeated OK / retry must not create
    // parallel controllers that both buffer and fight over playback.
    if (_initInFlight) return;

    final videoUrl = widget.post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    // 1. YouTube
    final ytId = YoutubePlayer.convertUrlToId(videoUrl);
    if (ytId != null && ytId.isNotEmpty) {
      _ytController = YoutubePlayerController(
        initialVideoId: ytId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
          hideControls: true,
        ),
      );
      if (mounted) setState(() {});
      return;
    }

    _initInFlight = true;
    if (mounted) {
      setState(() {
        _isVideoLoading = true;
        _videoError = null;
      });
    }

    try {
      // 2. Embed URL → resolve direct streams (avoids WebView GPU crashes on TV).
      // 3. Direct streamable file (mp4, m3u8, …) is already its own candidate.
      final candidates = _isEmbedUrl(videoUrl)
          ? await _resolveEmbedCandidates(videoUrl)
          : <String>[videoUrl];

      if (candidates.isEmpty) {
        debugPrint('[PostDetail] Falling back to WebView button for: $videoUrl');
        return;
      }

      Object? lastError;
      for (final url in candidates.take(_maxPlaybackAttempts)) {
        if (!mounted) return;
        try {
          debugPrint('[PostDetail] Trying stream: $url');
          await _attachVideo(url);
          return;
        } catch (e) {
          lastError = e;
          debugPrint('[PostDetail] Stream failed ($url): $e');
        }
      }
      debugPrint('[PostDetail] All stream candidates failed: $lastError');
      if (mounted) {
        setState(() {
          _videoError = 'Video failed to load. Check the connection and retry.';
        });
      }
    } catch (e) {
      debugPrint('[PostDetail] Player init error: $e');
      if (mounted) {
        setState(() {
          _videoError = 'Video failed to load. Check the connection and retry.';
        });
      }
    } finally {
      _initInFlight = false;
      _playWhenReady = false;
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  Future<void> _retryVideo() async {
    if (_initInFlight) return;
    setState(() {
      _videoError = null;
      _isVideoLoading = true;
    });
    await _initPlayer();
  }

  @override
  void dispose() {
    TvPlayerRemote.unregister(_onPlayerRemote);
    _ytController?.dispose();
    _videoPlayerController?.removeListener(_onVideoTick);
    _videoPlayerController?.dispose();
    _scrollCtrl.dispose();
    for (final n in [_backFocus, ..._transportFocus]) {
      n.dispose();
    }
    _chromeTimer?.cancel();
    super.dispose();
  }

  bool get _isPlaying {
    if (_ytController != null) return _ytController!.value.isPlaying;
    return _videoPlayerController?.value.isPlaying ?? false;
  }

  bool get _showTransport =>
      _ytController != null ||
      (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized);

  void _toggleMute() {
    if (!_guardRemoteAction()) return;
    final next = !_muted;
    setState(() => _muted = next);
    if (_ytController != null) {
      if (next) {
        _ytController!.mute();
      } else {
        _ytController!.unMute();
      }
      return;
    }
    _videoPlayerController?.setVolume(next ? 0 : 1);
  }

  void _toggleFullscreen() {
    if (!_guardRemoteAction()) return;
    setState(() => _fullscreen = !_fullscreen);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playFocus.requestFocus();
    });
  }

  bool get _hasPlayer =>
      _ytController != null ||
      (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized);

  Duration get _position {
    if (_ytController != null) return _ytController!.value.position;
    final vpc = _videoPlayerController;
    if (vpc != null && vpc.value.isInitialized) return vpc.value.position;
    return Duration.zero;
  }

  Duration get _duration {
    if (_ytController != null) {
      final d = _ytController!.metadata.duration;
      if (d > Duration.zero) return d;
    }
    final vpc = _videoPlayerController;
    if (vpc != null && vpc.value.isInitialized) return vpc.value.duration;
    return Duration.zero;
  }

  /// One physical OK reaches the controls twice: once through
  /// [TvRemoteBinder] → [TvPlayerRemote] (a `HardwareKeyboard` handler) and
  /// once through the app-level `Shortcuts` → `ActivateIntent`, because Flutter
  /// still dispatches the key message to the focus tree after a hardware
  /// handler returns true. Every transport action funnels through here so the
  /// duplicate is dropped and one press stays one action.
  bool _guardRemoteAction() {
    final now = DateTime.now();
    final last = _lastRemoteActionAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 280)) {
      return false;
    }
    _lastRemoteActionAt = now;
    return true;
  }

  void _togglePlayPause() {
    if (!_guardRemoteAction()) return;
    if (_ytController != null) {
      if (_ytController!.value.isPlaying) {
        _ytController!.pause();
      } else {
        _ytController!.play();
      }
      if (mounted) setState(() {});
      return;
    }
    final vpc = _videoPlayerController;
    if (vpc == null || !vpc.value.isInitialized) {
      // Not ready yet: keep the intent instead of dropping the press. The
      // spinner is already on screen and playback starts as soon as it can.
      if (_isVideoLoading || _initInFlight) {
        _playWhenReady = true;
        return;
      }
      if (_videoError != null) {
        _playWhenReady = true;
        _retryVideo();
      }
      return;
    }
    if (vpc.value.isPlaying) {
      vpc.pause();
      if (mounted) setState(() => _isBuffering = false);
    } else {
      // Show loading immediately so OK does not look frozen at 0:00.
      if (mounted) setState(() => _isBuffering = true);
      vpc.play();
    }
  }

  Future<void> _seekBy(Duration delta) async {
    if (!_guardRemoteAction()) return;
    var next = _position + delta;
    if (next < Duration.zero) next = Duration.zero;
    final dur = _duration;
    if (dur > Duration.zero && next > dur) next = dur;
    if (_ytController != null) {
      _ytController!.seekTo(next);
      return;
    }
    final vpc = _videoPlayerController;
    if (vpc != null && vpc.value.isInitialized) {
      await vpc.seekTo(next);
    }
  }

  FocusNode? _focusedTransportNode() {
    for (final n in _transportFocus) {
      if (n.hasFocus) return n;
    }
    if (_backFocus.hasFocus) return _backFocus;
    return null;
  }

  /// Back control: leave fullscreen first, otherwise close the movie page.
  /// Guarded so the duplicated OK cannot pop two routes at once.
  void _exitFullscreenOrPop() {
    if (!_guardRemoteAction()) return;
    if (_fullscreen) {
      setState(() => _fullscreen = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _activateFocusedControl({bool preferPlayIfNone = false}) {
    final focused = _focusedTransportNode();
    if (identical(focused, _backFocus)) {
      _exitFullscreenOrPop();
      return;
    }
    if (identical(focused, _back10mFocus)) {
      _seekBy(const Duration(minutes: -10));
      return;
    }
    if (identical(focused, _back10sFocus)) {
      _seekBy(const Duration(seconds: -10));
      return;
    }
    if (identical(focused, _playFocus)) {
      _togglePlayPause();
      return;
    }
    if (identical(focused, _fwd10sFocus)) {
      _seekBy(const Duration(seconds: 10));
      return;
    }
    if (identical(focused, _fwd10mFocus)) {
      _seekBy(const Duration(minutes: 10));
      return;
    }
    if (identical(focused, _muteFocus)) {
      _toggleMute();
      return;
    }
    if (identical(focused, _fullscreenFocus)) {
      _toggleFullscreen();
      return;
    }
    if (preferPlayIfNone) _togglePlayPause();
  }

  bool _moveTransport(TraversalDirection direction) {
    final order = _transportFocus;
    final idx = order.indexWhere((n) => n.hasFocus);

    if (direction == TraversalDirection.left ||
        direction == TraversalDirection.right) {
      if (_backFocus.hasFocus) {
        // From back, Left/Right stay; user presses Down for controls.
        return true;
      }
      if (idx < 0) {
        _playFocus.requestFocus();
        return true;
      }
      final next = direction == TraversalDirection.right ? idx + 1 : idx - 1;
      if (next < 0 || next >= order.length) return true; // clamp, no page jump
      order[next].requestFocus();
      return true;
    }

    if (direction == TraversalDirection.up) {
      // If page is scrolled down, first bring content back up.
      if (_scrollPage(-1)) return true;
      if (idx >= 0) {
        _backFocus.requestFocus();
        return true;
      }
      return true;
    }

    // Down: back → play controls; from controls → scroll page content.
    if (_backFocus.hasFocus) {
      _playFocus.requestFocus();
      return true;
    }
    if (idx >= 0) {
      _scrollPage(1);
      return true;
    }
    _playFocus.requestFocus();
    return true;
  }

  /// Remote-driven page scroll so TV can read title / HTML under the player.
  bool _scrollPage(int direction) {
    if (!_scrollCtrl.hasClients) return false;
    final position = _scrollCtrl.position;
    if (!position.hasContentDimensions) return false;
    final viewport = position.viewportDimension;
    final step = viewport.isFinite && viewport > 80 ? viewport * 0.55 : 280.0;
    final next = (position.pixels + step * direction)
        .clamp(0.0, position.maxScrollExtent);
    if ((next - position.pixels).abs() < 1) return false;
    position.animateTo(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    return true;
  }

  bool _onPlayerRemote(RemoteAction action, KeyEvent event) {
    if (event is KeyUpEvent) return false;
    if (!_hasPlayer && !_showTransport) {
      // Still resolving / initializing: remember a Play press so the user's
      // action is not lost while the loading state is on screen.
      if (action == RemoteAction.playPause &&
          event is KeyDownEvent &&
          (_isVideoLoading || _initInFlight)) {
        _playWhenReady = true;
        return true;
      }
      return false;
    }

    final wasHidden = _showTransport && !_chrome;
    if (_showTransport &&
        (action == RemoteAction.select ||
            action == RemoteAction.up ||
            action == RemoteAction.down ||
            action == RemoteAction.left ||
            action == RemoteAction.right ||
            action == RemoteAction.playPause)) {
      _revealChrome();
    }

    if (action == RemoteAction.back && _fullscreen) {
      if (event is KeyDownEvent) {
        setState(() => _fullscreen = false);
      }
      return true;
    }

    if (!_hasPlayer) return false;

    switch (action) {
      case RemoteAction.playPause:
        if (event is KeyDownEvent) _togglePlayPause();
        return true;
      case RemoteAction.rewind:
        if (event is KeyDownEvent) _seekBy(const Duration(seconds: -10));
        return true;
      case RemoteAction.fastForward:
        if (event is KeyDownEvent) _seekBy(const Duration(seconds: 10));
        return true;
      case RemoteAction.skipBack:
        if (event is KeyDownEvent) _seekBy(const Duration(minutes: -10));
        return true;
      case RemoteAction.skipForward:
        if (event is KeyDownEvent) _seekBy(const Duration(minutes: 10));
        return true;
      case RemoteAction.select:
        if (event is! KeyDownEvent) return true;
        // Single OK: reveal (if needed) and fire the focused control.
        if (wasHidden) {
          // Focus lands on play after reveal; run play on this same press.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _activateFocusedControl(preferPlayIfNone: true);
          });
          return true;
        }
        _activateFocusedControl(preferPlayIfNone: true);
        return true;
      case RemoteAction.left:
      case RemoteAction.right:
      case RemoteAction.up:
      case RemoteAction.down:
        if (wasHidden) return true;
        // Chrome hidden: Up/Down still scroll the description under the video.
        if (!_chrome) {
          if (action == RemoteAction.down) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              _scrollPage(1);
            }
            return true;
          }
          if (action == RemoteAction.up) {
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              _scrollPage(-1);
            }
            return true;
          }
          return true;
        }
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return true;
        final dir = switch (action) {
          RemoteAction.left => TraversalDirection.left,
          RemoteAction.right => TraversalDirection.right,
          RemoteAction.up => TraversalDirection.up,
          _ => TraversalDirection.down,
        };
        return _moveTransport(dir);
      default:
        return false;
    }
  }

  void _revealChrome({FocusNode? preferFocus}) {
    _chromeTimer?.cancel();
    final wasHidden = !_chrome;
    _chrome = true;
    _chromeArmed = true;
    if (wasHidden && mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chrome) return;
        final target = preferFocus ?? _playFocus;
        if (target.canRequestFocus) target.requestFocus();
      });
    }
    _chromeTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || !_chrome) return;
      setState(() => _chrome = false);
    });
  }

  void _openEmbed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebViewScreen(
          url: widget.post.videoUrl!,
          title: widget.post.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showTransport && !_chromeArmed) {
      _chromeArmed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealChrome();
      });
    }

    final size = MediaQuery.sizeOf(context);
    final screenH = size.height;
    final screenW = size.width;
    // Poster band: 16:9 of the width, capped so the title stays on screen.
    // On a 16:9 TV the cap wins, which is why the artwork inside is contained
    // rather than cover-cropped.
    final posterH = (screenW * 9 / 16).clamp(200.0, screenH * 0.55);

    if (_fullscreen && _showTransport) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: _buildPlayerStack()),
      );
    }

    final dateStr = widget.post.date != null
        ? DateFormat('MMMM d, yyyy').format(widget.post.date!)
        : '';

    final playing = _showTransport;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            expandedHeight: playing
                ? (PlatformService.isTV ? screenH * 0.86 : 320)
                : posterH,
            pinned: !playing,
            toolbarHeight: playing ? 0 : kToolbarHeight,
            automaticallyImplyLeading: !playing,
            backgroundColor: playing ? Colors.black : AppTheme.bgDark,
            leading: playing
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
            flexibleSpace: FlexibleSpaceBar(
              background: playing
                  ? _buildPlayerStack()
                  : ExcludeFocus(child: _buildHeaderMedia()),
            ),
          ),
          SliverToBoxAdapter(
            child: ExcludeFocus(
              // While the native player is up, keep D-pad on transport —
              // never jump focus into HTML / links below.
              excluding: PlatformService.isTV && _showTransport,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.post.authorName != null) ...[
                        const Icon(Icons.person_outline,
                            color: AppTheme.textMuted, size: 14),
                        const SizedBox(width: 5),
                        Text(widget.post.authorName!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary)),
                        const SizedBox(width: 14),
                      ],
                      if (dateStr.isNotEmpty) ...[
                        const Icon(Icons.calendar_today_outlined,
                            color: AppTheme.textMuted, size: 13),
                        const SizedBox(width: 5),
                        Text(dateStr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.post.title,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 20),
                  if (widget.isLocked) ...[
                    const LockedContentBanner(),
                    const SizedBox(height: 24),
                    Stack(
                      children: [
                        Text(
                          widget.post.excerpt,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.7,
                                  ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppTheme.bgDark.withValues(alpha: 0.95),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    if (_ytController == null &&
                        _videoPlayerController == null &&
                        !_isVideoLoading &&
                        widget.post.videoUrl != null &&
                        widget.post.videoUrl!.isNotEmpty) ...[
                      if (_videoError != null) ...[
                        Text(
                          _videoError!,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          autofocus: PlatformService.isTV && !_showTransport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _retryVideo,
                          icon: const Icon(Icons.refresh_rounded, size: 24),
                          label: const Text(
                            'RETRY VIDEO',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        autofocus: PlatformService.isTV &&
                            !_showTransport &&
                            _videoError == null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openEmbed,
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            size: 24),
                        label: const Text(
                          'PLAY VIDEO',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    HtmlWidget(
                      widget.post.content,
                      textStyle: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.75,
                      ),
                      customStylesBuilder: (element) {
                        if (element.localName == 'a') {
                          return {'color': '#FF4444'};
                        }
                        if (element.localName == 'blockquote') {
                          return {
                            'border-left': '3px solid #E31212',
                            'padding-left': '16px',
                            'color': '#CCCCCC',
                          };
                        }
                        if (element.localName == 'code') {
                          return {
                            'background-color': '#111111',
                            'color': '#FF4444',
                            'font-family': 'monospace',
                          };
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_chrome) {
              _chromeTimer?.cancel();
              setState(() => _chrome = false);
            } else {
              _revealChrome();
            }
          },
          child: ExcludeFocus(child: _buildHeaderMedia()),
        ),
        if (_isBuffering && _videoPlayerController != null)
          const IgnorePointer(
            child: ColoredBox(
              color: Color(0x66000000),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
          ),
        IgnorePointer(
          ignoring: !_chrome,
          child: AnimatedOpacity(
            opacity: _chrome ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            child: ExcludeFocus(
              excluding: !_chrome,
              child: _buildChrome(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChrome() {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Actions(
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _exitFullscreenOrPop();
                    return true;
                  },
                ),
              },
              child: ListenableBuilder(
                listenable: _backFocus,
                builder: (context, _) {
                  final focused = _backFocus.hasFocus;
                  return Focus(
                    focusNode: _backFocus,
                    child: Material(
                      color: Colors.transparent,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: focused ? AppTheme.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        canRequestFocus: false,
                        onTap: _exitFullscreenOrPop,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const Spacer(),
        if (_showTransport)
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: _buildTransport(autofocusPlay: false),
          ),
      ],
    );
  }

  Widget _buildTransport({required bool autofocusPlay}) {
    final tick = _ytController ?? _videoPlayerController;
    if (tick == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: tick,
      builder: (context, _) {
        return TvTransportBar(
          isPlaying: _isPlaying,
          muted: _muted,
          position: _position,
          duration: _duration,
          autofocusPlay: autofocusPlay,
          playFocus: _playFocus,
          back10mFocus: _back10mFocus,
          back10sFocus: _back10sFocus,
          fwd10sFocus: _fwd10sFocus,
          fwd10mFocus: _fwd10mFocus,
          muteFocus: _muteFocus,
          fullscreenFocus: _fullscreenFocus,
          onPlayPause: _togglePlayPause,
          onBack10s: () => _seekBy(const Duration(seconds: -10)),
          onFwd10s: () => _seekBy(const Duration(seconds: 10)),
          onBack10m: () => _seekBy(const Duration(minutes: -10)),
          onFwd10m: () => _seekBy(const Duration(minutes: 10)),
          onMute: _toggleMute,
          onFullscreen: _toggleFullscreen,
        );
      },
    );
  }

  /// Fills the available area with the video texture while preserving AR
  /// (equivalent to BoxFit.contain). Used in both page and fullscreen modes.
  Widget _buildFittedVideo(VideoPlayerController vpc) {
    final size = vpc.value.size;
    final hasSize = size.width > 0 && size.height > 0;
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: hasSize
            ? FittedBox(
                fit: BoxFit.contain,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: VideoPlayer(vpc),
                ),
              )
            : AspectRatio(
                aspectRatio: vpc.value.aspectRatio > 0
                    ? vpc.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(vpc),
              ),
      ),
    );
  }

  Widget _buildHeaderMedia() {
    if (widget.isLocked) return _buildBackdropImage();

    if (_ytController != null) {
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                controller: _ytController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppTheme.accent,
                progressColors: const ProgressBarColors(
                  playedColor: AppTheme.accent,
                  handleColor: AppTheme.accentLight,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final vpc = _videoPlayerController;
    if (vpc != null && vpc.value.isInitialized) {
      return _buildFittedVideo(vpc);
    }

    if (_isVideoLoading) {
      return const ColoredBox(
        color: AppTheme.bgCard,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_videoError != null) {
      return ColoredBox(
        color: AppTheme.bgCard,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.textMuted, size: 48),
                const SizedBox(height: 12),
                Text(
                  _videoError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryVideo,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildBackdropImage();
  }

  Widget _buildBackdropImage() {
    if (widget.post.featuredImageUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Constrain featured art to a cinematic 16:9 crop inside the bar.
          // The header band on a 16:9 TV is wider than 16:9 once its height is
          // capped, so `cover` would crop a 16:9 still into a thin strip.
          // `contain` keeps the whole artwork visible at full band height.
          ColoredBox(
            color: AppTheme.bgCard,
            child: PosterImage(
              url: widget.post.featuredImageUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppTheme.bgDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.5, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    return const ColoredBox(
      color: AppTheme.bgCard,
      child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 64),
    );
  }
}
