import 'package:flutter/services.dart';
import 'remote_keys.dart';

/// The open video screen registers here so the global TV remote binder
/// can play/pause and seek instead of moving poster focus.
class TvPlayerRemote {
  static bool Function(RemoteAction action, KeyEvent event)? _handler;

  static void register(bool Function(RemoteAction action, KeyEvent event) handler) {
    _handler = handler;
  }

  static void unregister(
    bool Function(RemoteAction action, KeyEvent event) handler,
  ) {
    if (_handler == handler) _handler = null;
  }

  static bool dispatch(RemoteAction action, KeyEvent event) {
    final handler = _handler;
    if (handler == null) return false;
    return handler(action, event);
  }
}

/// Home shell registers so Left from posters always reaches the side rail,
/// even when focus-scope geometry cannot find it.
class TvRailRemote {
  static void Function()? _focusRail;

  static void register(void Function() focusRail) {
    _focusRail = focusRail;
  }

  static void unregister(void Function() focusRail) {
    if (identical(_focusRail, focusRail)) _focusRail = null;
  }

  static bool moveToRail() {
    final cb = _focusRail;
    if (cb == null) return false;
    cb();
    return true;
  }
}

/// A screen that is not the video player (membership, checkout) can claim
/// remote keys before poster focus runs. The top-most registration wins.
class TvPageKeys {
  static final List<bool Function(RemoteAction action, KeyEvent event)>
      _stack = [];

  static void register(
    bool Function(RemoteAction action, KeyEvent event) handler,
  ) {
    _stack.remove(handler);
    _stack.add(handler);
  }

  static void unregister(
    bool Function(RemoteAction action, KeyEvent event) handler,
  ) {
    _stack.remove(handler);
  }

  static bool dispatch(RemoteAction action, KeyEvent event) {
    if (_stack.isEmpty) return false;
    return _stack.last(action, event);
  }
}
