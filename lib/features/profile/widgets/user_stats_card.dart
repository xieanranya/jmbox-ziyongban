/// 统计卡：等级 / J币 / 收藏 三列 + 经验与容量进度条；未登录显示占位。
library;

import 'package:flutter/material.dart';

import '../../../core/constants/dimen.dart';
import '../../../data/models/user.dart';

class UserStatsCard extends StatelessWidget {
  const UserStatsCard({super.key, this.user});

  /// 非空为已登录态。
  final UserInfo? user;

  @override
  Widget build(BuildContext context) {
    final u = user;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Dimen.lg),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Dimen.lg),
        child: Column(
          children: [
            Row(
              children: [
                _stat(context, u == null ? '-' : '${u.level}', '等级'),
                _stat(context, u == null ? '-' : '${u.coin}', 'J coins'),
                _stat(context, u == null ? '-' : '${u.albumFavorites}', '收藏'),
              ],
            ),
            const SizedBox(height: Dimen.md),
            _progress(
              context,
              '等级经验',
              u == null ? '-' : '${u.exp}/${u.nextLevelExp}',
              u == null || u.nextLevelExp <= 0 ? 0.0 : (u.exp / u.nextLevelExp).clamp(0.0, 1.0),
            ),
            _progress(
              context,
              '收藏容量',
              u == null ? '-' : '${u.albumFavorites}/${u.albumFavoritesMax}',
              u == null || u.albumFavoritesMax <= 0
                  ? 0.0
                  : (u.albumFavorites / u.albumFavoritesMax).clamp(0.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: Dimen.xs),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, String label, String value, double progress) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Dimen.md),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: Dimen.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
