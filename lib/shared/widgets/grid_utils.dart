/// 网格布局与分页**展示**工具（仅 UI 层，不含状态）。
///
/// - [albumGridDelegate]：专辑卡片网格的响应式列数（3:4 封面 + 文案区）。
/// - [pagedDelegate]：把 [PagedChildBuilderDelegate] 的进度/错误/空态/「没有更多了」一次配齐，供各列表页共用。
/// 分页**控制器**（数据/状态层）见 `core/utils/paging.dart` 的 `pagingController`。
library;

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/constants/dimen.dart';
import 'async_view.dart';

/// 相册卡片网格布局：按 [maxWidth]（已扣除左右 padding）推算列数，并保证卡片 3:4 封面 + 文案区。
SliverGridDelegate albumGridDelegate(double maxWidth) {
  final columns = (maxWidth / Dimen.gridMinExtent).floor().clamp(
    Dimen.gridMinColumns,
    Dimen.gridMaxColumns,
  );
  final cardWidth = (maxWidth - Dimen.gridSpacing * (columns - 1)) / columns;
  const captionHeight = 72.0;
  final itemHeight = cardWidth / Dimen.coverAspectRatio + captionHeight;

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: Dimen.gridSpacing,
    mainAxisSpacing: Dimen.gridSpacing,
    childAspectRatio: cardWidth / itemHeight,
  );
}

/// 构造分页**展示**委托：列表页/列表 Tab 共用（配合 `pagingController` 产出的控制器）。
PagedChildBuilderDelegate<T> pagedDelegate<T>({
  required Widget Function(BuildContext context, T item, int index) itemBuilder,
  required Object? error,
  required VoidCallback onRetry,
  required VoidCallback fetchNextPage,

  /// 列表为空时的占位；缺省为空白。
  Widget? emptyView,
}) {
  return PagedChildBuilderDelegate<T>(
    itemBuilder: itemBuilder,
    firstPageProgressIndicatorBuilder: (_) => const LoadingView(),
    firstPageErrorIndicatorBuilder: (context) => ErrorRetryView(error: error, onRetry: onRetry),
    newPageProgressIndicatorBuilder: (_) => const Padding(
      padding: EdgeInsets.symmetric(vertical: Dimen.lg),
      child: Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
      ),
    ),
    newPageErrorIndicatorBuilder: (context) => Center(
      child: TextButton.icon(
        onPressed: fetchNextPage,
        icon: const Icon(Icons.refresh),
        label: const Text('加载失败，点击重试'),
      ),
    ),
    noItemsFoundIndicatorBuilder: (_) => emptyView ?? const SizedBox.shrink(),
    noMoreItemsIndicatorBuilder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimen.lg),
        child: Center(
          child: Text(
            '没有更多了',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    },
  );
}
