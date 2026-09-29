import 'package:flutter/services.dart';

/// Directions and buttons shared by TV remotes.
///
/// Android TV, Google TV, Fire TV, and TV browsers do not all send the same
/// key codes. This maps those variants onto one set of actions.
enum RemoteAction {
  up,
  down,
  left,
  right,
  select,
  back,
  playPause,
  rewind,
  fastForward,
  skipBack,
  skipForward,
  mouseToggle,
  none,
}

class RemoteKeys {
  static RemoteAction actionOf(KeyEvent event) {
    final logical = event.logicalKey;
    final physical = event.physicalKey;

    if (_isUp(logical, physical)) return RemoteAction.up;
    if (_isDown(logical, physical)) return RemoteAction.down;
    if (_isLeft(logical, physical)) return RemoteAction.left;
    if (_isRight(logical, physical)) return RemoteAction.right;
    if (_isPlayPause(logical)) return RemoteAction.playPause;
    if (_isRewind(logical)) return RemoteAction.rewind;
    if (_isFastForward(logical)) return RemoteAction.fastForward;
    if (_isSkipBack(logical)) return RemoteAction.skipBack;
    if (_isSkipForward(logical)) return RemoteAction.skipForward;
    if (_isMouseToggle(logical, physical, event)) {
      return RemoteAction.mouseToggle;
    }
    if (_isSelect(logical)) return RemoteAction.select;
    if (_isBack(logical)) return RemoteAction.back;

    final android = _androidKeyCode(event);
    if (android != null) {
      switch (android) {
        case 19: // KEYCODE_DPAD_UP
          return RemoteAction.up;
        case 20: // KEYCODE_DPAD_DOWN
          return RemoteAction.down;
        case 21: // KEYCODE_DPAD_LEFT
          return RemoteAction.left;
        case 22: // KEYCODE_DPAD_RIGHT
          return RemoteAction.right;
        case 23: // KEYCODE_DPAD_CENTER
        case 66: // KEYCODE_ENTER
        case 160: // KEYCODE_NUMPAD_ENTER
        case 96: // KEYCODE_BUTTON_A
          return RemoteAction.select;
        case 4: // KEYCODE_BACK
        case 111: // KEYCODE_ESCAPE
        case 97: // KEYCODE_BUTTON_B
          return RemoteAction.back;
        case 85: // KEYCODE_MEDIA_PLAY_PAUSE
        case 86: // KEYCODE_MEDIA_STOP
        case 126: // KEYCODE_MEDIA_PLAY
        case 127: // KEYCODE_MEDIA_PAUSE
          return RemoteAction.playPause;
        case 89: // KEYCODE_MEDIA_REWIND
        case 273: // KEYCODE_MEDIA_SKIP_BACKWARD
          return RemoteAction.rewind;
        case 90: // KEYCODE_MEDIA_FAST_FORWARD
        case 272: // KEYCODE_MEDIA_SKIP_FORWARD
          return RemoteAction.fastForward;
        case 88: // KEYCODE_MEDIA_PREVIOUS
          return RemoteAction.skipBack;
        case 87: // KEYCODE_MEDIA_NEXT
          return RemoteAction.skipForward;
      }
    }

    if (logical == LogicalKeyboardKey.backspace) return RemoteAction.none;

    final label = '${logical.keyLabel} ${logical.debugName ?? ''}'.toLowerCase();
    if (label.contains('backspace')) return RemoteAction.none;
    if (label.contains('xf86back') ||
        label.contains('goback') ||
        label.contains('browserback') ||
        label.contains('back')) {
      return RemoteAction.back;
    }
    return RemoteAction.none;
  }

  static bool isSelect(KeyEvent event) => actionOf(event) == RemoteAction.select;

  static bool isBack(KeyEvent event) => actionOf(event) == RemoteAction.back;

  static bool isPress(KeyEvent event) =>
      event is KeyDownEvent || event is KeyRepeatEvent;

  static bool _isUp(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    return logical == LogicalKeyboardKey.arrowUp ||
        logical == LogicalKeyboardKey.numpad8 ||
        logical == LogicalKeyboardKey.channelUp ||
        logical == LogicalKeyboardKey.pageUp ||
        physical == PhysicalKeyboardKey.arrowUp ||
        physical == PhysicalKeyboardKey.numpad8;
  }

  static bool _isDown(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    return logical == LogicalKeyboardKey.arrowDown ||
        logical == LogicalKeyboardKey.numpad2 ||
        logical == LogicalKeyboardKey.channelDown ||
        logical == LogicalKeyboardKey.pageDown ||
        physical == PhysicalKeyboardKey.arrowDown ||
        physical == PhysicalKeyboardKey.numpad2;
  }

  static bool _isLeft(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    return logical == LogicalKeyboardKey.arrowLeft ||
        logical == LogicalKeyboardKey.numpad4 ||
        physical == PhysicalKeyboardKey.arrowLeft ||
        physical == PhysicalKeyboardKey.numpad4;
  }

  static bool _isRight(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    return logical == LogicalKeyboardKey.arrowRight ||
        logical == LogicalKeyboardKey.numpad6 ||
        physical == PhysicalKeyboardKey.arrowRight ||
        physical == PhysicalKeyboardKey.numpad6;
  }

  static bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonSelect ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.open ||
        key == LogicalKeyboardKey.accept ||
        key == LogicalKeyboardKey.execute ||
        key == LogicalKeyboardKey.numpad5;
  }

  static bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.abort ||
        key == LogicalKeyboardKey.close;
  }

  static bool _isPlayPause(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPause ||
        key == LogicalKeyboardKey.mediaStop ||
        key == LogicalKeyboardKey.mediaPlay;
  }

  static bool _isRewind(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaRewind ||
        key == LogicalKeyboardKey.mediaStepBackward;
  }

  static bool _isFastForward(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaFastForward ||
        key == LogicalKeyboardKey.mediaStepForward;
  }

  static bool _isSkipBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaTrackPrevious ||
        key == LogicalKeyboardKey.mediaSkipBackward;
  }

  static bool _isSkipForward(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.mediaTrackNext ||
        key == LogicalKeyboardKey.mediaSkipForward;
  }

  /// Dedicated Mouse / Pointer / Air-mouse keys used by many TV remotes.
  static bool _isMouseToggle(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
    KeyEvent event,
  ) {
    if (logical == LogicalKeyboardKey.f9 ||
        logical == LogicalKeyboardKey.f10 ||
        logical == LogicalKeyboardKey.f11 ||
        logical == LogicalKeyboardKey.f12 ||
        logical == LogicalKeyboardKey.insert ||
        logical == LogicalKeyboardKey.gameButtonMode ||
        physical == PhysicalKeyboardKey.f9 ||
        physical == PhysicalKeyboardKey.f10 ||
        physical == PhysicalKeyboardKey.f11 ||
        physical == PhysicalKeyboardKey.f12 ||
        physical == PhysicalKeyboardKey.insert) {
      return true;
    }

    final label =
        '${logical.keyLabel} ${logical.debugName ?? ''} ${physical.debugName ?? ''}'
            .toLowerCase();
    if (label.contains('mouse') ||
        label.contains('pointer') ||
        label.contains('airmouse') ||
        label.contains('air mouse') ||
        label.contains('air-mouse')) {
      return true;
    }

    // Android KEYCODE_F9=139, F10=140, F11=141, F12=142, BUTTON_MODE=110
    final id = logical.keyId;
    const androidExtras = {110, 139, 140, 141, 142};
    if (androidExtras.contains(id) || androidExtras.contains(id & 0xFFFF)) {
      return true;
    }
    return false;
  }

  /// Cheap TV boxes often send unmapped Android keyCodes (DPAD 19–23, etc.).
  static int? _androidKeyCode(KeyEvent event) {
    final id = event.logicalKey.keyId;
    if ((id & LogicalKeyboardKey.planeMask) != LogicalKeyboardKey.androidPlane) {
      return null;
    }
    return id & LogicalKeyboardKey.valueMask;
  }
}
