import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Pointer / air-mouse scrolling for TV screens.
///
/// D-pad focus is owned by [TvRemoteBinder] so each press moves one item
/// (YouTube on Android TV). This widget only scrolls with the wheel or when
/// the pointer sits on the top or bottom edge.
class TvScrollHandler extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final bool isTV;
  final double scrollStep;
  final bool backPops;

  const TvScrollHandler({
    super.key,
    required this.child,
    required this.controller,
    this.isTV = true,
    this.scrollStep = 280.0,
    this.backPops = true,
  });

  @override
  State<TvScrollHandler> createState() => _TvScrollHandlerState();
}

class _TvScrollHandlerState extends State<TvScrollHandler>
    with SingleTickerProviderStateMixin {
  static const double _edgeZone = 72;

  late final Ticker _ticker;
  double _pointerY = -1;
  double _viewHeight = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onEdgeTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _scroll(double delta) {
    final controller = widget.controller;
    if (!controller.hasClients) return;
    final target = (controller.offset + delta)
        .clamp(0.0, controller.position.maxScrollExtent);
    if (target == controller.offset) return;
    controller.jumpTo(target);
  }

  void _onPointerHover(PointerHoverEvent event) {
    _pointerY = event.position.dy;
    _viewHeight = MediaQuery.sizeOf(context).height;
    final onEdge = _pointerY <= _edgeZone ||
        _pointerY >= _viewHeight - _edgeZone;
    if (onEdge && !_ticker.isActive) {
      _ticker.start();
    } else if (!onEdge && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onEdgeTick(Duration elapsed) {
    if (_viewHeight <= 0) return;
    if (_pointerY >= 0 && _pointerY <= _edgeZone) {
      _scroll(-18);
    } else if (_pointerY >= _viewHeight - _edgeZone) {
      _scroll(18);
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTV) return widget.child;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _scroll(event.scrollDelta.dy);
        }
      },
      onPointerHover: _onPointerHover,
      child: widget.child,
    );
  }
}
