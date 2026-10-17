/// 搜索页数据流：搜索历史 + 标签云板块（来自分类接口的 blocks）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category.dart';
import '../../data/providers.dart';

/// 搜索历史：包装 [SearchHistoryRepository]（去重 / 最新在前 / 上限 20 / 磁盘持久化）。
class SearchHistoryNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() {
    return ref.watch(searchHistoryRepositoryProvider).list();
  }

  Future<void> add(String keyword) async {
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.add(keyword);
    state = AsyncData(await repo.list());
  }

  Future<void> remove(String keyword) async {
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.remove(keyword);
    state = AsyncData(await repo.list());
  }

  Future<void> clear() async {
    final repo = ref.read(searchHistoryRepositoryProvider);
    await repo.clear();
    state = const AsyncData([]);
  }
}

final searchHistoryProvider = AsyncNotifierProvider<SearchHistoryNotifier, List<String>>(
  SearchHistoryNotifier.new,
);

/// 标签云板块（发现页迁入搜索页）：主题 / 角色 / 特殊PLAY / 其他。
final searchTagBlocksProvider = FutureProvider.autoDispose<List<CategoryBlock>>((ref) async {
  final info = await ref.watch(apiRepositoryProvider).getCategories();
  return info.blocks;
});
