import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects Android TV, Google TV, Fire TV, and smart-TV browsers.
/// Call [PlatformService.init()] once at startup before using [isTV].
class PlatformService {
  static const _channel = MethodChannel('alberto50/platform');

  static bool _isTV = false;
  static bool _initialized = false;

  /// Rebuild the app when TV mode is promoted at runtime (mis-detected box).
  static final ValueNotifier<bool> tvMode = ValueNotifier(false);

  static bool get isTV => _isTV;

  /// Turn on TV UI + remote after the first D-pad / OK from a mis-detected box.
  static void promoteToTvMode() {
    if (_isTV) return;
    _isTV = true;
    tvMode.value = true;
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const forced = bool.fromEnvironment('FORCE_TV', defaultValue: false);
    if (forced) {
      _isTV = true;
      tvMode.value = true;
      return;
    }

    try {
      if (kIsWeb) {
        final tvQuery = Uri.base.queryParameters['tv']?.toLowerCase();
        if (tvQuery == '1' || tvQuery == 'true' || tvQuery == 'yes') {
          _isTV = true;
          tvMode.value = true;
          return;
        }
        final info = await DeviceInfoPlugin().webBrowserInfo;
        _isTV = _uaIsTv(info.userAgent ?? '');
        tvMode.value = _isTV;
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await DeviceInfoPlugin().androidInfo;
        _isTV = _androidIsTv(info);
        if (!_isTV) {
          _isTV = await _androidUiModeIsTv();
        }
        tvMode.value = _isTV;
        return;
      }
    } catch (_) {
      _isTV = false;
      tvMode.value = false;
    }
  }

  static Future<bool> _androidUiModeIsTv() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getAndroidTvHints');
      if (raw == null) return false;
      if (raw['uiModeTelevision'] == true) return true;
      if (raw['leanbackLauncher'] == true && raw['hasTouchscreen'] != true) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool _androidIsTv(AndroidDeviceInfo info) {
    final features = info.systemFeatures;
    if (features.contains('android.software.leanback') ||
        features.contains('android.hardware.type.television')) {
      return true;
    }
    // TV boxes and Fire TV sticks often ship without a touchscreen.
    if (!features.contains('android.hardware.touchscreen')) return true;

    final haystack =
        '${info.brand} ${info.manufacturer} ${info.model} ${info.device} ${info.product} ${info.hardware} ${info.board} ${info.fingerprint}'
            .toLowerCase();
    const markers = [
      'aft',
      'firetv',
      'fire tv',
      'bravia',
      'android tv',
      'google tv',
      'mitv',
      'chromecast',
      'leanback',
      'tvbox',
      'tv box',
      'tvstick',
      'tv stick',
      'atv',
      'shield',
      'vidaa',
      'roku',
      'vizio',
      'mi box',
      'mibox',
      'nexus player',
      'adt-',
      'amlogic',
      'droidlogic',
      'rockchip',
      'allwinner',
      'x96',
      'x88',
      'mxq',
      't95',
      'h96',
      'hk1',
      'tanix',
      'mecool',
      'beelink',
      'ugoos',
      'minix',
      'nexbox',
      'a95x',
      'transpeed',
      'pendoo',
      'magicsee',
      'vontar',
      'km8',
      'km9',
      'tx3',
      'tx6',
      'tx9',
      's905',
      's912',
      'rk3328',
      'rk3566',
      'rk3588',
      'ott-box',
      'ottbox',
      'androidbox',
    ];
    if (markers.any(haystack.contains)) return true;

    final noPhone = !features.contains('android.hardware.telephony');
    final hdmi = features.contains('android.hardware.hdmi.cec') ||
        features.contains('android.hardware.hdmi');
    if (noPhone && hdmi) return true;
    return false;
  }

  static bool _uaIsTv(String ua) {
    final value = ua.toLowerCase();
    const markers = [
      'smart-tv',
      'smarttv',
      'googletv',
      'appletv',
      'hbbtv',
      'netcast',
      'nettv',
      'tizen',
      'web0s',
      'webos',
      'bravia',
      'viera',
      'aftb',
      'aftt',
      'aftm',
      'afts',
      'aftn',
      'firetv',
      'silk',
      'crkey',
      'android tv',
      'google tv',
      'large screen',
      'tizen',
      'vidaa',
      'hisense',
      'tcl/',
      'roku',
      'vizio',
      'philips tv',
      'nettv',
      'opera tv',
      'operatv',
      'webtv',
      'xbox',
      'playstation',
      'nintendo',
      'vestel',
      'foxxum',
      'zeasn',
      'coast',
      'lg browser',
      'webos.tv',
      'sonycei',
    ];
    return markers.any(value.contains);
  }
}
