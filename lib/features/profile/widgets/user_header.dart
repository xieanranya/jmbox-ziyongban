/// 用户信息区：头像 + 名称/UID；未登录为点击登录的引导态。
library;

import 'package:flutter/material.dart';

import '../../../core/constants/dimen.dart';
import '../../../data/models/user.dart';
import '../../../shared/widgets/login_sheet.dart';

class UserHeader extends StatelessWidget {
  const UserHeader({super.key, this.user});

  /// 非空为已登录态。
  final UserInfo? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loggedIn = user != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.sm, Dimen.lg, 0),
      child: GestureDetector(
        onTap: loggedIn ? null : () => showLoginSheet(context),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.surfaceContainerHighest,
              child: loggedIn
                  ? Text(
                      user!.username.isEmpty ? '?' : user!.username.characters.first,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(Icons.person_outline, size: 40, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Dimen.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loggedIn ? user!.username : '未登录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: Dimen.xs),
                  if (loggedIn) ...[
                    Text(
                      user!.levelName,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: Dimen.xs),
                    Text(
                      'UID ${user!.uid}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ] else
                    Text(
                      '点击登录后查看账户资料',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
