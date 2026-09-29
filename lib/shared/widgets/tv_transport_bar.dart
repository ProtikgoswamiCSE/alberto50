import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

/// Player controls in one row. Each button has a stable [FocusNode] so
/// TV OK / Select activates it on the first press (no second click).
class TvTransportBar extends StatelessWidget {
  final bool isPlaying;
  final bool muted;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final VoidCallback onBack10s;
  final VoidCallback onFwd10s;
  final VoidCallback onBack10m;
  final VoidCallback onFwd10m;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;
  final FocusNode playFocus;
  final FocusNode back10mFocus;
  final FocusNode back10sFocus;
  final FocusNode fwd10sFocus;
  final FocusNode fwd10mFocus;
  final FocusNode muteFocus;
  final FocusNode fullscreenFocus;
  final bool autofocusPlay;

  const TvTransportBar({
    super.key,
    required this.isPlaying,
    required this.muted,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onBack10s,
    required this.onFwd10s,
    required this.onBack10m,
    required this.onFwd10m,
    required this.onMute,
    required this.onFullscreen,
    required this.playFocus,
    required this.back10mFocus,
    required this.back10sFocus,
    required this.fwd10sFocus,
    required this.fwd10mFocus,
    required this.muteFocus,
    required this.fullscreenFocus,
    this.autofocusPlay = false,
  });

  /// Left-to-right order used for smooth D-pad moves on the player page.
  List<FocusNode> get focusOrder => [
        back10mFocus,
        back10sFocus,
        playFocus,
        fwd10sFocus,
        fwd10mFocus,
        muteFocus,
        fullscreenFocus,
      ];

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      color: AppTheme.bgDark.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: AppTheme.accent,
                backgroundColor: AppTheme.bgElevated,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _fmt(position),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(duration),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: _ctrlBtn(
                      focus: back10mFocus,
                      icon: Icons.keyboard_double_arrow_left,
                      label: '-10m',
                      onPressed: onBack10m,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: _ctrlBtn(
                      focus: back10sFocus,
                      icon: Icons.replay_10,
                      label: '-10s',
                      onPressed: onBack10s,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(3),
                    child: _playBtn(),
                  ),
                  const SizedBox(width: 12),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(4),
                    child: _ctrlBtn(
                      focus: fwd10sFocus,
                      icon: Icons.forward_10,
                      label: '+10s',
                      onPressed: onFwd10s,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(5),
                    child: _ctrlBtn(
                      focus: fwd10mFocus,
                      icon: Icons.keyboard_double_arrow_right,
                      label: '+10m',
                      onPressed: onFwd10m,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(6),
                    child: _ctrlBtn(
                      focus: muteFocus,
                      icon: muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      label: muted ? 'Muted' : 'Sound',
                      onPressed: onMute,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(7),
                    child: _ctrlBtn(
                      focus: fullscreenFocus,
                      icon: Icons.fullscreen_rounded,
                      label: 'Full',
                      onPressed: onFullscreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playBtn() {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 56,
          child: _TvControlButton(
            focusNode: playFocus,
            autofocus: autofocusPlay,
            background: AppTheme.accent,
            onPressed: onPlayPause,
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isPlaying ? 'Pause' : 'Play',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _ctrlBtn({
    required FocusNode focus,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: _TvControlButton(
            focusNode: focus,
            background: AppTheme.bgElevated,
            onPressed: onPressed,
            child: Icon(icon, size: 26, color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// TV-safe control: OK / Select fires [onPressed] on the first press via
/// [ActivateIntent], independent of IconButton quirks under rebuilds.
///
/// Select is handled only through [ActivateIntent] here. The global TV remote
/// binder / player remote already maps OK → ActivateIntent or direct callbacks;
/// a second [onKeyEvent] Select handler would double-toggle play/fullscreen.
class _TvControlButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final Widget child;
  final Color background;
  final bool autofocus;

  const _TvControlButton({
    required this.focusNode,
    required this.onPressed,
    required this.child,
    required this.background,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return true;
          },
        ),
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            autofocus: autofocus,
            child: Material(
              color: background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: focused ? AppTheme.accent : AppTheme.divider,
                  width: focused ? 3 : 1,
                ),
              ),
              child: InkWell(
                onTap: onPressed,
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(28),
                child: Center(child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}
