import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class LockedContentBanner extends StatelessWidget {
  final bool isTV;
  const LockedContentBanner({super.key, this.isTV = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isTV ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.15),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTV ? 14 : 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1),
            ),
            child: Icon(Icons.lock_rounded,
                color: AppTheme.accent, size: isTV ? 28 : 22),
          ),
          SizedBox(width: isTV ? 20 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEMBERS ONLY',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.accent,
                        fontSize: isTV ? 18 : 13,
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upgrade your membership to unlock this content.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: isTV ? 15 : 12,
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
