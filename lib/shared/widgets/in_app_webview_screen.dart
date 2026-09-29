import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/remote_keys.dart';
import '../../core/services/tv_player_remote.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../shared/theme/app_theme.dart';
import 'web_iframe.dart';

class InAppWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final Map<String, String>? initialUserData;

  const InAppWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Sign Up',
    this.initialUserData,
  });

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  WebViewController? _controller;
  int _progress = 0;
  bool _hasError = false;
  int _iframeGeneration = 0;

  @override
  void initState() {
    super.initState();
    TvPageKeys.register(_onPageKeys);
    if (kIsWeb) return;
    _initWebView();
  }

  @override
  void dispose() {
    TvPageKeys.unregister(_onPageKeys);
    super.dispose();
  }

  bool _onPageKeys(RemoteAction action, KeyEvent event) {
    if (event is KeyUpEvent) return false;
    switch (action) {
      case RemoteAction.down:
        _scrollPage(520);
        return true;
      case RemoteAction.up:
        _scrollPage(-520);
        return true;
      case RemoteAction.right:
        _scrollPage(0, dx: 240);
        return true;
      case RemoteAction.left:
        _scrollPage(0, dx: -240);
        return true;
      default:
        return false;
    }
  }

  void _scrollPage(int dy, {int dx = 0}) {
    final controller = _controller;
    if (controller == null) return;
    controller.runJavaScript('''
      (function() {
        var dy = $dy;
        var dx = $dx;
        function canScroll(el) {
          if (!el) return false;
          var y = el.scrollHeight > el.clientHeight + 24;
          var x = el.scrollWidth > el.clientWidth + 24;
          return y || x;
        }
        var el = document.scrollingElement || document.documentElement || document.body;
        var beforeY = el.scrollTop;
        var beforeX = el.scrollLeft;
        el.scrollBy(dx, dy);
        if (el.scrollTop === beforeY && el.scrollLeft === beforeX) {
          var nodes = document.querySelectorAll('div, main, section, article');
          for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i];
            if (!canScroll(n)) continue;
            n.scrollBy(dx, dy);
            break;
          }
        }
      })();
    ''').catchError((_) {});
  }

  void _reload() {
    final controller = _controller;
    if (controller != null) {
      controller.reload();
      return;
    }
    if (kIsWeb) setState(() => _iframeGeneration++);
  }

  Future<void> _initWebView() async {
    final targetUrl = Uri.parse(widget.url);

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.bgDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _hasError = false);
            _checkRegistrationSuccess(url);
          },
          onPageFinished: (url) async {
            _checkRegistrationSuccess(url);
            _injectAutofillScript();
            // Unmute any video/audio elements the page may have muted
            // due to browser autoplay policy, and ensure full volume.
            controller.runJavaScript('''
              (function() {
                document.querySelectorAll('video, audio').forEach(function(el) {
                  el.muted = false;
                  el.volume = 1.0;
                });
              })();
            ''').catchError((_) {});
          },
          onWebResourceError: (error) {
            debugPrint('WebView Resource Error: \${error.description}');
          },
        ),
      );

    // Allow media (including audio) to play without requiring a user gesture.
    // setMediaPlaybackRequiresUserGesture is an Android-specific WebView setting
    // that must be applied via the platform controller, not the base WebViewController.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidController =
          controller.platform as AndroidWebViewController;
      await androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    if (mounted) setState(() {});
    _clearSessionAndLoad(targetUrl);
  }

  void _clearSessionAndLoad(Uri targetUrl) async {
    try {
      final cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      await _controller?.clearCache();
      await _controller?.clearLocalStorage();
    } catch (e) {
      debugPrint('Error clearing WebView session cache: $e');
    }
    _controller?.loadRequest(targetUrl);
  }

  void _checkRegistrationSuccess(String url) {
    final lowerUrl = url.toLowerCase();
    // PMPro confirmation page URLs or query parameters
    if (lowerUrl.contains('membership-confirmation') ||
        lowerUrl.contains('level_registered') ||
        lowerUrl.contains('membership-account') && lowerUrl.contains('success') ||
        lowerUrl.contains('pmpro_checkout') && lowerUrl.contains('confirm')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please log in.'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Close web view and return to Login screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _injectAutofillScript() async {
    if (widget.initialUserData == null || widget.initialUserData!.isEmpty) return;

    final user = widget.initialUserData!;
    final username = user['username'] ?? user['user_login'] ?? '';
    final email = user['email'] ?? user['bemail'] ?? '';
    final password = user['password'] ?? '';
    final firstName = user['first_name'] ?? '';
    final lastName = user['last_name'] ?? '';

    final jsScript = '''
      (function() {
        var attempts = 0;
        function tryAutofill() {
          attempts++;
          function setVal(idNames, val) {
            if (!val) return;
            for (var i = 0; i < idNames.length; i++) {
              var nameOrId = idNames[i];
              var elements = [
                document.getElementById(nameOrId),
                document.querySelector('[name="' + nameOrId + '"]'),
                document.querySelector('input[type="password"]:nth-of-type(2)'),
                document.querySelector('input[name*="confirm"]'),
                document.querySelector('input[name*="again"]'),
                document.querySelector('input[id*="confirm"]'),
                document.querySelector('input[id*="again"]')
              ];
              for (var j = 0; j < elements.length; j++) {
                var el = elements[j];
                if (el && el.tagName === 'INPUT') {
                  el.value = val;
                  el.dispatchEvent(new Event('input', { bubbles: true }));
                  el.dispatchEvent(new Event('change', { bubbles: true }));
                  el.dispatchEvent(new Event('blur', { bubbles: true }));
                }
              }
            }
          }

          setVal(['username', 'user_login', 'log'], '$username');
          setVal(['email', 'bemail', 'bconfirmemail', 'user_email'], '$email');
          setVal(['password', 'password_1', 'pass1', 'user_pass'], '$password');
          setVal(['password_again', 'password_2', 'pass2', 'confirm_password', 'password_confirm', 'bconfirmemail', 'user_pass_confirm'], '$password');
          setVal(['first_name', 'bfirstname'], '$firstName');
          setVal(['last_name', 'blastname'], '$lastName');

          if (attempts < 10) {
            setTimeout(tryAutofill, 500);
          }
        }
        tryAutofill();
      })();
    ''';

    try {
      await _controller?.runJavaScript(jsScript);
    } catch (e) {
      debugPrint('Error injecting autofill script: $e');
    }
  }

  /// TV remote key handler: Left arrow / Back → pop; remote key → reload page.
  KeyEventResult _onKey(KeyEvent event) {
    if (!RemoteKeys.isPress(event)) return KeyEventResult.ignored;
    final action = RemoteKeys.actionOf(event);
    if (action == RemoteAction.back) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.mediaRewind ||
        event.logicalKey == LogicalKeyboardKey.f5) {
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(event),
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final controller = _controller;
    final page = kIsWeb
        ? buildWebIframe(
            key: ValueKey(_iframeGeneration),
            url: widget.url,
          )
        : controller == null
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : WebViewWidget(
                controller: controller,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<EagerGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              );

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              _scrollPage(event.scrollDelta.dy.round());
            }
          },
          child: page,
        ),
        if (!kIsWeb && _progress < 100)
          LinearProgressIndicator(
            value: _progress / 100,
            color: AppTheme.accent,
            backgroundColor: AppTheme.bgCard,
          ),
        if (_hasError)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.danger, size: 48),
                const SizedBox(height: 12),
                const Text('Failed to load page',
                    style: TextStyle(color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
