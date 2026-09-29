import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';

Widget buildWebIframe({required Key key, required String url}) {
  return HtmlElementView.fromTagName(
    key: key,
    tagName: 'iframe',
    onElementCreated: (element) => _configureIframe(element, url),
  );
}

void _configureIframe(Object element, String url) {
  final iframe = element as JSObject;
  iframe.setProperty('src'.toJS, url.toJS);
  final style = iframe.getProperty('style'.toJS) as JSObject;
  style.setProperty('border'.toJS, 'none'.toJS);
  style.setProperty('width'.toJS, '100%'.toJS);
  style.setProperty('height'.toJS, '100%'.toJS);
  style.setProperty('backgroundColor'.toJS, '#0A0A0A'.toJS);
}
