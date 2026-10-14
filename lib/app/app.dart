/// 根组件：启动初始化三态渲染 + 全局主题装配。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/async_view.dart';
import 'app_router.dart';
import 'app_state.dart';
import 'app_theme.dart';

class JmApp extends ConsumerWidget {
  const JmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(bootstrapProvider);
    final themeSetting = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'JmBox',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeOf(themeSetting),
      routerConfig: appRouter,
      builder: (context, child) => init.when(
        // 启动完成前不渲染路由树：首页/发现页的匿名请求（promote、setting）
        // 若与自动登录并发，其响应可能把会话 AVS 轮换掉，导致登录后收藏 401（偶现）。
        loading: () => const LoadingView(),
        error: (error, _) => _InitErrorView(error: error),
        data: (_) => child!,
      ),
    );
  }
}

/// 初始化失败视图：复用统一错误重试组件，铺满背景色作全屏错误页。
class _InitErrorView extends ConsumerWidget {
  const _InitErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ErrorRetryView(
      title: '应用初始化失败',
      icon: Icons.error_outline,
      iconColor: scheme.error,
      background: scheme.surface,
      error: error,
      onRetry: () => ref.invalidate(bootstrapProvider),
    );
  }
}
