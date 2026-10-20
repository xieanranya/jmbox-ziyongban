/// 统一异步视图：加载 / 错误重试 / 空态。
///
/// 使用方：app 壳、各网格页与业务页。
library;

import 'package:flutter/material.dart';

import '../../core/constants/dimen.dart';

/// 统一加载态：主题背景 + 居中转圈。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

/// 错误重试视图：错误摘要 + 重试按钮。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.onRetry,
    this.error,
    this.title = '加载失败',
    this.icon = Icons.cloud_off_outlined,
    this.iconColor,
    this.background,
  });

  final VoidCallback onRetry;
  final Object? error;
  final String title;
  final IconData icon;
  final Color? iconColor;

  /// 非空时铺满背景色。
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimen.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Dimen.md,
          children: [
            Icon(icon, size: 48, color: iconColor ?? scheme.outline),
            Text(title, style: theme.textTheme.titleMedium),
            if (error != null)
              Text(
                '$error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Dimen.sm),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
    final bg = background;
    return bg == null ? content : ColoredBox(color: bg, child: content);
  }
}

/// 空态视图：图标 + 引导文案。
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: Dimen.md,
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 48, color: scheme.outline),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 整页状态视图：内容铺满剩余空间，配合 RefreshIndicator 可下拉。
class ScrollableStatusView extends StatelessWidget {
  const ScrollableStatusView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
    );
  }
}
