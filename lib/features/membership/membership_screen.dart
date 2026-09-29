import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/membership_level.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/membership_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/in_app_webview_screen.dart';
import '../../shared/widgets/membership_badge.dart';
import '../../shared/widgets/tv_focusable_card.dart';
import '../../shared/widgets/tv_scroll_handler.dart';

class MembershipScreen extends StatefulWidget {
  final bool isTV;
  const MembershipScreen({super.key, this.isTV = false});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};
  double _cardHeight = 0;

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
      // Left arrow on membership should NOT pop — home screen manages focus.
      backPops: false,
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Consumer2<MembershipProvider, AuthProvider>(
            builder: (context, membership, auth, _) {
              return CustomScrollView(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      widget.isTV ? 40 : 20,
                      widget.isTV ? 32 : 20,
                      widget.isTV ? 40 : 20,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Membership',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(fontSize: widget.isTV ? 36 : 26)),
                          const SizedBox(height: 20),
                          _currentLevelCard(context, membership, auth),
                          const SizedBox(height: 32),
                          Text('Available Plans',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontSize: widget.isTV ? 24 : 18)),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),
                  if (membership.loadingLevels)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child:
                              CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      ),
                    )
                  else if (membership.allLevels.isEmpty)
                    SliverToBoxAdapter(child: _plansUnavailable(membership))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        widget.isTV ? 40 : 20,
                        4,
                        widget.isTV ? 40 : 20,
                        28,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _planGrid(context, membership, auth),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _currentLevelCard(
      BuildContext context, MembershipProvider membership, AuthProvider auth) {
    final level = membership.currentLevel;
    final hasMembership = membership.hasMembership;

    return Container(
      padding: EdgeInsets.all(widget.isTV ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasMembership
              ? [
                  AppTheme.gold.withValues(alpha: 0.15),
                  AppTheme.accent.withValues(alpha: 0.1),
                ]
              : [AppTheme.bgCard, AppTheme.bgElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasMembership
              ? AppTheme.gold.withValues(alpha: 0.4)
              : AppTheme.divider,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasMembership
                  ? AppTheme.gold.withValues(alpha: 0.15)
                  : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              hasMembership
                  ? Icons.workspace_premium
                  : Icons.person_outline_rounded,
              color: hasMembership ? AppTheme.gold : AppTheme.textMuted,
              size: widget.isTV ? 28 : 22,
            ),
          ),
          SizedBox(width: widget.isTV ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMembership ? 'Active Membership' : 'No Active Membership',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: hasMembership
                            ? AppTheme.gold
                            : AppTheme.textSecondary,
                        fontSize: widget.isTV ? 15 : 12,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  level?.name ?? 'None',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontSize: widget.isTV ? 18 : 16,
                      ),
                ),
                if (level != null && !level.isFree) ...[
                  const SizedBox(height: 4),
                  Text(level.priceLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: widget.isTV ? 14 : 12,
                          )),
                ],
              ],
            ),
          ),
          MembershipBadge(
              levelName: level?.name ?? '',
              compact: !widget.isTV),
        ],
      ),
    );
  }

  Widget _plansUnavailable(MembershipProvider membership) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isTV ? 40 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plans could not be loaded.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: membership.loadAll,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  GlobalKey _keyFor(int id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  void _syncCardHeights(List<MembershipLevel> levels) {
    var maxH = 0.0;
    for (final level in levels) {
      final box = _keyFor(level.id).currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        maxH = math.max(maxH, box.size.height);
      }
    }
    if (!mounted || maxH <= _cardHeight + 2) return;
    setState(() => _cardHeight = maxH);
  }

  Widget _planGrid(
    BuildContext context,
    MembershipProvider membership,
    AuthProvider auth,
  ) {
    final levels = membership.allLevels;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCardHeights(levels));
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 640;
        if (!sideBySide) {
          return Column(
            children: [
              for (final level in levels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _levelCard(context, level, membership, auth),
                ),
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < levels.length; i += 2) {
          final right = i + 1 < levels.length ? levels[i + 1] : null;
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _levelCard(context, levels[i], membership, auth),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: right == null
                        ? const SizedBox.shrink()
                        : _levelCard(context, right, membership, auth),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _levelCard(
    BuildContext context,
    MembershipLevel level,
    MembershipProvider membership,
    AuthProvider auth,
  ) {
    final isCurrent = membership.currentLevel?.id == level.id;
    final isFree = level.isFree;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _cardHeight),
      child: TvFocusableCard(
      key: _keyFor(level.id),
      scaleOnFocus: false,
      onTap: isCurrent
          ? null
          : () => _openCheckout(context, level, auth.user?.id ?? 0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(widget.isTV ? 14 : 12),
        decoration: BoxDecoration(
          gradient: isCurrent
              ? LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.15),
                    AppTheme.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isCurrent ? null : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isFree
                        ? AppTheme.bgElevated
                        : AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isFree ? Icons.person_outline : Icons.workspace_premium,
                    color: isFree ? AppTheme.textMuted : AppTheme.gold,
                    size: 18,
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text('Current',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              level.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: widget.isTV ? 16 : 15,
                    color: AppTheme.textPrimary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              level.priceLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isFree ? AppTheme.textMuted : AppTheme.gold,
                    fontWeight:
                        isFree ? FontWeight.w400 : FontWeight.w600,
                    fontSize: widget.isTV ? 15 : 14,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            if (level.includes.isEmpty)
              Text(
                level.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: widget.isTV ? 13 : 12,
                    ),
              )
            else
              _includesList(context, level.includes),
              ],
            ),
            const SizedBox(height: 12),
            if (!isCurrent)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ExcludeFocus(
                  child: ElevatedButton(
                    onPressed: () =>
                        _openCheckout(context, level, auth.user?.id ?? 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFree ? AppTheme.bgElevated : AppTheme.accent,
                      minimumSize: Size.zero,
                      textStyle: TextStyle(fontSize: widget.isTV ? 14 : 13),
                    ),
                    child: Text(isFree ? 'Select Free' : 'Upgrade →'),
                  ),
                ),
              )
            else
              const SizedBox(height: 42),
          ],
        ),
      ),
      ),
    );
  }

  Widget _includesList(BuildContext context, List<String> points) {
    const fontSize = 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Membership Includes:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: widget.isTV ? 13 : 12,
              ),
        ),
        const SizedBox(height: 6),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.play_circle_fill,
                    color: AppTheme.purpleLight,
                    size: widget.isTV ? 16 : 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: fontSize,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openCheckout(
    BuildContext context,
    MembershipLevel level,
    int userId,
  ) async {
    final url =
        'https://albertru50.doptortechllc.com/membership-checkout/?level=${level.id}';
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebViewScreen(
          url: url,
          title: level.name,
        ),
      ),
    );
    if (!context.mounted) return;
    await context.read<MembershipProvider>().loadAll();
  }
}
