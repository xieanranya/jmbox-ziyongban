/// 我的页：账号资料 + 内容/其他入口 + 退出登录。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/dimen.dart';
import '../../data/session_providers.dart';
import '../../shared/widgets/login_sheet.dart';
import '../../shared/widgets/section.dart';
import 'widgets/user_header.dart';
import 'widgets/user_stats_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Dimen.xl),
        children: [
          UserHeader(user: user),
          const SizedBox(height: Dimen.lg),
          UserStatsCard(user: user),
          const SectionHeader('内容'),
          SectionCard(
            children: [
              _tile(
                context,
                Icons.favorite_border,
                '漫画收藏',
                onTap: () => _openFavorites(context, ref),
              ),
              _tile(context, Icons.history, '观看历史', onTap: () => context.push(AppRoutes.history)),
              _tile(
                context,
                Icons.check_circle_outline,
                '每日签到',
                onTap: () => _openCheckin(context, ref),
              ),
            ],
          ),
          const SectionHeader('其他'),
          SectionCard(
            children: [
              _tile(context, Icons.info_outline, '关于', onTap: () => context.push(AppRoutes.about)),
            ],
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Dimen.lg, Dimen.xl, Dimen.lg, 0),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => _signOut(context, ref),
                child: const Text('退出登录'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, {VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );

  Future<void> _openFavorites(BuildContext context, WidgetRef ref) async {
    if (!await ensureLoggedIn(context, ref)) return;
    if (!context.mounted) return;
    await context.push(AppRoutes.favorites);
  }

  Future<void> _openCheckin(BuildContext context, WidgetRef ref) async {
    if (!await ensureLoggedIn(context, ref)) return;
    if (!context.mounted) return;
    await context.push(AppRoutes.dailyCheckin);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('将清除本地保存的账号凭据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).signOut();
    }
  }
}
