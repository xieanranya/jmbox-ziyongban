/// 书架页：本地收藏网格（复用 [LocalGridPage]）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/local_grid_page.dart';
import 'bookshelf_providers.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookshelfProvider);

    return LocalGridPage(
      title: '书架',
      items: books,
      onRemoveMany: (ids) => ref.read(bookshelfProvider.notifier).removeMany(ids),
      onRetry: () => ref.invalidate(bookshelfProvider),
      emptyMessage: '书架还是空的，去发现喜欢的作品吧',
      emptyIcon: Icons.collections_bookmark_outlined,
      heroTagPrefix: 'cover',
      removedLabel: '已移出',
      removedUnit: '部作品',
    );
  }
}
