import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class MembershipBadge extends StatelessWidget {
  final String levelName;
  final bool compact;

  const MembershipBadge({
    super.key,
    required this.levelName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = levelName.isEmpty || levelName.toLowerCase() == 'free';
    final color = isFree ? AppTheme.textMuted : AppTheme.gold;
    final bg = isFree
        ? AppTheme.textMuted.withValues(alpha: 0.10)
        : AppTheme.gold.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFree ? Icons.person_outline : Icons.workspace_premium,
            color: color,
            size: compact ? 12 : 14,
          ),
          const SizedBox(width: 5),
          Text(
            isFree ? 'No Membership' : levelName,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
