import 'package:flutter/material.dart';
import '../../core/services/remote_keys.dart';
import '../../shared/theme/app_theme.dart';
import 'tv_focusable_card.dart';

class TvNavItem {
  final IconData icon;
  final String label;
  const TvNavItem({required this.icon, required this.label});
}

/// Side navigation rail for Android TV.
/// Collapses to icon-only and expands on focus.
/// D-pad Up/Down cycles items; Enter/OK selects; Right arrow → content via [onRightArrow].
class TvSideRail extends StatefulWidget {
  final List<TvNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  /// Called when D-pad Right is pressed while the rail is focused.
  /// Typically wires to a callback that moves focus to the content area.
  final VoidCallback? onRightArrow;

  const TvSideRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onRightArrow,
  });

  @override
  State<TvSideRail> createState() => _TvSideRailState();
}

class _TvSideRailState extends State<TvSideRail>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _widthController;
  late final Animation<double> _widthAnimation;
  late final List<FocusNode> _itemFocusNodes;
  int _focusedIndex = 0;

  static const double _collapsedWidth = 72;
  static const double _expandedWidth = 220;

  @override
  void initState() {
    super.initState();
    _widthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _widthAnimation = Tween<double>(
      begin: _collapsedWidth,
      end: _expandedWidth,
    ).animate(CurvedAnimation(parent: _widthController, curve: Curves.easeOut));

    _itemFocusNodes = List.generate(widget.items.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    _widthController.dispose();
    for (final fn in _itemFocusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  void _expand() {
    setState(() => _expanded = true);
    _widthController.forward();
  }

  void _collapse() {
    setState(() => _expanded = false);
    _widthController.reverse();
  }

  /// Handle D-pad Up/Down/Right within the rail.
  KeyEventResult _handleRailKey(KeyEvent event) {
    if (!RemoteKeys.isPress(event)) return KeyEventResult.ignored;

    switch (RemoteKeys.actionOf(event)) {
      case RemoteAction.down:
        final next = (_focusedIndex + 1).clamp(0, widget.items.length - 1);
        _itemFocusNodes[next].requestFocus();
        setState(() => _focusedIndex = next);
        return KeyEventResult.handled;
      case RemoteAction.up:
        final prev = (_focusedIndex - 1).clamp(0, widget.items.length - 1);
        _itemFocusNodes[prev].requestFocus();
        setState(() => _focusedIndex = prev);
        return KeyEventResult.handled;
      case RemoteAction.right:
        widget.onRightArrow?.call();
        return KeyEventResult.handled;
      case RemoteAction.left:
        return KeyEventResult.handled;
      case RemoteAction.select:
      case RemoteAction.back:
      case RemoteAction.playPause:
      case RemoteAction.rewind:
      case RemoteAction.fastForward:
      case RemoteAction.skipBack:
      case RemoteAction.skipForward:
      case RemoteAction.mouseToggle:
      case RemoteAction.none:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        if (focused) {
          _expand();
          // Restore focus to the last focused item
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemFocusNodes.isNotEmpty) {
              _itemFocusNodes[_focusedIndex].requestFocus();
            }
          });
        } else {
          _collapse();
        }
      },
      onKeyEvent: (node, event) => _handleRailKey(event),
      child: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, _) {
          return Container(
            width: _widthAnimation.value,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: const Border(
                right: BorderSide(color: AppTheme.divider, width: 1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // App logo / brand
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: _expanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.whatshot_rounded,
                            color: Colors.white, size: 20),
                      ),
                      if (_expanded) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Horror After Dark',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    color: AppTheme.textPrimary, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ...List.generate(widget.items.length, (i) {
                  final item = widget.items[i];
                  final selected = widget.selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: TvFocusableCard(
                      focusNode: _itemFocusNodes[i],
                      onTap: () {
                        setState(() => _focusedIndex = i);
                        widget.onItemSelected(i);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        // Tighter padding when collapsed so icon fits cleanly
                        padding: EdgeInsets.symmetric(
                          horizontal: _expanded ? 16 : 10,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: _expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(
                              item.icon,
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.textSecondary,
                              size: 24,
                            ),
                            // Only show label when expanded — clip prevents overflow
                            if (_expanded) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: selected
                                            ? AppTheme.accent
                                            : AppTheme.textSecondary,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        fontSize: 15,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                // D-pad hint shown when expanded
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gamepad_outlined,
                            color: AppTheme.textMuted, size: 13),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '↑↓ nav  ▶ content',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
