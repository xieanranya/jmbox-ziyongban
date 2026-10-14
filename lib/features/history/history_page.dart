/// 观看历史页：本地阅读记录网格（复用 [LocalGridPage]）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/local_grid_page.dart';
import 'history_providers.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(readingHistoryProvider);

    return LocalGridPage(
      title: '观看历史',
      items: history,
      onRemoveMany: (ids) => ref.read(readingHistoryProvider.notifier).removeMany(ids),
      onRetry: () => ref.invalidate(readingHistoryProvider),
      emptyMessage: '暂无观看历史',
      emptyIcon: Icons.history,
      heroTagPrefix: 'history',
      removedLabel: '已删除',
      removedUnit: '条记录',
    );
  }
}
