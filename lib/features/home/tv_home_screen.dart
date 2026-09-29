import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/membership_provider.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/services/tv_player_remote.dart';
import '../posts/posts_feed_screen.dart';
import '../membership/membership_screen.dart';
import '../account/account_screen.dart';
import '../../shared/widgets/tv_side_rail.dart';
import '../../shared/theme/app_theme.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int _selectedIndex = 0;

  final _railFocus = FocusScopeNode();
  final _contentFocus = FocusScopeNode();

  static const _navItems = [
    TvNavItem(icon: Icons.movie_rounded, label: 'Movies'),
    TvNavItem(icon: Icons.workspace_premium, label: 'Membership'),
    TvNavItem(icon: Icons.person_rounded, label: 'Account'),
  ];

  final _screens = const [
    PostsFeedScreen(isTV: true),
    MembershipScreen(isTV: true),
    AccountScreen(isTV: true),
  ];

  @override
  void initState() {
    super.initState();
    TvRailRemote.register(_focusRail);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MembershipProvider>().loadAll();
      context.read<PostsProvider>().loadPosts();
      // Give focus to the content area on startup so the TV remote
      // works immediately without requiring a screen tap.
      _focusContent();
    });
  }

  @override
  void dispose() {
    TvRailRemote.unregister(_focusRail);
    _railFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  bool _railFocused = false;

  void _focusRail() {
    _railFocus.requestFocus();
    setState(() => _railFocused = true);
  }

  void _focusContent() {
    // Use nextFocus() so the first focusable descendant inside the
    // content screen (e.g. the hero TvFocusableCard) receives focus.
    _contentFocus.requestFocus();
    setState(() => _railFocused = false);
    // Give the content area a frame to settle, then move into first child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocus.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Root must not pop to login (that looked like logout). First Back from
      // content focuses the rail; Back again on the rail leaves the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_railFocused) {
          _focusRail();
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Row(
            children: [
              // Side rail
              FocusScope(
                node: _railFocus,
                onFocusChange: (focused) {
                  if (focused) setState(() => _railFocused = true);
                },
                child: TvSideRail(
                  items: _navItems,
                  selectedIndex: _selectedIndex,
                  onItemSelected: (i) {
                    setState(() => _selectedIndex = i);
                    // After selecting, move focus to content area.
                    _focusContent();
                  },
                  // Right arrow on rail → move focus to content.
                  onRightArrow: _focusContent,
                ),
              ),
              // Content area — Left-to-rail is owned by TvRemoteBinder only.
              Expanded(
                child: FocusScope(
                    node: _contentFocus,
                    onFocusChange: (focused) {
                      if (focused) setState(() => _railFocused = false);
                    },
                    child: IndexedStack(
                      index: _selectedIndex,
                      sizing: StackFit.expand,
                      children: [
                        for (var i = 0; i < _screens.length; i++)
                          ExcludeFocus(
                            excluding: i != _selectedIndex,
                            child: _screens[i],
                          ),
                      ],
                    ),
                  ),
              ),
            ],
          ),
      ),
    );
  }
}
