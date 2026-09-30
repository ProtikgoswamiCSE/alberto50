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

    final amount = double.tryParse(level.billingAmount) ??
        double.tryParse(level.initialPayment) ??
        0;
    final period = level.billingPeriod.trim();

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _cardHeight),
      child: TvFocusableCard(
        key: _keyFor(level.id),
        scaleOnFocus: true,
        focusScale: 1.02,
        focusColor: isFree ? null : AppTheme.gold,
        borderRadius: BorderRadius.circular(18),
        onTap: isCurrent
            ? null
            : () => _openCheckout(context, level, auth.user?.id ?? 0),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            widget.isTV ? 18 : 16,
            widget.isTV ? 16 : 14,
            widget.isTV ? 18 : 16,
            widget.isTV ? 16 : 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFree
                  ? [AppTheme.bgCard, const Color(0xFF141414)]
                  : const [
                      Color(0xFF3A2C12),
                      Color(0xFF1A160F),
                      Color(0xFF101010),
                    ],
            ),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFree
                              ? AppTheme.bgElevated
                              : AppTheme.gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isFree
                              ? Icons.person_outline
                              : Icons.workspace_premium_rounded,
                          color: isFree ? AppTheme.textMuted : AppTheme.goldLight,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      if (!isFree && !isCurrent)
                        _pill('Recommended', AppTheme.gold),
                      if (isCurrent) _pill('Current', AppTheme.accent),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    level.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: widget.isTV ? 20 : 17,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.2,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (isFree)
                    Text(
                      'Free',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMuted,
                            fontSize: widget.isTV ? 16 : 14,
                          ),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '\$${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppTheme.goldLight,
                            fontSize: widget.isTV ? 28 : 24,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        if (period.isNotEmpty)
                          Text(
                            '  / $period',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: widget.isTV ? 14 : 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  if (level.includes.isEmpty)
                    Text(
                      level.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: widget.isTV ? 13 : 12,
                            height: 1.4,
                          ),
                    )
                  else
                    _includesList(context, level.includes, gold: !isFree),
                ],
              ),
              const SizedBox(height: 16),
              if (!isCurrent)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ExcludeFocus(
                    child: ElevatedButton(
                      onPressed: () =>
                          _openCheckout(context, level, auth.user?.id ?? 0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isFree ? AppTheme.bgElevated : AppTheme.gold,
                        foregroundColor:
                            isFree ? AppTheme.textPrimary : const Color(0xFF1A1204),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: widget.isTV ? 15 : 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      child: Text(isFree ? 'Select Free' : 'Upgrade'),
                    ),
                  ),
                )
              else
                const SizedBox(height: 46),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _includesList(
    BuildContext context,
    List<String> points, {
    required bool gold,
  }) {
    final mark = gold ? AppTheme.goldLight : AppTheme.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your membership includes',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: widget.isTV ? 13 : 12,
                letterSpacing: 0.2,
              ),
        ),
        const SizedBox(height: 10),
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: mark,
                    size: widget.isTV ? 16 : 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFE6E6E6),
                          fontSize: widget.isTV ? 13 : 12,
                          height: 1.4,
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
