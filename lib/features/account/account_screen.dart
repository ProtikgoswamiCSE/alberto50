import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/membership_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/membership_badge.dart';
import '../../shared/widgets/tv_focusable_card.dart';
import '../../shared/widgets/tv_scroll_handler.dart';

class AccountScreen extends StatefulWidget {
  final bool isTV;
  const AccountScreen({super.key, this.isTV = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvScrollHandler(
      controller: _scrollCtrl,
      isTV: widget.isTV,
      // Left arrow on account should NOT pop — home screen manages focus.
      backPops: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Consumer2<AuthProvider, MembershipProvider>(
            builder: (context, auth, membership, _) {
              final user = auth.user;
              if (user == null) return const SizedBox.shrink();

              return SingleChildScrollView(
                controller: _scrollCtrl,
                padding: EdgeInsets.all(widget.isTV ? 40 : 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Account',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontSize: widget.isTV ? 36 : 26)),
                      SizedBox(height: widget.isTV ? 32 : 24),

                      // Profile card
                      _profileCard(context, auth, membership),
                      SizedBox(height: widget.isTV ? 24 : 18),

                      // Info rows
                      _infoSection(context, 'Account Details', [
                        _infoRow(context, Icons.person_outline,
                            'Username', user.username),
                        _infoRow(context, Icons.email_outlined,
                            'Email', user.email),
                        _infoRow(context, Icons.tag, 'User ID',
                            user.id.toString()),
                      ]),
                      SizedBox(height: widget.isTV ? 24 : 18),

                      // Membership quick info
                      _infoSection(context, 'Membership', [
                        _infoRow(
                          context,
                          Icons.workspace_premium_outlined,
                          'Level',
                          membership.currentLevel?.name ?? 'None',
                        ),
                      ]),
                      SizedBox(height: widget.isTV ? 40 : 32),

                      // Logout
                      TvFocusableCard(
                        onTap: () => _confirmLogout(context, auth),
                        child: Padding(
                          padding: EdgeInsets.all(widget.isTV ? 20 : 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.logout_rounded,
                                    color: AppTheme.danger, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Sign Out',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppTheme.danger,
                                      fontWeight: FontWeight.w600,
                                      fontSize: widget.isTV ? 18 : 15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileCard(
      BuildContext context, AuthProvider auth, MembershipProvider membership) {
    final user = auth.user!;
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : user.username[0].toUpperCase();

    return Container(
      padding: EdgeInsets.all(widget.isTV ? 28 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.bgCard, AppTheme.bgElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: widget.isTV ? 80 : 60,
            height: widget.isTV ? 80 : 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, Color(0xFF6A5AF9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(widget.isTV ? 24 : 18),
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.isTV ? 34 : 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(width: widget.isTV ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.username,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: widget.isTV ? 24 : 18,
                      ),
                ),
                const SizedBox(height: 4),
                Text(user.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: widget.isTV ? 15 : 13)),
                const SizedBox(height: 10),
                MembershipBadge(
                  levelName: membership.currentLevel?.name ?? '',
                  compact: !widget.isTV,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(
      BuildContext context, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  fontSize: widget.isTV ? 15 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                )),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: rows
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < rows.length - 1)
                          const Divider(
                              height: 1, color: AppTheme.divider,
                              indent: 16, endIndent: 16),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: widget.isTV ? 22 : 16, vertical: widget.isTV ? 16 : 13),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: widget.isTV ? 20 : 17),
          SizedBox(width: widget.isTV ? 14 : 12),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: widget.isTV ? 16 : 13,
                  )),
          const Spacer(),
          Text(value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: widget.isTV ? 16 : 13,
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          // Cancel: only close this popup (never pop the account page).
          TextButton(
            autofocus: true,
            onPressed: () {
              final nav = Navigator.of(ctx, rootNavigator: true);
              if (nav.canPop()) nav.pop(false);
            },
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(80, 40),
            ),
            onPressed: () {
              final nav = Navigator.of(ctx, rootNavigator: true);
              if (nav.canPop()) nav.pop(true);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !context.mounted) return;
      auth.logout();
      context.read<MembershipProvider>().reset();
    });
  }
}
