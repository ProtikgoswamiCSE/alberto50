import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/platform_service.dart';
import '../../core/services/remote_keys.dart';
import '../../core/services/tv_player_remote.dart';

/// Scrolls only when [target] is off-screen. Visible cards stay put,
/// so Right (1 → 2 → 3) and Down do not jump the page.
void revealTvTarget(BuildContext target) {
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return;
  final item = box.localToGlobal(Offset.zero) & box.size;

  ScrollableState? scrollable = Scrollable.maybeOf(target);
  while (scrollable != null) {
    final viewport = scrollable.context.findRenderObject();
    final pos = scrollable.position;
    if (viewport is RenderBox &&
        viewport.attached &&
        viewport.hasSize &&
        pos.hasPixels &&
        pos.hasContentDimensions) {
      final view = viewport.localToGlobal(Offset.zero) & viewport.size;
      var delta = 0.0;
      if (scrollable.widget.axis == Axis.vertical) {
        if (item.height > view.height * 0.9) {
          // Tall membership cards: bring the top on screen, then let
          // D-pad page through the rest without snapping back.
          if (item.top < view.top - 8 || item.top > view.bottom - 80) {
            delta = item.top - view.top - 16;
          }
        } else if (item.top < view.top + 12) {
          delta = item.top - view.top - 24;
        } else if (item.bottom > view.bottom - 12) {
          delta = item.bottom - view.bottom + 24;
        }
      } else if (item.width <= view.width * 0.9) {
        if (item.left < view.left + 12) {
          delta = item.left - view.left - 24;
        } else if (item.right > view.right - 12) {
          delta = item.right - view.right + 24;
        }
      }
      if (delta.abs() > 1) {
        final next = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
        if (next != pos.pixels) {
          pos.animateTo(
            next,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
    scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
  }
}

final GlobalKey<NavigatorState> tvNavigatorKey = GlobalKey<NavigatorState>();

/// Captures TV-box remote keys at the engine level.
///
/// Shortcuts often never fire on Android TV: the IME or a TextField eats
/// D-pad events, or the box sends Android key codes Flutter does not bind.
/// This handler always moves focus, activates the focused control, and pops
/// on Back — no on-screen mouse cursor.
class TvRemoteBinder extends StatefulWidget {
  final Widget child;

  const TvRemoteBinder({super.key, required this.child});

  @override
  State<TvRemoteBinder> createState() => _TvRemoteBinderState();
}

class _TvRemoteBinderState extends State<TvRemoteBinder> {
  static const int _pointerId = 92001;
  /// Absorbs duplicate KeyDown from one physical press without eating
  /// intentional rapid presses (typically >120ms apart).
  static const Duration _moveGuard = Duration(milliseconds: 110);
  static const Duration _backGuard = Duration(milliseconds: 280);

  bool _pointerAdded = false;
  DateTime _lastMoveAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBackAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastActivateAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _heldSince;
  bool _scrollMovePending = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _ensureFocus() {
    if (!mounted || !PlatformService.isTV) return;
    final scope = FocusScope.of(context);
    if (scope.focusedChild == null) {
      scope.nextFocus();
    }
  }

  bool _inEditable() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _shouldSkipRepeat() {
    final held = _heldSince;
    if (held == null) return true;
    // Brief pause after the first move, then a steady cadence so
    // holding Up/Down feels smooth instead of jumpy.
    if (DateTime.now().difference(held) < const Duration(milliseconds: 320)) {
      return true;
    }
    return DateTime.now().difference(_lastMoveAt) <
        const Duration(milliseconds: 140);
  }

  bool _shouldSkipDuplicateMove() {
    return DateTime.now().difference(_lastMoveAt) < _moveGuard;
  }

  bool _onKey(KeyEvent event) {
    final action = RemoteKeys.actionOf(event);
    if (action != RemoteAction.none) {
      PlatformService.promoteToTvMode();
    }
    if (!PlatformService.isTV) {
      // Phones ignore D-pad; TV boxes that failed detection get promoted above.
      if (defaultTargetPlatform != TargetPlatform.android ||
          action == RemoteAction.none) {
        return false;
      }
    }
    if (event is KeyUpEvent) {
      _heldSince = null;
      return false;
    }

    if (TvPlayerRemote.dispatch(action, event)) return true;
    if (TvPageKeys.dispatch(action, event)) return true;

    if (action == RemoteAction.none) return false;

    if (action == RemoteAction.back) {
      // KeyRepeat must not pop multiple routes for one held Back.
      if (event is! KeyDownEvent) return true;
      if (event.logicalKey == LogicalKeyboardKey.backspace && _inEditable()) {
        return false;
      }
      if (DateTime.now().difference(_lastBackAt) < _backGuard) return true;
      _lastBackAt = DateTime.now();
      _hideIme();
      // Ask the route. Nested pages pop; home PopScope moves to rail / exits.
      tvNavigatorKey.currentState?.maybePop();
      return true;
    }

    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final isMove = action == RemoteAction.up ||
        action == RemoteAction.down ||
        action == RemoteAction.left ||
        action == RemoteAction.right;

    if (isMove && _scrollMovePending) {
      return true;
    }
    if (isMove && event is KeyRepeatEvent && _shouldSkipRepeat()) {
      return true;
    }
    if (isMove && event is KeyDownEvent && _shouldSkipDuplicateMove()) {
      return true;
    }
    if (isMove && event is KeyDownEvent) {
      _heldSince = DateTime.now();
    }

    _hideIme();

    switch (action) {
      case RemoteAction.up:
        _lastMoveAt = DateTime.now();
        _move(TraversalDirection.up);
        return true;
      case RemoteAction.down:
        _lastMoveAt = DateTime.now();
        _move(TraversalDirection.down);
        return true;
      case RemoteAction.left:
        _lastMoveAt = DateTime.now();
        _move(TraversalDirection.left);
        return true;
      case RemoteAction.right:
        _lastMoveAt = DateTime.now();
        _move(TraversalDirection.right);
        return true;
      case RemoteAction.select:
      case RemoteAction.mouseToggle:
        if (action == RemoteAction.select &&
            event.logicalKey == LogicalKeyboardKey.space &&
            _inEditable()) {
          return false;
        }
        if (event is KeyDownEvent) _activate();
        return true;
      case RemoteAction.playPause:
      case RemoteAction.rewind:
      case RemoteAction.fastForward:
      case RemoteAction.skipBack:
      case RemoteAction.skipForward:
      case RemoteAction.back:
      case RemoteAction.none:
        return false;
    }
  }

  void _hideIme() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _focusNode(FocusNode node) {
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = node.context;
      if (target == null || !target.mounted) return;
      revealTvTarget(target);
    });
  }

  /// Leaf focusables in [scope], in visual rows (top-to-bottom, then left-to-right).
  List<List<_FocusSpot>> _rowsIn(FocusScopeNode scope) {
    final spots = <_FocusSpot>[];
    for (final node in scope.traversalDescendants) {
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (node.traversalDescendants.isNotEmpty) continue;
      final ctx = node.context;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = node.rect;
      if (!rect.isFinite || rect.width < 4 || rect.height < 4) continue;
      spots.add(_FocusSpot(node, rect));
    }
    spots.sort((a, b) {
      final dy = a.rect.center.dy.compareTo(b.rect.center.dy);
      if ((a.rect.center.dy - b.rect.center.dy).abs() > 8) return dy;
      return a.rect.left.compareTo(b.rect.left);
    });

    final rows = <List<_FocusSpot>>[];
    for (final spot in spots) {
      if (rows.isNotEmpty && _sameRow(spot, rows.last)) {
        rows.last.add(spot);
        continue;
      }
      rows.add([spot]);
    }
    for (final row in rows) {
      row.sort((a, b) => a.rect.left.compareTo(b.rect.left));
    }
    return rows;
  }

  bool _sameRow(_FocusSpot spot, List<_FocusSpot> row) {
    var sum = 0.0;
    var minH = spot.rect.height;
    for (final item in row) {
      sum += item.rect.center.dy;
      if (item.rect.height < minH) minH = item.rect.height;
    }
    final avgY = sum / row.length;
    final limit = math.max(28.0, math.min(spot.rect.height, minH) * 0.45);
    return (spot.rect.center.dy - avgY).abs() <= limit;
  }

  _FocusSpot? _verticalTarget(Rect from, List<_FocusSpot> row) {
    if (row.isEmpty) return null;
    final rowLeft = row.map((e) => e.rect.left).reduce(math.min);
    final rowRight = row.map((e) => e.rect.right).reduce(math.max);
    final span = rowRight - rowLeft;
    // A full-width hero should land on the first card of the next row.
    if (span > 1 && from.width >= span * 0.72) return row.first;

    _FocusSpot? best;
    var bestScore = double.infinity;
    for (final spot in row) {
      final overlap = math.min(from.right, spot.rect.right) -
          math.max(from.left, spot.rect.left);
      final dx = (spot.rect.center.dx - from.center.dx).abs();
      final score = overlap > 8 ? -overlap * 1000 + dx : 100000 + dx;
      if (score < bestScore) {
        bestScore = score;
        best = spot;
      }
    }
    return best;
  }

  FocusNode? _neighbor(
    FocusNode current,
    TraversalDirection direction,
    List<List<_FocusSpot>> rows,
    int rowIndex,
    int colIndex,
  ) {
    final row = rows[rowIndex];
    switch (direction) {
      case TraversalDirection.right:
        if (colIndex + 1 >= row.length) {
          return _sideScopeLeaf(current, TraversalDirection.right);
        }
        // Same visual row: next index is always the neighbor (no gap skip).
        return row[colIndex + 1].node;
      case TraversalDirection.left:
        if (colIndex == 0) {
          return _sideScopeLeaf(current, TraversalDirection.left);
        }
        return row[colIndex - 1].node;
      case TraversalDirection.down:
        if (rowIndex + 1 >= rows.length) return null;
        return _verticalTarget(current.rect, rows[rowIndex + 1])?.node;
      case TraversalDirection.up:
        if (rowIndex == 0) return null;
        return _verticalTarget(current.rect, rows[rowIndex - 1])?.node;
    }
  }

  /// Rail ↔ content. Only a scope that actually sits beside this one.
  FocusNode? _sideScopeLeaf(FocusNode current, TraversalDirection direction) {
    final mine = current.enclosingScope;
    if (mine == null) return null;
    final myRect = mine.rect;
    if (!myRect.isFinite || myRect.width < 4 || myRect.height < 4) return null;

    final scopes = <FocusScopeNode>[];
    void walk(FocusNode node) {
      for (final child in node.children) {
        if (child is! FocusScopeNode) continue;
        if (!identical(child, mine) &&
            child.canRequestFocus &&
            child.traversalDescendants.isNotEmpty) {
          final rect = child.rect;
          if (rect.isFinite && rect.width >= 4 && rect.height >= 4) {
            scopes.add(child);
          }
        }
        walk(child);
      }
    }

    walk(FocusManager.instance.rootScope);

    FocusScopeNode? best;
    var bestGap = double.infinity;
    for (final scope in scopes) {
      final rect = scope.rect;
      final overlap = math.min(rect.bottom, myRect.bottom) -
          math.max(rect.top, myRect.top);
      if (overlap < math.min(myRect.height, rect.height) * 0.5) continue;
      final gap = direction == TraversalDirection.right
          ? rect.left - myRect.right
          : myRect.left - rect.right;
      // Rail and content sit in one Row; allow a little padding/gap.
      if (gap > 160) continue;
      if (gap < -40) continue;
      if (direction == TraversalDirection.right && rect.left < myRect.center.dx) {
        continue;
      }
      if (direction == TraversalDirection.left && rect.right > myRect.center.dx) {
        continue;
      }
      if (gap < bestGap) {
        bestGap = gap;
        best = scope;
      }
    }
    if (best == null) return null;

    final leaves = _rowsIn(best).expand((row) => row).toList();
    if (leaves.isEmpty) return null;
    if (direction == TraversalDirection.right) {
      leaves.sort((a, b) {
        final dy = a.rect.top.compareTo(b.rect.top);
        if ((a.rect.top - b.rect.top).abs() > 24) return dy;
        return a.rect.left.compareTo(b.rect.left);
      });
      return leaves.first.node;
    }
    final y = current.rect.center.dy;
    leaves.sort((a, b) => (a.rect.center.dy - y)
        .abs()
        .compareTo((b.rect.center.dy - y).abs()));
    return leaves.first.node;
  }

  bool _scrollForMore(TraversalDirection direction) {
    if (_scrollMovePending) return true;
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final axis = direction == TraversalDirection.left ||
            direction == TraversalDirection.right
        ? Axis.horizontal
        : Axis.vertical;
    final scrollable = Scrollable.maybeOf(ctx, axis: axis);
    if (scrollable == null || !scrollable.position.hasPixels) return false;
    final viewport = scrollable.position.viewportDimension;
    final step = viewport.isFinite && viewport > 80 ? viewport * 0.62 : 360.0;
    final delta = direction == TraversalDirection.down ||
            direction == TraversalDirection.right
        ? step
        : -step;
    final next = (scrollable.position.pixels + delta)
        .clamp(0.0, scrollable.position.maxScrollExtent);
    if (next == scrollable.position.pixels) return false;
    _scrollMovePending = true;
    scrollable.position
        .animateTo(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      _scrollMovePending = false;
      if (!mounted) return;
      final current = FocusManager.instance.primaryFocus;
      if (current == null) return;
      final picked = _pick(current, direction);
      if (picked.next != null && !identical(picked.next, current)) {
        _focusNode(picked.next!);
      }
    });
    return true;
  }

  ({bool found, FocusNode? next}) _pick(
    FocusNode current,
    TraversalDirection direction,
  ) {
    const missing = (found: false, next: null);
    final scope = current.enclosingScope;
    if (scope == null) return missing;
    final rows = _rowsIn(scope);
    var rowIndex = -1;
    var colIndex = -1;
    for (var r = 0; r < rows.length; r++) {
      final c = rows[r].indexWhere((s) => identical(s.node, current));
      if (c >= 0) {
        rowIndex = r;
        colIndex = c;
        break;
      }
    }
    if (rowIndex < 0) return missing;
    final next = _neighbor(current, direction, rows, rowIndex, colIndex);
    if (next == null || identical(next, current)) {
      return (found: true, next: null);
    }
    return (found: true, next: next);
  }

  void _move(TraversalDirection direction) {
    var focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.skipTraversal) {
      final ctx = tvNavigatorKey.currentContext ?? context;
      FocusScope.of(ctx).nextFocus();
      focus = FocusManager.instance.primaryFocus;
      if (focus == null) return;
    }

    final pick = _pick(focus, direction);
    if (pick.next != null) {
      _focusNode(pick.next!);
      return;
    }

    // Leftmost poster: always try the side rail before scrolling.
    if (direction == TraversalDirection.left) {
      final rail = _sideScopeLeaf(focus, TraversalDirection.left);
      if (rail != null) {
        _focusNode(rail);
        return;
      }
      // Geometry can miss the rail; home registers an explicit callback.
      if (TvRailRemote.moveToRail()) return;
    }

    // Flutter's nearest-widget search skips cards. Only use it when this
    // node is not in the row map at all.
    if (!pick.found && focus.focusInDirection(direction)) {
      return;
    }

    _scrollForMore(direction);
  }

  void _activate() {
    // One physical OK must not run twice (eye toggle would undo itself;
    // dialog Cancel would pop the page under the popup).
    if (DateTime.now().difference(_lastActivateAt) <
        const Duration(milliseconds: 320)) {
      return;
    }
    _lastActivateAt = DateTime.now();

    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) {
      _ensureFocus();
      return;
    }

    if (_inEditable()) {
      focus!.nextFocus();
      return;
    }

    // Prefer ActivateIntent on the focused control (buttons, eye toggle, cards).
    if (Actions.maybeInvoke(ctx, const ActivateIntent()) != null) return;

    Element? found;
    ctx.visitAncestorElements((element) {
      if (Actions.maybeInvoke(element, const ActivateIntent()) != null) {
        found = element;
        return false;
      }
      return true;
    });
    if (found != null) return;

    // Fallback: synthesize a tap at the focused widget center.
    _tapFocused(focus);
  }

  void _tapFocused(FocusNode? focus) {
    final box = focus?.context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final pos = box.localToGlobal(box.size.center(Offset.zero));

    Future<void>(() {
      final binding = GestureBinding.instance;
      if (!_pointerAdded) {
        _pointerAdded = true;
        binding.handlePointerEvent(
          PointerAddedEvent(
            pointer: _pointerId,
            kind: PointerDeviceKind.touch,
            position: pos,
          ),
        );
      }
      binding.handlePointerEvent(
        PointerDownEvent(
          pointer: _pointerId,
          kind: PointerDeviceKind.touch,
          position: pos,
          buttons: kPrimaryButton,
        ),
      );
      binding.handlePointerEvent(
        PointerUpEvent(
          pointer: _pointerId,
          kind: PointerDeviceKind.touch,
          position: pos,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (PlatformService.isTV) {
      child = MediaQuery(
        data: MediaQuery.of(context).copyWith(
          navigationMode: NavigationMode.directional,
        ),
        child: child,
      );
    }
    return child;
  }
}

class _FocusSpot {
  final FocusNode node;
  final Rect rect;
  const _FocusSpot(this.node, this.rect);
}
