/// 首页数据流：promote 标签 + 分区内容分页。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../core/utils/paging.dart';
import '../../data/models/album.dart';
import '../../data/models/promote.dart';
import '../../data/providers.dart';

/// 首页标签：getPromote 返回，仅保留 type=promote。
final promoteSectionsProvider = FutureProvider.autoDispose<List<PromoteSection>>((ref) async {
  final sections = await ref.watch(apiRepositoryProvider).getPromote();
  return sections.where((s) => s.sectionType == 'promote').toList();
});

/// 当前选中分区 id；null 表示未选择（默认第一个）。
///
/// 用 provider 而非 widget state 持有：build 无副作用，下拉刷新可直接读取。
class SelectedSectionId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) => state = id;
}

final selectedSectionIdProvider = NotifierProvider<SelectedSectionId, int?>(SelectedSectionId.new);

/// 每个分区的分页控制器（family 参数 = 分区 id）。
final homeSectionPagingProvider = Provider.autoDispose
    .family<PagingController<int, AlbumBrief>, int>((ref, sectionId) {
      final api = ref.read(apiRepositoryProvider);
      final controller = pagingController((page) async {
        // getPromoteList 的 page 从 0 起，内部页码从 1 起，需 -1。
        final info = await api.getPromoteList(sectionId, page - 1);
        return (info.list, info.total);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
