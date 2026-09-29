import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/order.dart';
import '../../core/providers/membership_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/tv_focusable_card.dart';
import '../../shared/widgets/tv_scroll_handler.dart';

class OrderHistoryScreen extends StatefulWidget {
  final bool isTV;
  const OrderHistoryScreen({super.key, this.isTV = false});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
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
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Consumer<MembershipProvider>(
            builder: (context, membership, _) {
              return CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      widget.isTV ? 40 : 20, widget.isTV ? 32 : 20,
                      widget.isTV ? 40 : 20, 0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Order History',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontSize: widget.isTV ? 36 : 26),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (membership.loadingOrders)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      ),
                    )
                  else if (membership.orders.isEmpty)
                    SliverFillRemaining(
                      child: _emptyState(context),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: widget.isTV ? 40 : 20),
                      sliver: widget.isTV
                          ? _tvGrid(context, membership.orders)
                          : _phoneList(context, membership.orders),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tvGrid(BuildContext context, List<MemberOrder> orders) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _orderCard(context, orders[i]),
        childCount: orders.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.4,
      ),
    );
  }

  Widget _phoneList(BuildContext context, List<MemberOrder> orders) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _orderCard(context, orders[i]),
        ),
        childCount: orders.length,
      ),
    );
  }

  Widget _orderCard(BuildContext context, MemberOrder order) {
    final statusColor = _statusColor(order.status);
    return TvFocusableCard(
      child: Padding(
        padding: EdgeInsets.all(widget.isTV ? 22 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.code}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: widget.isTV ? 18 : 14,
                        color: AppTheme.textPrimary,
                      ),
                ),
                _statusChip(context, order.status, statusColor),
              ],
            ),
            SizedBox(height: widget.isTV ? 14 : 10),
            Text(
              order.membershipName.isNotEmpty
                  ? order.membershipName
                  : 'Membership Order',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: widget.isTV ? 15 : 13,
                  ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppTheme.textMuted, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      order.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: widget.isTV ? 14 : 11,
                          ),
                    ),
                  ],
                ),
                Text(
                  order.formattedTotal,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.accent,
                        fontSize: widget.isTV ? 20 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: widget.isTV ? 12 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
        return AppTheme.success;
      case 'pending':
        return AppTheme.gold;
      case 'cancelled':
      case 'error':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              color: AppTheme.textMuted, size: widget.isTV ? 72 : 52),
          const SizedBox(height: 16),
          Text('No orders yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: widget.isTV ? 22 : 16)),
          const SizedBox(height: 8),
          Text('Your order history will appear here.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
