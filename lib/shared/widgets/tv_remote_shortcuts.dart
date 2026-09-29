import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/platform_service.dart';

/// OK / Enter still activate focused controls.
///
/// D-pad, page, channel, and Back keys are intentionally [DoNothingAndStopPropagationIntent]:
/// [TvRemoteBinder] already owns those actions. Flutter's default
/// [DirectionalFocusIntent] / [DismissIntent] must not run on the same press,
/// or focus skips a card and Back can fire twice.
class TvRemoteShortcuts extends StatefulWidget {
  final Widget child;

  const TvRemoteShortcuts({super.key, required this.child});

  @override
  State<TvRemoteShortcuts> createState() => _TvRemoteShortcutsState();
}

class _TvRemoteShortcutsState extends State<TvRemoteShortcuts> {
  @override
  void initState() {
    super.initState();
    if (PlatformService.isTV) {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureFocus());
  }

  void _ensureFocus() {
    if (!mounted) return;
    if (!PlatformService.isTV) return;
    final scope = FocusScope.of(context);
    if (scope.focusedChild == null) {
      scope.nextFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpad5): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonStart): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonSelect): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.open): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.accept): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.execute): ActivateIntent(),

        // Block Flutter default focus / dismiss so binder is the only owner.
        SingleActivator(LogicalKeyboardKey.arrowUp):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpad8):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpad2):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpad4):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.numpad6):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.channelUp):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.channelDown):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.pageUp):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.pageDown):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.goBack):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.abort):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.close):
            DoNothingAndStopPropagationIntent(),
        SingleActivator(LogicalKeyboardKey.escape):
            DoNothingAndStopPropagationIntent(),
      },
      child: widget.child,
    );
  }
}
