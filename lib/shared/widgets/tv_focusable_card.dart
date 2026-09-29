import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/remote_keys.dart';
import '../../shared/theme/app_theme.dart';
import 'tv_remote_binder.dart';

/// A TV-friendly focusable card wrapper.
/// Adds a glowing focus ring and subtle scale animation on D-pad focus.
/// Works transparently on phones (focus ring is invisible without TV focus).
///
/// Fix: `InkWell.onTap` is removed to prevent double-firing on TV remotes.
/// Touch/mouse taps are handled by a wrapping [GestureDetector] instead.
class TvFocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool scaleOnFocus;
  final BorderRadius borderRadius;

  const TvFocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.scaleOnFocus = true,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<TvFocusableCard> createState() => _TvFocusableCardState();
}

class _TvFocusableCardState extends State<TvFocusableCard>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  bool _isFocused = false;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleOnFocus ? 1.05 : 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    setState(() => _isFocused = focused);
    if (focused) {
      _scaleController.forward();
      final target = _focusNode.context;
      if (target != null) {
        revealTvTarget(target);
      }
    } else {
      _scaleController.reverse();
    }
  }

  void _handleTap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) < const Duration(milliseconds: 350)) {
      return;
    }
    _lastTap = now;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _handleTap();
            return true;
          },
        ),
      },
      child: Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      descendantsAreFocusable: false,
      onFocusChange: _onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && RemoteKeys.isSelect(event)) {
          _handleTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
            border: Border.all(
              color: _isFocused ? AppTheme.accent : AppTheme.divider,
              width: 2,
            ),
          ),
          // GestureDetector handles touch/mouse tap; remote uses key handler above.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap != null ? _handleTap : null,
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  // onTap intentionally omitted — handled by GestureDetector above
                  // to prevent double-fire on TV remotes that send both key + tap events.
                  canRequestFocus: false,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
