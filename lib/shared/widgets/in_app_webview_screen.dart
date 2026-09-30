import 'dart:async';
import 'dart:convert';

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

class _InAppWebViewScreenState extends State<InAppWebViewScreen>
    with TextInputClient {
  WebViewController? _controller;
  int _progress = 0;
  bool _hasError = false;
  int _iframeGeneration = 0;

  /// Free / Premium checkout only. 0 = back, 1 = refresh, 2+ = web control.
  final FocusNode _pageFocus = FocusNode(skipTraversal: true);
  final FocusNode _backFocus = FocusNode();
  final FocusNode _refreshFocus = FocusNode();
  int _slot = 0;
  int _moveGen = 0;
  int _navSeq = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  static const Duration _moveGuard = Duration(milliseconds: 110);
  DateTime _lastMoveAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _heldSince;
  DateTime _lastActivateAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _editClosedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _blockRoutePop = false;
  bool _editing = false;
  TextInputConnection? _ime;
  TextEditingValue? _imeValue;

  bool get _planCheckout {
    return widget.url.toLowerCase().contains('membership-checkout');
  }

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
    _stopEditing();
    _pageFocus.dispose();
    _backFocus.dispose();
    _refreshFocus.dispose();
    super.dispose();
  }

  bool _skipMove(KeyEvent event) {
    if (event is KeyRepeatEvent) {
      final held = _heldSince;
      if (held == null) return true;
      if (DateTime.now().difference(held) < const Duration(milliseconds: 320)) {
        return true;
      }
      return DateTime.now().difference(_lastMoveAt) <
          const Duration(milliseconds: 140);
    }
    if (event is KeyDownEvent &&
        DateTime.now().difference(_lastMoveAt) < _moveGuard) {
      return true;
    }
    return false;
  }

  bool _onPageKeys(RemoteAction action, KeyEvent event) {
    if (!_planCheckout) {
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

    if (_editing) return _onEditKey(action, event);

    final isMove = action == RemoteAction.up ||
        action == RemoteAction.down ||
        action == RemoteAction.left ||
        action == RemoteAction.right;
    if (isMove) {
      if (event is KeyUpEvent) return false;
      if (_skipMove(event)) return true;
      if (event is KeyDownEvent) _heldSince = DateTime.now();
      _lastMoveAt = DateTime.now();
      final dir = switch (action) {
        RemoteAction.up => 'up',
        RemoteAction.down => 'down',
        RemoteAction.left => 'left',
        RemoteAction.right => 'right',
        _ => 'down',
      };
      _movePlan(dir);
      return true;
    }

    if (action == RemoteAction.back) {
      if (event is! KeyDownEvent) return true;
      if (DateTime.now().difference(_editClosedAt) <
          const Duration(milliseconds: 280)) {
        _blockRoutePop = true;
        return true;
      }
      _popRoute();
      return true;
    }

    if (action == RemoteAction.select) {
      if (event is! KeyDownEvent) return true;
      if (DateTime.now().difference(_lastActivateAt) < _moveGuard) return true;
      _lastActivateAt = DateTime.now();
      if (_slot <= 1) return false;
      _activateWeb();
      return true;
    }
    return false;
  }

  bool _onEditKey(RemoteAction action, KeyEvent event) {
    if (action == RemoteAction.back) {
      if (event is! KeyDownEvent) return true;
      _stopEditing();
      _editClosedAt = DateTime.now();
      _blockRoutePop = true;
      return true;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return true;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _deleteChar();
      return true;
    }
    if (action == RemoteAction.select &&
        event.logicalKey == LogicalKeyboardKey.space) {
      _insertChar(' ');
      return true;
    }
    if (action == RemoteAction.select) {
      if (event is KeyDownEvent) _stopEditing();
      return true;
    }
    if (action == RemoteAction.up ||
        action == RemoteAction.down ||
        action == RemoteAction.left ||
        action == RemoteAction.right) {
      return true;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty && ch != '\n' && ch != '\r') {
      _insertChar(ch);
      return true;
    }
    return true;
  }

  void _movePlan(String dir) {
    final back = dir == 'up' || dir == 'left';
    if (_slot == 0) {
      if (back) {
        _nav('window.__tvNav.scrollByDir(-1)');
      } else {
        _slot = 1;
        _refreshFocus.requestFocus();
        _nav('window.__tvNav.clearMark()');
      }
      return;
    }
    if (_slot == 1) {
      if (back) {
        _slot = 0;
        _backFocus.requestFocus();
        _nav('window.__tvNav.scrollToTop()');
      } else {
        _slot = 2;
        _pageFocus.requestFocus();
        _applyWeb(0);
      }
      return;
    }
    _moveWeb(dir);
  }

  Future<void> _moveWeb(String dir) async {
    final gen = ++_moveGen;
    final from = _slot - 2;
    var res = await _nav('window.__tvNav.focusDir("$dir",$from)');
    if (!mounted || gen != _moveGen) return;
    if (res['kind'] == 'err') {
      await _installPlanNav();
      if (!mounted || gen != _moveGen) return;
      res = await _nav('window.__tvNav.focusDir("$dir",$from)');
      if (!mounted || gen != _moveGen) return;
    }
    final kind = res['kind']?.toString() ?? 'err';
    if (kind == 'edge') {
      if (dir == 'up' || dir == 'left') {
        _slot = 1;
        _refreshFocus.requestFocus();
        await _nav('window.__tvNav.clearMark()');
        await _nav('window.__tvNav.scrollToTop()');
      } else {
        await _nav('window.__tvNav.scrollKeepingFocus(1)');
      }
      return;
    }
    if (kind == 'err') {
      _scrollPage(dir == 'up' ? -520 : 520);
      return;
    }
    final index = (res['index'] as num?)?.toInt();
    if (index != null && index >= 0) _slot = index + 2;
    _pageFocus.requestFocus();
  }

  Future<void> _applyWeb(int index) async {
    final gen = ++_moveGen;
    var res = await _nav('window.__tvNav.focusIndex($index)');
    if (!mounted || gen != _moveGen) return;
    if (res['kind'] == 'err') {
      await _installPlanNav();
      if (!mounted || gen != _moveGen) return;
      res = await _nav('window.__tvNav.focusIndex($index)');
      if (!mounted || gen != _moveGen) return;
    }
    final kind = res['kind']?.toString() ?? 'err';
    if (kind == 'edge') {
      final count = (res['count'] as num?)?.toInt() ?? 0;
      if (count <= 0) {
        _slot = 0;
        _backFocus.requestFocus();
        await _nav('window.__tvNav.scrollByDir(1)');
        return;
      }
      final last = count - 1;
      _slot = last + 2;
      await _nav('window.__tvNav.focusIndex($last)');
      if (index > last) {
        await _nav('window.__tvNav.scrollKeepingFocus(1)');
      }
      return;
    }
    if (kind == 'err') _scrollPage(520);
  }

  Future<void> _activateWeb() async {
    final index = _slot - 2;
    final res = await _nav('window.__tvNav.activate($index)');
    if (!mounted) return;
    if (res['kind'] == 'text') _beginEdit(res);
  }

  void _beginEdit(Map<String, dynamic> info) {
    final type = (info['type'] ?? 'text').toString().toLowerCase();
    final value = (info['value'] ?? '').toString();
    _stopEditing();
    _editing = true;
    _imeValue = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    final obscure = type.contains('password');
    _ime = TextInput.attach(
      this,
      TextInputConfiguration(
        inputType: _inputTypeFor(type),
        obscureText: obscure,
        autocorrect: !obscure,
        enableSuggestions: !obscure,
        keyboardAppearance: Brightness.dark,
        inputAction: type == 'textarea'
            ? TextInputAction.newline
            : TextInputAction.done,
      ),
    );
    _ime!.setEditingState(_imeValue!);
    _ime!.show();
  }

  TextInputType _inputTypeFor(String type) {
    switch (type) {
      case 'email':
        return TextInputType.emailAddress;
      case 'tel':
        return TextInputType.phone;
      case 'number':
        return const TextInputType.numberWithOptions(signed: false);
      case 'url':
        return TextInputType.url;
      case 'textarea':
        return TextInputType.multiline;
      case 'password':
        return TextInputType.visiblePassword;
      default:
        return TextInputType.text;
    }
  }

  void _stopEditing() {
    if (!_editing && _ime == null) return;
    _editing = false;
    final conn = _ime;
    _ime = null;
    _imeValue = null;
    conn?.close();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _insertChar(String ch) {
    final current = _imeValue?.text ?? '';
    _setImeText(current + ch);
  }

  void _deleteChar() {
    final current = _imeValue?.text ?? '';
    if (current.isEmpty) return;
    _setImeText(current.substring(0, current.length - 1));
  }

  void _setImeText(String text) {
    _imeValue = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _ime?.setEditingState(_imeValue!);
    _pushWebValue(text);
  }

  void _pushWebValue(String text) {
    final controller = _controller;
    if (controller == null) return;
    final encoded = jsonEncode(text);
    controller
        .runJavaScript('window.__tvNav&&window.__tvNav.setValue($encoded);')
        .catchError((_) {});
  }

  Future<Map<String, dynamic>> _nav(String call) {
    final controller = _controller;
    if (controller == null) return Future.value({'kind': 'err'});
    final id = ++_navSeq;
    final done = Completer<Map<String, dynamic>>();
    _pending[id] = done;
    controller.runJavaScript('''
try {
  var __r = $call;
  if (!__r) __r = {kind:"err"};
  __r.id = $id;
  TvNav.postMessage(JSON.stringify(__r));
} catch (e) {
  TvNav.postMessage(JSON.stringify({id:$id,kind:"err"}));
}
''').catchError((_) {
      final pending = _pending.remove(id);
      if (pending != null && !pending.isCompleted) {
        pending.complete({'kind': 'err'});
      }
    });
    return done.future.timeout(const Duration(milliseconds: 600), onTimeout: () {
      _pending.remove(id);
      return {'kind': 'err'};
    });
  }

  void _onNavMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final id = (decoded['id'] as num?)?.toInt();
      if (id == null) return;
      final pending = _pending.remove(id);
      if (pending != null && !pending.isCompleted) {
        pending.complete(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<void> _installPlanNav({bool focusFirst = false}) async {
    if (!_planCheckout) return;
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript(_planNavJs);
    } catch (_) {
      return;
    }
    if (!focusFirst || !mounted) return;
    _slot = 2;
    if (_pageFocus.canRequestFocus) _pageFocus.requestFocus();
    await _applyWeb(0);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _editing || _slot != 2) return;
      _applyWeb(0);
    });
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
      ..addJavaScriptChannel(
        'TvNav',
        onMessageReceived: (JavaScriptMessage message) {
          _onNavMessage(message.message);
        },
      )
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
            if (_planCheckout) _installPlanNav(focusFirst: true);
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

  bool _leaving = false;
  bool _popScheduled = false;

  void _popRoute() {
    if (!mounted || _leaving || _popScheduled) return;
    _popScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popScheduled = false;
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  void _checkRegistrationSuccess(String url) {
    final lowerUrl = url.toLowerCase();
    final confirmed = lowerUrl.contains('membership-confirmation') ||
        lowerUrl.contains('level_registered') ||
        (lowerUrl.contains('membership-account') &&
            lowerUrl.contains('success')) ||
        (lowerUrl.contains('pmpro_checkout') && lowerUrl.contains('confirm'));
    if (!confirmed || !mounted || _leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please log in.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
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
      if (_blockRoutePop) {
        _blockRoutePop = false;
        return KeyEventResult.handled;
      }
      _popRoute();
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
      focusNode: _pageFocus,
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(event),
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgCard,
          title: Text(widget.title),
          leading: IconButton(
            focusNode: _backFocus,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _popRoute,
          ),
          actions: [
            IconButton(
              focusNode: _refreshFocus,
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

  @override
  TextEditingValue? get currentTextEditingValue => _imeValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _imeValue = value;
    _pushWebValue(value.text);
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.done) _stopEditing();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    final wasEditing = _editing;
    _editing = false;
    _ime = null;
    if (wasEditing) {
      _editClosedAt = DateTime.now();
      _blockRoutePop = true;
    }
  }
}

const String _planNavJs = r'''
(function() {
  if (!window.__tvNav) window.__tvNav = {};
  function fitCheckout() {
    var form = document.getElementById('pmpro_form');
    if (!form) return {kind:'skip'};
    var page = document.getElementById('page');
    if (page) {
      var kids = page.children;
      for (var i = 0; i < kids.length; i++) {
        if (kids[i].contains(form)) continue;
        kids[i].style.setProperty('display', 'none', 'important');
      }
    }
    var extras = document.querySelectorAll('.preloader, .preloader-inner, .mouse-cursor, #back-top, .back-to-top, .offcanvas__overlay, #gtx-trans');
    for (var j = 0; j < extras.length; j++) {
      extras[j].style.setProperty('display', 'none', 'important');
    }
    var style = document.getElementById('tv-checkout-style');
    if (!style) {
      style = document.createElement('style');
      style.id = 'tv-checkout-style';
      (document.head || document.documentElement).appendChild(style);
    }
    style.textContent = 'html,body,#page,.site{background:#0A0A0A!important;color:#F4F4F4!important;}'
      + '.pmpro{max-width:880px;margin:12px auto 48px;padding:8px 28px 36px;}'
      + '.pmpro_card{background:#141414!important;border:1px solid #2C2C2C!important;border-radius:14px!important;color:#F4F4F4!important;box-shadow:none!important;}'
      + '.pmpro_card_title{color:#fff!important;font-size:28px!important;}'
      + '.pmpro_level_name_text,.pmpro_level_cost_text,.pmpro_card_content p,.pmpro_card_actions{color:#E8E8E8!important;font-size:22px!important;line-height:1.4!important;}'
      + '.pmpro_card_actions a{color:#FF6B6B!important;font-size:22px!important;}'
      + '.pmpro_form_label{color:#fff!important;font-size:22px!important;display:block!important;margin-bottom:8px!important;}'
      + '.pmpro_cols-2{display:flex!important;flex-direction:column!important;gap:8px!important;}'
      + '.pmpro_form_field{width:100%!important;margin:0 0 18px!important;float:none!important;}'
      + '.pmpro_form_input,.pmpro input[type="text"],.pmpro input[type="password"],.pmpro input[type="email"],.pmpro select{background:#0E0E0E!important;color:#fff!important;border:2px solid #3A3A3A!important;border-radius:10px!important;min-height:64px!important;height:64px!important;max-height:64px!important;font-size:26px!important;width:100%!important;max-width:100%!important;padding:14px 18px!important;box-sizing:border-box!important;}'
      + '.pmpro_btn-submit-checkout,#pmpro_btn-submit{background:#E31212!important;color:#fff!important;border:none!important;border-radius:12px!important;min-height:72px!important;width:100%!important;font-size:26px!important;font-weight:700!important;margin-top:8px!important;}'
      + '.pmpro_form_field-password-toggle{margin-top:8px!important;}'
      + '.pmpro_btn-password-toggle{color:#fff!important;font-size:20px!important;background:transparent!important;}'
      + '.pmpro_form_fields-inline{display:flex!important;flex-direction:column!important;align-items:stretch!important;gap:12px!important;}'
      + '.pmpro_form_fields-inline select{flex:none!important;width:100%!important;min-width:0!important;max-width:100%!important;}'
      + '#pmpro_form select{display:block!important;visibility:visible!important;opacity:1!important;position:relative!important;clip:auto!important;clip-path:none!important;overflow:hidden!important;height:64px!important;min-height:64px!important;max-height:64px!important;margin:0!important;}'
      + '#pmpro_form .select2-container,#pmpro_form .select2-dropdown,#pmpro_form .nice-select{display:none!important;}'
      + '.pmpro select,.pmpro select option,.pmpro input,.pmpro textarea{color:#fff!important;-webkit-text-fill-color:#fff!important;opacity:1!important;}'
      + '.tv-focus{border:3px solid #E31212!important;box-shadow:0 0 0 4px rgba(227,18,18,.45)!important;}';
    document.documentElement.style.background = '#0A0A0A';
    if (document.body) document.body.style.background = '#0A0A0A';
    window.scrollTo(0, 0);
    return {kind:'ok'};
  }
  function plainSelects() {
    var form = document.getElementById('pmpro_form');
    if (!form) return;
    if (window.jQuery && jQuery.fn && jQuery.fn.select2) {
      try {
        jQuery(form).find('select').each(function() {
          var $el = jQuery(this);
          if ($el.hasClass('select2-hidden-accessible') || $el.data('select2')) {
            try { $el.select2('destroy'); } catch (e) {}
          }
        });
      } catch (e) {}
    }
    var extras = form.querySelectorAll('.select2-container, .select2-dropdown, .nice-select');
    for (var i = 0; i < extras.length; i++) {
      if (extras[i].parentNode) extras[i].parentNode.removeChild(extras[i]);
    }
    var selects = form.querySelectorAll('select');
    for (var s = 0; s < selects.length; s++) {
      var el = selects[s];
      el.disabled = false;
      el.removeAttribute('aria-hidden');
      el.removeAttribute('tabindex');
      el.classList.remove('select2-hidden-accessible');
      el.style.setProperty('display', 'block', 'important');
      el.style.setProperty('visibility', 'visible', 'important');
      el.style.setProperty('opacity', '1', 'important');
      el.style.setProperty('position', 'relative', 'important');
      el.style.setProperty('clip', 'auto', 'important');
      el.style.setProperty('clip-path', 'none', 'important');
      el.style.setProperty('width', '100%', 'important');
      el.style.setProperty('height', '64px', 'important');
      el.style.setProperty('min-height', '64px', 'important');
      el.style.setProperty('max-height', '64px', 'important');
      el.style.setProperty('overflow', 'hidden', 'important');
      el.style.setProperty('margin', '0', 'important');
    }
  }
  window.__tvNav.fitCheckout = fitCheckout;
  window.__tvNav.plainSelects = plainSelects;
  fitCheckout();
  plainSelects();
  setTimeout(function() { fitCheckout(); plainSelects(); }, 250);
  setTimeout(function() { fitCheckout(); plainSelects(); }, 900);
  setTimeout(plainSelects, 1800);
  function collect() {
    plainSelects();
    var root = document.getElementById('pmpro_form') || document;
    var sel = 'a[href], button, input, textarea, select, summary, [role="button"], [role="link"], [role="checkbox"], [role="radio"], [role="switch"], [role="tab"]';
    var nodes = root.querySelectorAll(sel);
    var list = [];
    for (var i = 0; i < nodes.length; i++) {
      if (visible(nodes[i])) list.push(nodes[i]);
    }
    list.sort(function(a, b) {
      var ra = a.getBoundingClientRect();
      var rb = b.getBoundingClientRect();
      if (Math.abs(ra.top - rb.top) > 14) return ra.top - rb.top;
      return ra.left - rb.left;
    });
    return list;
  }
  function visible(el) {
    if (!el) return false;
    var tag = el.tagName;
    var keepDisabled = tag === 'SELECT' || tag === 'INPUT' || tag === 'TEXTAREA';
    if (el.disabled && !keepDisabled) return false;
    if (el.tagName === 'INPUT' && String(el.type || '').toLowerCase() === 'hidden') return false;
    if (el.getAttribute('aria-hidden') === 'true') return false;
    var st = window.getComputedStyle(el);
    if (!st || st.display === 'none' || st.visibility === 'hidden' || parseFloat(st.opacity || '1') === 0) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    if (r.right < 0) return false;
    return true;
  }
  function kindOf(el) {
    var tag = el.tagName;
    if (tag === 'TEXTAREA') return 'text';
    if (tag === 'SELECT') return 'choice';
    if (tag === 'INPUT') {
      var t = String(el.type || 'text').toLowerCase();
      if (t === 'checkbox' || t === 'radio' || t === 'button' || t === 'submit' || t === 'reset' || t === 'image' || t === 'file' || t === 'range' || t === 'color') return 'click';
      if (t === 'date' || t === 'time' || t === 'datetime-local' || t === 'month' || t === 'week') return 'choice';
      if (t === 'hidden') return 'skip';
      return 'text';
    }
    return 'click';
  }
  function unmark(el) {
    if (!el || !el.getAttribute) return;
    if (el.getAttribute('data-tv-mark') !== '1') return;
    el.style.outline = el.getAttribute('data-tv-outline') || '';
    el.style.outlineOffset = el.getAttribute('data-tv-offset') || '';
    el.style.borderColor = el.getAttribute('data-tv-border') || '';
    el.style.boxShadow = el.getAttribute('data-tv-shadow') || '';
    if (el.classList) el.classList.remove('tv-focus');
    el.removeAttribute('data-tv-mark');
  }
  function mark(el) {
    if (window.__tvCur && window.__tvCur !== el) unmark(window.__tvCur);
    window.__tvCur = el;
    if (el.getAttribute('data-tv-mark') !== '1') {
      el.setAttribute('data-tv-outline', el.style.outline || '');
      el.setAttribute('data-tv-offset', el.style.outlineOffset || '');
      el.setAttribute('data-tv-border', el.style.borderColor || '');
      el.setAttribute('data-tv-shadow', el.style.boxShadow || '');
      el.setAttribute('data-tv-mark', '1');
    }
    if (el.classList) el.classList.add('tv-focus');
    el.style.outline = '3px solid #E31212';
    el.style.outlineOffset = '3px';
    el.style.borderColor = '#E31212';
    el.style.boxShadow = '0 0 0 4px rgba(227,18,18,.45)';
  }
  function cycleSelect(el, dir) {
    if (!el || el.tagName !== 'SELECT' || !el.options || !el.options.length) return false;
    if (el.disabled) el.disabled = false;
    var n = el.options.length;
    var i = el.selectedIndex;
    if (i < 0) i = 0;
    el.selectedIndex = dir === 'left' ? (i - 1 + n) % n : (i + 1) % n;
    try {
      el.dispatchEvent(new Event('input', {bubbles:true}));
      el.dispatchEvent(new Event('change', {bubbles:true}));
    } catch (e) {}
    return true;
  }
  function focusResult(list, i) {
    mark(list[i]);
    reveal(list[i]);
    return {kind:kindOf(list[i]), count:list.length, index:i};
  }
  function rootScroller() {
    return document.scrollingElement || document.documentElement || document.body;
  }
  function bestScroller() {
    var root = rootScroller();
    var best = root;
    var bestRoom = root.scrollHeight - root.clientHeight;
    var nodes = document.querySelectorAll('div, main, section, article, form');
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      var room = n.scrollHeight - n.clientHeight;
      if (room > bestRoom + 80 && n.clientHeight > 120) {
        best = n;
        bestRoom = room;
      }
    }
    return best;
  }
  function isRoot(sc, root) {
    return sc === root || sc === document.body || sc === document.documentElement;
  }
  function scrollByDy(dy) {
    if (!dy) return;
    var root = rootScroller();
    var sc = bestScroller();
    if (isRoot(sc, root)) {
      var y = window.pageYOffset || root.scrollTop || 0;
      window.scrollTo(window.pageXOffset || 0, y + dy);
    } else {
      sc.scrollTop = sc.scrollTop + dy;
    }
  }
  function reveal(el) {
    var margin = 20;
    for (var guard = 0; guard < 5; guard++) {
      var rect = el.getBoundingClientRect();
      var vh = window.innerHeight || document.documentElement.clientHeight || 0;
      var vw = window.innerWidth || document.documentElement.clientWidth || 0;
      var dy = 0;
      var dx = 0;
      if (rect.height > vh * 0.85) {
        if (rect.top < margin || rect.top > vh - 80) dy = rect.top - margin;
      } else if (rect.top < margin) {
        dy = rect.top - margin;
      } else if (rect.bottom > vh - margin) {
        dy = rect.bottom - (vh - margin);
      }
      if (rect.left < margin) dx = rect.left - margin;
      else if (rect.right > vw - margin) dx = rect.right - (vw - margin);
      if (Math.abs(dy) < 2 && Math.abs(dx) < 2) return;
      var root = rootScroller();
      var sc = bestScroller();
      var beforeY = isRoot(sc, root) ? (window.pageYOffset || root.scrollTop || 0) : sc.scrollTop;
      if (Math.abs(dy) >= 2) {
        if (isRoot(sc, root)) window.scrollTo(window.pageXOffset || 0, beforeY + dy);
        else sc.scrollTop = beforeY + dy;
      }
      if (Math.abs(dx) >= 2) {
        if (isRoot(sc, root)) window.scrollTo((window.pageXOffset || 0) + dx, window.pageYOffset || 0);
        else sc.scrollLeft = sc.scrollLeft + dx;
      }
      var afterY = isRoot(sc, root) ? (window.pageYOffset || root.scrollTop || 0) : sc.scrollTop;
      if (afterY === beforeY && Math.abs(dy) >= 2) return;
    }
  }
  window.__tvNav.clearMark = function() {
    unmark(window.__tvCur);
    window.__tvCur = null;
    return {kind:'ok', count:collect().length};
  };
  window.__tvNav.scrollToTop = function() {
    var root = rootScroller();
    window.scrollTo(0, 0);
    root.scrollTop = 0;
    var sc = bestScroller();
    if (sc && sc !== root) sc.scrollTop = 0;
    return {kind:'scroll', count:collect().length};
  };
  window.__tvNav.scrollByDir = function(dir) {
    var vh = window.innerHeight || 600;
    scrollByDy(Math.round(vh * 0.72) * (dir < 0 ? -1 : 1));
    return {kind:'scroll', count:collect().length};
  };
  window.__tvNav.focusIndex = function(i) {
    var list = collect();
    if (i < 0 || i >= list.length) return {kind:'edge', count:list.length, index:-1};
    return focusResult(list, i);
  };
  window.__tvNav.focusDir = function(dir, fromIndex) {
    var list = collect();
    var cur = (fromIndex >= 0 && fromIndex < list.length) ? list[fromIndex] : window.__tvCur;
    if (!cur) {
      if (!list.length) return {kind:'edge', count:0, index:-1};
      return focusResult(list, 0);
    }
    if ((dir === 'left' || dir === 'right') && cur.tagName === 'SELECT' && cycleSelect(cur, dir)) {
      mark(cur);
      var kept = list.indexOf(cur);
      return {kind:'choice', count:list.length, index:kept < 0 ? fromIndex : kept};
    }
    var cr = cur.getBoundingClientRect();
    var cx = cr.left + cr.width / 2;
    var cy = cr.top + cr.height / 2;
    var best = -1;
    var bestScore = 1e15;
    for (var i = 0; i < list.length; i++) {
      if (list[i] === cur) continue;
      var r = list[i].getBoundingClientRect();
      var x = r.left + r.width / 2;
      var y = r.top + r.height / 2;
      var dx = x - cx;
      var dy = y - cy;
      if (dir === 'down' && dy < 12) continue;
      if (dir === 'up' && dy > -12) continue;
      if (dir === 'right' && dx < 12) continue;
      if (dir === 'left' && dx > -12) continue;
      var primary = (dir === 'up' || dir === 'down') ? Math.abs(dy) : Math.abs(dx);
      var secondary = (dir === 'up' || dir === 'down') ? Math.abs(dx) : Math.abs(dy);
      if ((dir === 'left' || dir === 'right') && secondary > Math.max(cr.height, r.height)) continue;
      var score = primary + secondary * 1.6;
      if (score < bestScore) { bestScore = score; best = i; }
    }
    if (best < 0) {
      if ((dir === 'left' || dir === 'right') && cur.tagName === 'SELECT' && cycleSelect(cur, dir)) {
        mark(cur);
        var idx = list.indexOf(cur);
        return {kind:'choice', count:list.length, index:idx < 0 ? fromIndex : idx};
      }
      return {kind:'edge', count:list.length, index:fromIndex};
    }
    return focusResult(list, best);
  };
  window.__tvNav.scrollKeepingFocus = function(dir) {
    var el = window.__tvCur;
    var vh = window.innerHeight || 600;
    var root = rootScroller();
    var sc = bestScroller();
    var y = isRoot(sc, root) ? (window.pageYOffset || root.scrollTop || 0) : sc.scrollTop;
    var max = isRoot(sc, root) ? Math.max(0, root.scrollHeight - root.clientHeight) : Math.max(0, sc.scrollHeight - sc.clientHeight);
    if (!el) {
      scrollByDy((dir < 0 ? -1 : 1) * Math.round(vh * 0.72));
      return {kind:'scroll'};
    }
    var rect = el.getBoundingClientRect();
    var margin = 20;
    var dy = 0;
    if (dir > 0) dy = Math.min(Math.max(0, rect.top - margin), Math.max(0, max - y));
    else dy = -Math.min(Math.max(0, (vh - margin) - rect.bottom), y);
    if (Math.abs(dy) < 2) return {kind:'scroll'};
    scrollByDy(dy);
    return {kind:'scroll'};
  };
  window.__tvNav.activate = function(index) {
    var list = collect();
    var el = (index >= 0 && index < list.length) ? list[index] : window.__tvCur;
    if (!el) return {kind:'none', count:list.length};
    mark(el);
    var k = kindOf(el);
    if (k === 'text') {
      var type = el.tagName === 'TEXTAREA' ? 'textarea' : String(el.type || 'text');
      return {kind:'text', type:type, value:el.value || '', count:list.length, index:index};
    }
    if (k === 'choice' && el.tagName === 'SELECT') {
      cycleSelect(el, 'right');
      return {kind:'choice', count:list.length, index:index};
    }
    try { el.focus({preventScroll:true}); } catch (e1) { try { el.focus(); } catch (e2) {} }
    el.click();
    return {kind:k, count:list.length, index:index};
  };
  window.__tvNav.setValue = function(v) {
    var el = window.__tvCur;
    if (!el) return;
    if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') el.value = v;
    else if (el.isContentEditable) el.textContent = v;
    try {
      el.dispatchEvent(new Event('input', {bubbles:true}));
      el.dispatchEvent(new Event('change', {bubbles:true}));
    } catch (e) {}
  };
})();
''';
